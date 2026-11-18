# Tạo replica mới sau failover — cụm thử lab13-bootstrap-check

## Phạm vi

Quy trình này đã được kiểm chứng trên cụm thử `lab13-bootstrap-check`.
Nó tạo một replica mới từ volume rỗng sau khi replica ban đầu được promote.
Nó không đưa primary cũ trở lại cụm và không dùng `pg_rewind`.

Không chạy quy trình trên cụm `lab13-isolated` chứa dữ liệu của phép thử
failover trước. Không khởi động lại primary cũ khi primary mới đang nhận ghi.

## Điều kiện trước khi tạo replica mới

1. `lab13-bootstrap-check-primary-1` đã dừng.
2. `lab13-bootstrap-check-replica-1` đã promote:
   `pg_is_in_recovery() = f`.
3. Mạng `lab13-bootstrap-check_default` còn tồn tại.
4. Role `replicator` có quyền LOGIN và REPLICATION.
5. Cổng 5555 trống và volume `lab13-bootstrap-check_rejoin_data`
   chưa tồn tại.
6. File `infra/.env` có mật khẩu replication phù hợp với cụm thử;
   không đưa file này vào Git.

Các điều kiện 1–4 phải được kiểm tra trên trạng thái thực tế,
không suy ra chỉ từ tên container.

## Tạo replica mới

Từ thư mục gốc repo, kiểm tra cấu hình:

```powershell
docker compose -p lab13-bootstrap-check --env-file infra/.env -f infra/compose-isolated.yaml -f infra/compose-bootstrap-check.yaml -f infra/compose-rejoin-check.yaml config --quiet
```

Chỉ khởi động service `rejoin`. Tùy chọn `--no-deps` giữ primary cũ
ở trạng thái dừng:

```powershell
docker compose -p lab13-bootstrap-check --env-file infra/.env -f infra/compose-isolated.yaml -f infra/compose-bootstrap-check.yaml -f infra/compose-rejoin-check.yaml up -d --no-deps rejoin
```

Script `isolated/rejoin-entrypoint.sh` dùng `pg_basebackup -R` sao chép
từ primary mới `lab13-bootstrap-check-replica-1` vào volume
`rejoin_data`. Nếu thư mục dữ liệu mới đã có file nhưng chưa có
`PG_VERSION`, script dừng để người vận hành kiểm tra, không xóa dữ liệu.

Kiểm tra trạng thái container:

```powershell
docker compose -p lab13-bootstrap-check --env-file infra/.env -f infra/compose-isolated.yaml -f infra/compose-bootstrap-check.yaml -f infra/compose-rejoin-check.yaml ps --all
```

Primary cũ phải vẫn `Exited`; primary mới và `rejoin-1` phải `Up`.

## Kiểm chứng sao chép

Trên replica mới, kết quả phải là `t`:

```powershell
docker exec lab13-bootstrap-check-rejoin-1 psql -U postgres -d ha_lab -c "SELECT pg_is_in_recovery() AS is_replica;"
```

Trên primary mới, phải thấy kết nối `streaming/async`:

```powershell
docker exec lab13-bootstrap-check-replica-1 psql -U postgres -d ha_lab -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"
```

Trong lần thử ngày 18/11/2026, nhóm đã ghi đơn
`REJOIN-20261118-001`, amount `456.78`, trên primary mới;
replica mới đọc lại đúng một dòng.

Ảnh minh chứng trên máy lab:
`anhminhchung/21_replica_moi_sau_failover_nhan_du_lieu.png`.

## Giới hạn và xử lý khi lỗi

- Đây là thao tác thủ công; chưa có bộ điều phối tự tạo replica.
- Dùng volume mới, không xóa hoặc tái sử dụng volume của primary cũ.
- Nếu service `rejoin` không chạy, xem log của riêng service trước khi
  sửa cấu hình. Không chạy `up -d` cho toàn bộ cụm đã failover.
- Không coi việc tạo replica mới là kiểm chứng failback của primary cũ.
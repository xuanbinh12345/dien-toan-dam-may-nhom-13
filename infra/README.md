# Hạ tầng PostgreSQL – Thành viên 1

## Đã hoàn thành

- [x] Ghi nhận PostgreSQL 16.15, Docker 29.9.2, Compose v5.6.1.
- [x] Dựng cụm riêng bằng [compose-isolated.yaml](compose-isolated.yaml).
- [x] Tạo `orders` từ [schema.sql](../tests/schema.sql).
- [x] Ghi primary, đọc cùng mã đơn trên replica; kiểm tra `streaming/async`.
- [x] Thử dừng primary, promote replica, đổi đích ghi và xác nhận ACK trên primary mới.
- [x] Có [quy trình failover](FAILOVER.md), [CSV và ảnh](../results/README.md).

## Địa chỉ và vai trò

| Container | Địa chỉ từ máy host | Trước failover | Cuối lần thử 17/11 |
|---|---|---|---|
| `lab13-isolated-primary-1` | `127.0.0.1:5543` | Primary | Đã dừng |
| `lab13-isolated-replica-1` | `127.0.0.1:5544` | Replica | Primary mới |

Database `ha_lab`, user quản trị lab `postgres`, bảng `public.orders`. Hai nút dùng volume riêng. Cổng chỉ bind localhost. Cấu hình cũ `compose.yaml` và các container `lab13-primary`, `lab13-replica`, `lab13-pitr` không thuộc lần thử hiện tại.

## Dựng mới và nạp schema

Đọc [hướng dẫn dựng cụm](isolated/README.md). Tạo `infra/.env` từ [.env.example](.env.example), thay giá trị mẫu bằng mật khẩu lab riêng; không commit `.env`.

Sau khi cụm mới có primary và replica đúng vai trò, từ thư mục gốc repo:

```powershell
Get-Content -Raw tests/schema.sql | docker exec -i lab13-isolated-primary-1 psql -v ON_ERROR_STOP=1 -U postgres -d ha_lab
docker exec lab13-isolated-primary-1 psql -U postgres -d ha_lab -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"
docker exec lab13-isolated-replica-1 psql -U postgres -d ha_lab -c "SELECT pg_is_in_recovery();"
```

## Kiểm chứng bổ sung ngày 18/11/2026

- [x] [Dựng cụm mới từ volume rỗng](compose-bootstrap-check.yaml): primary streaming/async, replica đọc được đơn mới.
- [x] [Tạo replica mới sau failover](REJOIN.md) trên cụm thử `lab13-bootstrap-check`; không tái sử dụng volume của primary cũ.
- [x] [Cụm tích hợp](compose-integrated.yaml) có replication và WAL archive; [PITR sau khi xóa lan sang replica](../docs/INTEGRATED_PITR.md) đã khôi phục đủ dữ liệu.

## Chưa hoàn tất

- [ ] Khóa phiên bản/digest image để máy mới tái lập đúng phiên bản.
- [ ] Viết và thử quy trình đưa primary cũ trở lại làm replica của primary mới.
- [ ] Kiểm thử lưu bản sao backup/WAL ngoài Docker host và quy trình lưu giữ.

**Không khởi động lại primary cũ hoặc chạy `compose up -d` toàn bộ trên môi trường đã promote.** Cụm `lab13-isolated` chưa có replica thay thế; cụm thử `lab13-bootstrap-check` đã tạo replica mới nhưng chưa đưa primary cũ trở lại.

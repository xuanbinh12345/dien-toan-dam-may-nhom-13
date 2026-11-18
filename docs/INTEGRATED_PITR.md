# Runbook — Replication kết hợp PITR

## Phạm vi

Quy trình đã kiểm chứng với run `INT-20261118-150553`.
Kết quả chi tiết và CSV nằm tại
[results/INT-20261118-150553](../results/INT-20261118-150553/README.md).

Lần chạy khác phải dùng tên project, cổng và volume mới.
Không xóa hoặc ghi đè volume của các phép thử đã lưu.
File `.env` chứa mật khẩu chỉ giữ trên máy lab.

## 1. Dựng nguồn có replication và WAL archive

File [compose-integrated.yaml](../infra/compose-integrated.yaml)
dựng primary, replica, volume WAL archive và volume base backup.
Chuẩn bị `infra/.env` theo `infra/.env.example`.
Kiểm tra cổng 5563 và 5564 còn trống, rồi chạy từ gốc repo:

```powershell
docker compose -p lab13-integrated --env-file infra/.env -f infra/compose-integrated.yaml config --quiet
docker compose -p lab13-integrated --env-file infra/.env -f infra/compose-integrated.yaml up -d
docker compose -p lab13-integrated --env-file infra/.env -f infra/compose-integrated.yaml ps
```

Kiểm tra primary thấy `streaming/async`, replica trả
`pg_is_in_recovery() = t`, primary có `archive_mode = on`.
Nạp `tests/schema.sql`. Ghi một đơn nền trên primary rồi đọc
lại trên replica trước khi backup.

## 2. Tạo backup và trạng thái trước xóa

Tạo base backup bằng `pg_basebackup` trên primary, lưu trong
`/backups/<ten_backup>` với `-Fp -Xs --checkpoint=fast
--manifest-checksums=SHA256`. Chạy `pg_verifybackup` và chỉ
tiếp tục khi báo thành công.

Sau backup, ghi các đơn thử nghiệm trên primary và xác nhận
replica đã đọc được. Lưu số dòng, checksum và mốc UTC
**sau khi dữ liệu đã được sao chép, trước khi xóa**.
Không dùng giờ địa phương làm mốc nếu chưa ghi múi giờ.

Lần thử đã lưu dùng:

- Backup: `/backups/base_integrated_20261118_150553`.
- Mốc phục hồi: `2026-11-18 08:08:44.585216+00`.
- Trạng thái trước xóa: 4 dòng,
  checksum `d86a2624608b97232e95955f5c8246fb`.

Câu SQL tạo checksum phải giống nhau trước và sau PITR:

```sql
SELECT count(*) AS row_count,
       md5(coalesce(
           string_agg(
               order_id || '|' || amount::text || '|' ||
               (created_at AT TIME ZONE 'UTC')::text,
               ';' ORDER BY order_id
           ), ''
       )) AS checksum_md5
FROM public.orders;
```

## 3. Xóa và xác nhận thao tác đã lan sang replica

Xóa các đơn thử nghiệm trên primary và ghi lại số dòng bị xóa.
Truy vấn lại cùng tập mã đơn trên primary và replica.
Chỉ tiếp tục khi cả hai cho thấy các đơn đã biến mất.
Chạy `pg_switch_wal()` trên primary, rồi kiểm tra
`pg_stat_archiver`: WAL mới đã được archive và `failed_count = 0`.

Trong run đã lưu, ba đơn bị xóa; cả hai nút đều trả số đơn
thử nghiệm còn lại là 0.

## 4. Phục hồi vào volume riêng

Tạo một tag ảnh cục bộ từ đúng image ID của primary nguồn.
Trong file cục bộ `backup/.env.integrated-restore`, đặt
`PITR_IMAGE`, `BACKUP_PATH` và `RECOVERY_TARGET_TIME` của
lần chạy. Không commit file môi trường này.

Dùng [compose-restore.yaml](../backup/compose-restore.yaml)
cùng [compose-integrated-restore.yaml](../backup/compose-integrated-restore.yaml).
File bổ sung trỏ tới hai volume `lab13-integrated_base_backups`,
`lab13-integrated_wal_archive` và cổng restore 5565.
Project restore dùng volume dữ liệu mới.

```powershell
docker compose -p lab13-integrated-restore --env-file backup/.env.integrated-restore -f backup/compose-restore.yaml -f backup/compose-integrated-restore.yaml config --quiet
docker compose -p lab13-integrated-restore --env-file backup/.env.integrated-restore -f backup/compose-restore.yaml -f backup/compose-integrated-restore.yaml --profile tools run --rm prepare
docker compose -p lab13-integrated-restore --env-file backup/.env.integrated-restore -f backup/compose-restore.yaml -f backup/compose-integrated-restore.yaml up -d --no-deps restore
```

`prepare` phải hiện `backup successfully verified` và
`PREPARE_OK`. Trong log restore, kiểm tra đúng
`recovery_target_time`, trạng thái `paused`, và giao dịch xóa
nằm sau mốc phục hồi.

## 5. Kiểm chứng và hoàn tất

Khi restore còn `paused`, kiểm tra `pg_is_in_recovery() = t`,
đọc lại các đơn đã xóa, lưu số dòng và checksum. So sánh với
trạng thái trước xóa. Chỉ sau khi lưu kết quả đối chiếu,
chạy `pg_wal_replay_resume()`.

Xác nhận `pg_is_in_recovery() = f` và
`transaction_read_only = off`, rồi ghi một đơn mới trên bản
phục hồi và đọc lại bằng truy vấn riêng.

Lần thử đã lưu khôi phục 4/4 dòng, checksum khớp và đọc/ghi
đơn mới trị giá 999.99 thành công. Thời gian restore đầy đủ
chưa được đo; không gọi thời gian khởi động container là RTO.

## Giới hạn

Replication bất đồng bộ trên cùng Docker host. Một lần thử
không xác lập RPO/RTO cho mọi sự cố. Phép thử này chứng minh
xóa dữ liệu có thể lan sang replica, trong khi bản backup cùng
WAL archive cho phép khôi phục về trước thao tác xóa trên một
PostgreSQL riêng.
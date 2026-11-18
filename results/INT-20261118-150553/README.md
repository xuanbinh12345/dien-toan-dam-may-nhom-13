# Thử nghiệm kết hợp replication và PITR

Run ID: `INT-20261118-150553`. Thực hiện ngày 18/11/2026
trên Docker Desktop và PostgreSQL 16.15.

## Môi trường

- Project nguồn: `lab13-integrated`.
- Primary: `lab13-integrated-primary-1`, cổng host 5563.
- Replica: `lab13-integrated-replica-1`, cổng host 5564.
- Replication: streaming bất đồng bộ.
- WAL archive và base backup nằm trên các volume riêng của project nguồn.
- Project phục hồi: `lab13-integrated-restore`.
- Bản phục hồi: `lab13-integrated-restore-restore-1`, cổng host 5565,
  dùng volume dữ liệu mới và đọc volume backup/WAL của project nguồn.

## Trình tự và kết quả

1. Tạo schema và đơn nền `INT-SETUP-20261118-001`, amount 100.00.
   Replica đọc được đơn nền.
2. Tạo base backup `/backups/base_integrated_20261118_150553`;
   `pg_verifybackup` xác nhận thành công.
3. Sau backup, ghi ba đơn `INT-20261118-001` đến
   `INT-20261118-003` với amount 111.00, 222.00, 333.00.
   Primary và replica đều đọc được đủ bốn đơn.
4. Lưu trạng thái trước xóa: 4 dòng, checksum
   `d86a2624608b97232e95955f5c8246fb`.
   Chọn mốc phục hồi `2026-11-18 08:08:44.585216+00`.
5. Xóa ba đơn thử nghiệm trên primary: `DELETE 3`.
   Cả primary và replica còn 0 đơn có mã `INT-20261118-%`.
6. Chuyển WAL sang archive; quan sát `archived_count = 13`,
   `last_archived_wal = 00000001000000000000000B`,
   `failed_count = 0`.
7. Sao chép base backup sang volume restore mới, kiểm tra lại
   `pg_verifybackup`: thành công.
8. Khởi động restore. PostgreSQL dừng recovery tại mốc đã chọn,
   trước commit lúc `2026-11-18 08:09:48.000605+00`.
   Khi paused, restore đọc được lại cả bốn đơn.
9. Số dòng sau PITR là 4 và checksum sau PITR bằng
   `d86a2624608b97232e95955f5c8246fb`, khớp trước xóa.
10. Kết thúc recovery: `pg_is_in_recovery() = f`,
    `transaction_read_only = off`. Ghi đơn
    `INT-POST-PITR-20261118-001`, amount 999.99,
    rồi đọc lại đúng một dòng.

## Dữ liệu thô

| File | Nội dung |
|---|---|
| [run-info.txt](run-info.txt) | Đường dẫn backup và mốc phục hồi UTC |
| [before-checksum.csv](before-checksum.csv) | Số dòng và checksum trước xóa |
| [after-delete-primary.csv](after-delete-primary.csv) | Số đơn thử nghiệm còn trên primary sau xóa |
| [after-delete-replica.csv](after-delete-replica.csv) | Số đơn thử nghiệm còn trên replica sau xóa |
| [after-checksum.csv](after-checksum.csv) | Số dòng và checksum sau PITR, trước khi ghi thử |
| [post-restore-read.csv](post-restore-read.csv) | Đơn mới đọc lại từ bản phục hồi |

Ảnh màn hình đã được sao chép vào [evidence/integrated](../evidence/integrated/):

- [22 — cụm replication và WAL archive](../evidence/integrated/22_cum_tich_hop_replication_va_wal_archive.png).
- [23 — base backup](../evidence/integrated/23_base_backup_cum_tich_hop.png).
- [24 — lệnh xóa đã lan sang replica](../evidence/integrated/24_xoa_don_da_lan_sang_replica.png).
- [26 — PITR dừng trước lệnh xóa](../evidence/integrated/26_pitr_cum_tich_hop_dung_truoc_lenh_xoa.png).
- [27 — đối chiếu checksum](../evidence/integrated/27_doi_chieu_checksum_pitr_cum_tich_hop.png).
- [28 — đọc/ghi sau PITR](../evidence/integrated/28_doc_ghi_sau_pitr_cum_tich_hop.png).

Ảnh 25 về trạng thái WAL archive chưa được lưu; số liệu
`archived_count = 13` và `failed_count = 0` đã được quan sát trong lần chạy.

## Giới hạn

Đây là một lần thử trên cùng Docker host. Phép thử chứng minh
thao tác xóa đã lan sang replica và bản PITR riêng lấy lại trạng thái
trước xóa, với số dòng và checksum khớp. Nó không chứng minh
RPO luôn bằng 0, không đo RTO đầy đủ và chưa kiểm thử lỗi toàn host.

Checksum 4 dòng được chụp trước thao tác ghi thử sau phục hồi;
không so sánh checksum đó với database đã thêm đơn 999.99.

# Backup và phục hồi PITR — TV2

Ngoài lần thử riêng của TV2 bên dưới, nhóm đã thực hiện [bài thử tích hợp replication và PITR](../results/INT-20261118-150553/README.md): xóa ba đơn đã lan sang replica, rồi phục hồi từ backup/WAL của cùng cụm về trước thời điểm xóa. [Runbook tích hợp](../docs/INTEGRATED_PITR.md) và [Compose bổ sung cho restore](compose-integrated-restore.yaml) ghi rõ môi trường, volume và giới hạn của lần thử này.

## Kết quả đã kiểm chứng

Đã thực hiện PITR trên môi trường riêng PostgreSQL **16.15**: archive WAL, tạo base backup, kiểm tra manifest, ghi dữ liệu sau backup, xóa ba đơn, restore tới trước thời điểm xóa, đối chiếu số dòng/checksum và kiểm tra đọc/ghi sau phục hồi.

| Hạng mục | Kết quả | Minh chứng |
|---|---|---|
| WAL archive | Đã lưu segment cần thiết; failed_count = 0 tại kiểm tra | [Ảnh 13b](../results/evidence/tv2/13b_wal_archive_sau_khi_xoa.png) |
| Base backup | `base_20261117_193933`, pg_verifybackup thành công | [CSV backup](../results/backup-base_20261117_193933.csv) |
| Mục tiêu PITR | `2026-11-17 19:46:55.579505+00` | [JSON mốc thử](../results/PITR-20261117-194600/pitr-info.json) |
| Xóa thử nghiệm | Ba đơn sau backup bị xóa; count nhóm còn 0 | [Ảnh 14b](../results/evidence/tv2/14b_du_lieu_sau_khi_xoa.png) |
| Phục hồi | Có lại ba đơn; toàn bảng 4 dòng; checksum khớp | [CSV đối chiếu](../results/PITR-20261117-194600/checksum-comparison.csv) |
| Khởi động đến pause | 1,935 giây; không phải tổng RTO | [CSV thời gian](../results/PITR-20261117-194600/restore-to-pause.csv) |
| Đọc/ghi sau phục hồi | INSERT được ACK, kết nối mới đọc đúng đơn 999.99 | [CSV đọc/ghi](../results/PITR-20261117-194600/post-restore-rw.csv) |

## Cấu hình và môi trường

| File / thành phần | Vai trò |
|---|---|
| [compose-backup.yaml](compose-backup.yaml) | Project `lab13-backup`; source tại `127.0.0.1:5545` |
| [compose-restore.yaml](compose-restore.yaml) | Project `lab13-restore`; prepare volume rồi restore tại `127.0.0.1:5546` |
| [.env.example](.env.example) | Mẫu mật khẩu để tạo `.env` cục bộ |
| [restore.env.example](restore.env.example) | Ví dụ thông tin lần thử; tạo lại `.env.restore` theo backup/target thật |
| [schema.sql](../tests/schema.sql) | Schema chung của dự án |

Source dùng ba volume riêng: `lab13-backup_source_data`, `lab13-backup_wal_archive`, `lab13-backup_base_backups`. Restore dùng `lab13-restore_restore_data`; backup/WAL nguồn được mount chỉ đọc. Các volume này vẫn cùng Docker host, chưa độc lập về miền lỗi.

`compose-backup.yaml` còn dùng tag động `postgres:16`; phiên bản đã quan sát là 16.15. Khi restore, lần thử đã gắn tag riêng vào đúng image ID của source và dùng `pull_policy: never`. Máy nhận không có tag/volume của máy thực nghiệm; cần tự dựng và ghi phiên bản thật nếu chạy mới.

## Trạng thái cuối lần thử

- Source giữ trạng thái sau xóa; ba đơn thử nghiệm không còn ở source.
- Restore đã kết thúc recovery và ghi được đơn `POST-PITR-20261117-201509116`. Sau kiểm thử, dự kiến có 5 dòng; snapshot/checksum 4 dòng được lấy trước lượt ghi này.
- Không chạy lại `prepare` trên volume restore đã có dữ liệu. Không tạo lại `recovery.signal` trên database đã mở ghi.
- Cụm HA có primary cũ dừng, replica cũ đã thành primary mới. Không thao tác Compose hạ tầng khi chỉ thử Backup/PITR.

## Hướng dẫn và phần còn lại

Đọc [RUNBOOK.md](RUNBOOK.md), [danh mục kết quả](../results/PITR-20261117-194600/README.md) và [ảnh minh chứng](../results/evidence/tv2/README.md).

- [x] Phép thử chức năng Backup/PITR độc lập thành công.
- [x] Đối chiếu dữ liệu và kiểm tra client psql đọc/ghi sau restore.
- [ ] Tái lập trên máy khác và lưu log mới đầy đủ.
- [ ] Tích hợp với HA, thử truyền thao tác xóa sang replica.
- [ ] Thống nhất mục tiêu RPO/RTO trước lần đo mới; đo tổng thời gian đến dịch vụ dùng được và nhiều lần lặp.
- [ ] Thực hiện lịch backup, retention, bảo vệ/mã hóa, bản sao ngoài host theo [đề xuất](RETENTION.md).

Không có full backup/WAL trong Git. `pg_verifybackup` không thay cho test restore, và checksum khớp của lần này không phải cam kết mọi lần phục hồi đều thành công.

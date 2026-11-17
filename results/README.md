# Kết quả thực nghiệm – Nhóm 13

## Lần thử ngày 17/11/2026 — lab13-isolated

| Dữ liệu | File | Kết quả / cách đọc |
|---|---|---|
| Tải bình thường | [workload-LOAD-20261117-141855.csv](workload-LOAD-20261117-141855.csv) | 444 ACK và 444 lần đọc thấy đơn |
| Đo lag | [replication-lag-20261117-141920.csv](replication-lag-20261117-141920.csv) | Số liệu thô; có cả mẫu sau khi tải kết thúc, chưa tổng hợp thống kê |
| Kiểm tra script 30 giây | [failover-FO-20261117-150424-e2388e.csv](failover-FO-20261117-150424-e2388e.csv) | 26 ACK; chưa dừng primary trong lần này |
| Tải failover chính thức | [failover-FO-20261117-151645-24e67c.csv](failover-FO-20261117-151645-24e67c.csv) | 511 lượt ghi, 510 ACK, 1 UNCONFIRMED |
| Mốc điều khiển | [events-FO-20261117-151645-24e67c.csv](events-FO-20261117-151645-24e67c.csv) | stop_requested, primary_stopped, promotion_requested/confirmed, write_target_changed |
| Thời gian khôi phục ghi | [recovery-summary-FO-20261117-151645-24e67c.csv](recovery-summary-FO-20261117-151645-24e67c.csv) | 2,316 giây |
| Đối chiếu tổng kết | [comparison-summary-FO-20261117-151645-24e67c.csv](comparison-summary-FO-20261117-151645-24e67c.csv) | 510 ACK còn hiện diện, 0 ACK thiếu; 1 UNCONFIRMED không hiện diện |
| Đối chiếu từng giao dịch | [comparison-details-FO-20261117-151645-24e67c.csv](comparison-details-FO-20261117-151645-24e67c.csv) | Trạng thái phía client và có/không trên primary mới |
| Snapshot mã đơn | [db-orders-FO-20261117-151645-24e67c.txt](db-orders-FO-20261117-151645-24e67c.txt) | 510 ID thuộc đúng run, lấy sau khi tải hoàn tất |
| Ảnh chụp kết quả | [Minh chứng TV3](evidence/tv3/README.md) | Schema, tải đọc/ghi, độ trễ, thời gian khôi phục và đối chiếu |

## Diễn giải

`stop_requested_utc = 2026-11-17T15:17:08.5583066Z`; ACK đầu tiên trên primary mới lúc `2026-11-17T15:17:10.8747392Z`. Hiệu hai mốc là 2,3164326 giây, làm tròn thành **2,316 giây**. Mốc bắt đầu nằm ngay trước lệnh dừng, không phải thời điểm lỗi được ứng dụng phát hiện. Phép đo có cả thời gian chờ lượt ghi.

20 ACK trên primary cũ và 490 ACK trên primary mới đều còn trong snapshot đối chiếu. Lượt 000021 là UNCONFIRMED do container cũ đã dừng và không hiện diện trong dữ liệu. Không gộp lượt này vào số ACK bị mất. Kết luận chỉ áp dụng cho lần thử đã lưu; không khẳng định RPO luôn bằng 0 hay toàn bộ nội dung bảng đã được kiểm chứng bằng checksum.

## Ảnh cũ và PITR

Các ảnh nằm trực tiếp trong `evidence/` (01-failover-status.png, 02-write-after-failover.png, 03-pitr.png, 04-backup-verify.png, 05-schema.png, 08-failover.png) thuộc thử nghiệm trước với cụm khác. Giữ để tham khảo, không dùng chứng minh Backup/PITR đã hoàn thành trên `lab13-isolated`.

PITR hiện chưa có bộ CSV/log/count/checksum mới. Xem [việc cần làm của TV2](../backup/README.md).

## Quy ước

Tên file hiện tại chứa run ID để ghép đúng dữ liệu; giữ nguyên tên khi chia sẻ. Thời gian UTC, độ trễ ms, WAL gap byte, thời gian khôi phục giây. File `write-target.txt` là trạng thái cục bộ bị Git bỏ qua. Không commit mật khẩu, volume, base backup hoặc WAL thật.

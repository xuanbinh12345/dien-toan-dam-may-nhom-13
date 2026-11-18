# Kết quả thực nghiệm – Nhóm 13

## Lần thử ngày 17/11/2026 — lab13-isolated

| Dữ liệu | File | Kết quả / cách đọc |
|---|---|---|
| Tải bình thường | [workload-LOAD-20261117-141855.csv](workload-LOAD-20261117-141855.csv) | 444 ACK và 444 lần đọc thấy đơn |
| Đo lag | [CSV gốc](replication-lag-20261117-141920.csv), [thống kê](lag-summary-LOAD-20261117-141855.csv), [biểu đồ](lag-chart-LOAD-20261117-141855.svg) | Trong khoảng có tải: 258 mẫu, trung bình 1,326 ms, p95 1,797 ms, lớn nhất 10,411 ms |
| Kiểm tra script 30 giây | [failover-FO-20261117-150424-e2388e.csv](failover-FO-20261117-150424-e2388e.csv) | 26 ACK; chưa dừng primary trong lần này |
| Tải failover chính thức | [failover-FO-20261117-151645-24e67c.csv](failover-FO-20261117-151645-24e67c.csv) | 511 lượt ghi, 510 ACK, 1 UNCONFIRMED |
| Mốc điều khiển | [events-FO-20261117-151645-24e67c.csv](events-FO-20261117-151645-24e67c.csv) | stop_requested, primary_stopped, promotion_requested/confirmed, write_target_changed |
| Thời gian khôi phục ghi | [recovery-summary-FO-20261117-151645-24e67c.csv](recovery-summary-FO-20261117-151645-24e67c.csv) | 2,316 giây |
| Đối chiếu tổng kết | [comparison-summary-FO-20261117-151645-24e67c.csv](comparison-summary-FO-20261117-151645-24e67c.csv) | 510 ACK còn hiện diện, 0 ACK thiếu; 1 UNCONFIRMED không hiện diện |
| Đối chiếu từng giao dịch | [comparison-details-FO-20261117-151645-24e67c.csv](comparison-details-FO-20261117-151645-24e67c.csv) | Trạng thái phía client và có/không trên primary mới |
| Snapshot mã đơn | [db-orders-FO-20261117-151645-24e67c.txt](db-orders-FO-20261117-151645-24e67c.txt) | 510 ID thuộc đúng run, lấy sau khi tải hoàn tất |
| Ảnh chụp kết quả | [Minh chứng TV3](evidence/tv3/README.md) | Schema, tải đọc/ghi, độ trễ, thời gian khôi phục và đối chiếu |

### Cách tính độ trễ khi có tải

Khoảng tải lấy từ giao dịch đầu tiên bắt đầu lúc
`2026-11-17T14:18:55.6371159Z` đến lần đọc cuối lúc
`2026-11-17T14:28:54.6095526Z`. CSV đo lag có 270 mẫu;
258 mẫu nằm trong khoảng này và không có mẫu lag NULL.
P95 là giá trị tại vị trí `ceil(0,95 × 258)` sau khi sắp xếp tăng dần.

Cột `sampled_utc` của CSV gốc bị ghi `THH24` thay vì giờ `T14`.
Khi phân tích riêng lần chạy này, thay `THH24:` bằng `T14:`
trong bộ nhớ rồi lọc theo khoảng tải. CSV gốc được giữ nguyên.
Script [plot-lag.ps1](../tests/plot-lag.ps1) tái tạo biểu đồ SVG.

Trong cùng 258 mẫu, WAL gap trung bình là 0,9 byte,
lớn nhất là 232 byte. Đây là một lần đo trên cùng Docker host.

## Diễn giải

`stop_requested_utc = 2026-11-17T15:17:08.5583066Z`; ACK đầu tiên trên primary mới lúc `2026-11-17T15:17:10.8747392Z`. Hiệu hai mốc là 2,3164326 giây, làm tròn thành **2,316 giây**. Mốc bắt đầu nằm ngay trước lệnh dừng, không phải thời điểm lỗi được ứng dụng phát hiện. Phép đo có cả thời gian chờ lượt ghi.

20 ACK trên primary cũ và 490 ACK trên primary mới đều còn trong snapshot đối chiếu. Lượt 000021 là UNCONFIRMED do container cũ đã dừng và không hiện diện trong dữ liệu. Không gộp lượt này vào số ACK bị mất. Kết luận chỉ áp dụng cho lần thử đã lưu; không khẳng định RPO luôn bằng 0 hay toàn bộ nội dung bảng đã được kiểm chứng bằng checksum.

## Backup và PITR — môi trường riêng

Lần thử: `PITR-20261117-194600`.

Bài thử thực hiện trên nguồn `lab13-backup-source-1`
và khôi phục vào `lab13-restore-restore-1`, tách biệt với cụm HA
`lab13-isolated`.

| Nội dung | Kết quả |
|---|---|
| Base backup | `/backups/base_20261117_193933` |
| Kiểm tra bản sao | `pg_verifybackup` thành công |
| Mốc khôi phục UTC | `2026-11-17 19:46:55.579505+00` |
| Dữ liệu trước khi xóa | 4 dòng, gồm 3 đơn hàng thử nghiệm và 1 đơn hàng thiết lập |
| Thao tác xóa | Xóa 3 đơn hàng thử nghiệm; kiểm tra trên nguồn còn 0 đơn thuộc nhóm này |
| Sau PITR, trước khi ghi thử | Khôi phục đủ 4 dòng; cả 3 đơn hàng đã xóa xuất hiện trở lại |
| Checksum trước/sau | Cùng bằng `32af3014e87e8c2c10683e8873cd2e9d` |
| Khởi động đến quan sát recovery paused | 1,935 giây |
| Sau khi kết thúc recovery | `pg_is_in_recovery() = false`, `transaction_read_only = off` |
| Kiểm tra đọc/ghi | Ghi đơn `POST-PITR-20261117-201509116`, amount `999.99`; nhận ACK và đọc lại được 1 dòng |

Số dòng và checksum được so sánh trước khi chèn đơn hàng kiểm tra
đọc/ghi sau phục hồi.

Khoảng 1,935 giây chỉ đo từ bắt đầu khởi động restore đến quan sát
trạng thái paused. Đây chưa phải RTO toàn bộ quy trình, vì chưa gồm
chuẩn bị dữ liệu khôi phục và kiểm tra dịch vụ đọc/ghi.

### Dữ liệu và minh chứng PITR

- [Metadata base backup](backup-base_20261117_193933.csv).
- [Chi tiết lần thử và các file kết quả](PITR-20261117-194600/README.md).
- [Đối chiếu số dòng và checksum](PITR-20261117-194600/checksum-comparison.csv).
- [Kết quả đọc/ghi sau phục hồi](PITR-20261117-194600/post-restore-rw.csv).
- [Ảnh minh chứng TV2](evidence/tv2/README.md).
- [Quy trình backup/PITR](../backup/RUNBOOK.md).

Đã có ảnh chụp log recovery; chưa lưu log restore dạng văn bản riêng.
Kết quả này chứng minh PITR trên môi trường backup riêng.
Chưa thực hiện bài thử xóa dữ liệu lan sang replica rồi PITR
trên cùng hệ thống HA.

## Phân loại ảnh minh chứng

- [TV1](evidence/tv1/): hạ tầng, replication và điều khiển failover.
- [TV2](evidence/tv2/README.md): backup, WAL archive, PITR và kiểm tra phục hồi.
- [TV3](evidence/tv3/README.md): schema, tải, đo lag và đối chiếu giao dịch.

Các ảnh nằm trực tiếp trong `evidence/`
(`01-failover-status.png`, `02-write-after-failover.png`,
`03-pitr.png`, `04-backup-verify.png`, `05-schema.png`,
`08-failover.png`) thuộc thử nghiệm trước với cụm khác.
Giữ để tham khảo, không ghép chúng vào bằng chứng của các run hiện tại.

## Quy ước

Tên file hiện tại chứa run ID để ghép đúng dữ liệu; giữ nguyên tên khi chia sẻ. Thời gian UTC, độ trễ ms, WAL gap byte, thời gian khôi phục giây. File `write-target.txt` là trạng thái cục bộ bị Git bỏ qua. Không commit mật khẩu, volume, base backup hoặc WAL thật.

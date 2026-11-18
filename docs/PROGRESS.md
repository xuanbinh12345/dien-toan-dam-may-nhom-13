# Tiến độ dự án — Nhóm 13

Cập nhật ngày 18/11/2026.

## Trạng thái tích hợp mã nguồn

Đã gộp vào main trên GitHub:
- TV1: hạ tầng primary–replica và quy trình failover — PR #4.
- TV3: script tải, đo lag, đối chiếu giao dịch và kết quả — PR #6.
- TV2: backup, lưu WAL, PITR và minh chứng — PR #5.

Máy triển khai đã đồng bộ main tại commit 165543e.
Các cập nhật hoàn thiện tiếp theo thực hiện trên nhánh codex/hoan-thien-du-an.

## Công việc đã thực hiện

| Phần | Kết quả |
|---|---|
| Hạ tầng | Dựng PostgreSQL primary–replica bằng Docker Compose; kiểm tra streaming replication bất đồng bộ |
| Dựng mới từ volume rỗng | Cụm lab13-bootstrap-check dùng volume và cổng riêng; primary streaming/async, replica ở recovery và đọc được đơn BOOTSTRAP-20261118-001 vừa ghi trên primary |
| Schema | Tạo bảng orders, khóa chính order_id và ràng buộc amount > 0 |
| Tải bình thường | 444 giao dịch ACK; 444 lần đọc thấy đơn hàng trên replica |
| Đo replication | Đã lưu CSV và biểu đồ; trong khoảng có tải có 258 mẫu, mean 1,326 ms, p95 1,797 ms, max 10,411 ms; WAL gap max 232 byte |
| Failover | Dừng primary bằng script, promote replica và chuyển đích ghi |
| Đối chiếu sau failover | 510/510 giao dịch ACK có trên primary mới; 1 UNCONFIRMED không có trong dữ liệu đối chiếu |
| Base backup | Tạo bản sao vật lý, kiểm tra pg_verifybackup thành công |
| WAL archive | Đã kiểm tra WAL được lưu vào thư mục archive |
| PITR | Khôi phục về thời điểm trước khi xóa 3 đơn hàng trong môi trường backup riêng |
| Kiểm tra PITR | Số dòng trước và sau khôi phục đều là 4; checksum khớp |
| Đọc/ghi sau PITR | Kết thúc recovery, ghi đơn hàng mới thành công và đọc lại được |
| Tái lập dự phòng sau failover | Trên lab13-bootstrap-check: dừng primary cũ, promote replica, tạo replica mới từ volume rỗng; primary mới thấy streaming/async và replica mới đọc được đơn REJOIN-20261118-001 trị giá 456.78 |

## Kết quả failover

Run ID: FO-20261117-151645-24e67c.

- Tổng số lần thử ghi: 511.
- ACK trên primary cũ: 20.
- ACK trên primary mới: 490.
- Tổng ACK: 510; có mặt sau failover: 510; thiếu: 0.
- UNCONFIRMED: 1; không có trong dữ liệu đối chiếu.
- Thời gian từ yêu cầu dừng primary đến ACK đầu tiên trên primary mới: 2,316 giây.

Đây là phép thử chuyển đổi do người vận hành kích hoạt.
Không coi 1 giao dịch UNCONFIRMED là giao dịch ACK bị mất.
Kết quả một lần thử không chứng minh replication bất đồng bộ luôn có RPO bằng 0.

## Kết quả backup và PITR

Run ID: PITR-20261117-194600.

- Base backup: /backups/base_20261117_193933.
- pg_verifybackup: thành công.
- Thời điểm khôi phục: 2026-11-17 19:46:55.579505+00.
- Đã xóa 3 đơn hàng thử nghiệm trên source.
- Khi recovery dừng tại mục tiêu, cả 3 đơn hàng được khôi phục.
- Tổng số dòng trước xóa và sau khôi phục: 4.
- Checksum trước và sau: 32af3014e87e8c2c10683e8873cd2e9d.
- Thời gian từ bắt đầu khởi động restore đến quan sát trạng thái paused: 1,935 giây.
- Sau khi kết thúc recovery, ghi và đọc lại đơn hàng trị giá 999,99 thành công.

Khoảng 1,935 giây không phải RTO toàn bộ quy trình:
chưa bao gồm chuẩn bị, sao chép backup và kiểm tra phục hồi dịch vụ.

Chi tiết: [kết quả PITR](../results/PITR-20261117-194600/README.md).
Quy trình: [runbook backup/PITR](../backup/RUNBOOK.md).

## Trạng thái môi trường ở cuối các lần thử

- lab13-isolated-primary-1: đã dừng.
- lab13-isolated-replica-1: đã promote thành primary mới.
- Chưa có replica thay thế cho primary mới.
- lab13-backup-source-1: nguồn của bài thử backup/PITR riêng.
- lab13-restore-restore-1: đã kết thúc recovery và kiểm tra đọc/ghi.

Đây là trạng thái ghi nhận trong các lần thử, không phải kiểm tra trạng thái trực tiếp hiện tại.

Không khởi động lại primary cũ hoặc chạy lại toàn bộ cấu hình HA
trên các volume hiện có khi chưa có quy trình tái gia nhập phù hợp.
Không dùng volume dữ liệu nguồn làm đích khôi phục.

## Minh chứng

- [Ảnh TV1 — hạ tầng và failover](../results/evidence/tv1/)
- [Ảnh TV2 — backup và PITR](../results/evidence/tv2/)
- [Ảnh TV3 — tải và đo lường](../results/evidence/tv3/)
- [Dữ liệu và kết quả thử nghiệm](../results/)

## Công việc còn lại

1. Đo thêm nhiều lần và ở các mức tải khác nhau để đánh giá độ biến động của replication lag; xác định mục tiêu trước khi chạy.
2. Rà soát README và cập nhật sơ đồ theo kiến trúc, kết quả thực tế.
3. Bổ sung thử nghiệm xóa dữ liệu được sao chép sang replica
   rồi phục hồi bằng backup/PITR của cùng hệ thống HA.
   Bài PITR hiện tại được thực hiện trên môi trường riêng.
4. Xác định mục tiêu RPO/RTO trước các lần đo bổ sung,
   đo đầy đủ thời gian phục hồi dịch vụ.
5. Hoàn thiện chính sách retention, bản sao ngoài máy và bảo mật.
   Phân biệt rõ đề xuất với cơ chế đã triển khai, kiểm thử.
6. Hoàn thiện báo cáo, slide và video/demo.

## Giới hạn hiện tại

- Các container chạy trên cùng một Docker host.
- Failover chưa có cơ chế tự động phát hiện sự cố.
- Chưa đánh giá sự cố toàn host, tải cao hoặc nhiều lần thử lặp lại.
- Đối chiếu failover dựa trên ID giao dịch; PITR có kiểm tra số dòng và checksum.
- Đã có ảnh log PITR, chưa lưu log restore dạng văn bản riêng.
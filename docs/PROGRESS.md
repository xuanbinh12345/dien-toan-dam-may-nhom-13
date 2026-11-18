# Tiến độ dự án — Nhóm 13

Cập nhật ngày 19/11/2026.

## Trạng thái tích hợp mã nguồn

Đã gộp vào main trên GitHub:
- TV1: hạ tầng primary–replica và quy trình failover — PR #4.
- TV3: script tải, đo lag, đối chiếu giao dịch và kết quả — PR #6.
- TV2: backup, lưu WAL, PITR và minh chứng — PR #5.

Các phần hạ tầng, tải/đo, backup/PITR và kiểm chứng bổ sung đã được tích hợp vào main.
Kết quả lần thử kết hợp replication và PITR được ghi tại
[INT-20261118-150553](../results/INT-20261118-150553/README.md).

## Công việc đã thực hiện

| Phần | Kết quả |
|---|---|
| Hạ tầng | Dựng PostgreSQL primary–replica bằng Docker Compose; kiểm tra streaming replication bất đồng bộ |
| Dựng mới từ volume rỗng | Cụm lab13-bootstrap-check dùng volume và cổng riêng; primary streaming/async, replica ở recovery và đọc được đơn BOOTSTRAP-20261118-001 vừa ghi trên primary |
| Schema | Tạo bảng orders, khóa chính order_id và ràng buộc amount > 0 |
| Tải bình thường | 444 giao dịch ACK; 444 lần đọc thấy đơn hàng trên replica |
| Đo replication | Đã lưu CSV và biểu đồ; trong khoảng có tải có 258 mẫu, mean 1,326 ms, p95 1,797 ms, max 10,411 ms; WAL gap max 232 byte |
| Đo lặp replication | Cụm lab13-repeat: 3 mức nghỉ, mỗi mức 2 lượt; 1132/1132 ACK và 1132/1132 lần đọc thấy đơn; lưu CSV, manifest và bảng tổng hợp |
| Failover | Dừng primary bằng script, promote replica và chuyển đích ghi |
| Đối chiếu sau failover | 510/510 giao dịch ACK có trên primary mới; 1 UNCONFIRMED không có trong dữ liệu đối chiếu |
| Base backup | Tạo bản sao vật lý, kiểm tra pg_verifybackup thành công |
| WAL archive | Đã kiểm tra WAL được lưu vào thư mục archive |
| PITR | Khôi phục về thời điểm trước khi xóa 3 đơn hàng trong môi trường backup riêng |
| HA kết hợp PITR | Trên lab13-integrated, xóa 3 đơn đã lan sang replica; phục hồi từ base backup và WAL về trước lệnh xóa; 4/4 dòng và checksum khớp, sau đó đọc/ghi thành công |
| Kiểm tra PITR | Số dòng trước và sau khôi phục đều là 4; checksum khớp |
| Đọc/ghi sau PITR | Kết thúc recovery, ghi đơn hàng mới thành công và đọc lại được |
| Tái lập dự phòng sau failover | Trên lab13-bootstrap-check: dừng primary cũ, promote replica, tạo replica mới từ volume rỗng; primary mới thấy streaming/async và replica mới đọc được đơn REJOIN-20261118-001 trị giá 456.78 |
| Đo phục hồi database có kiểm soát | Trên lab13-repeat: từ yêu cầu dừng đến ghi và đọc lại thành công trên primary mới 1,078 giây, dưới mục tiêu thử nghiệm 30 giây; 1132/1132 ID ACK có mặt |
| Sao chép và PITR từ ổ D | Bản sao ngoài Docker volume được verify; 4 dòng và checksum khớp, ghi/đọc sau phục hồi thành công; ổ D vẫn ở cùng host |
| Ứng dụng sau PITR | Ứng dụng lab HTTP ghi và đọc lại đơn trên bản restore; run APP-PITR-20261118-184031-d5a9f5 PASS; database được truy cập qua Docker CLI/psql |

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

Phép thử bổ sung ngày 18/11 trên `lab13-rpo` giữ tải chạy trong lúc
failover có kiểm soát: [run FO-20261118-165349-5aac44](../results/RPO-FO-20261118-165349-5aac44.md)
có 204/204 ACK hiện diện trên primary mới, một UNCONFIRMED không hiện
diện và 1,333 giây từ yêu cầu dừng đến ACK đầu tiên trên node mới.

## Đo lặp và phục hồi bổ sung ngày 18/11/2026

Trên `lab13-repeat`, sáu lượt đo lag ở ba mức nghỉ đã được lưu cùng
[bảng số liệu và phương pháp](../results/repeat-lag-20261118/README.md).
Sau đó nhóm ghi [kế hoạch đo phục hồi](RECOVERY_MEASUREMENT_PLAN.md)
trước khi dừng primary. Run `REC-20261118-161901-297576` ghi nhận
1,078 giây từ yêu cầu dừng đến ghi và đọc lại thành công trên primary
đã promote; đối chiếu 1132/1132 mã ACK trước đó trên primary mới.
[CSV sự kiện và giới hạn](../results/recovery-REC-20261118-161901-297576/README.md).

1132 mã đã có trên replica trước khi dừng; phép đối chiếu này không đo
RPO tại thời điểm có giao dịch đang ghi. Thời gian đo chưa gồm tự động
phát hiện lỗi hoặc chuyển endpoint ứng dụng.

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

## Kết quả thử nghiệm kết hợp

Run ID: `INT-20261118-150553`.
Primary và replica đều còn 0 đơn thử nghiệm sau khi xóa.
PITR từ backup và WAL của cùng cụm dừng tại
`2026-11-18 08:08:44.585216+00`, trước commit xóa.
Bản phục hồi có 4 dòng; checksum trước/sau cùng là
`d86a2624608b97232e95955f5c8246fb`.
Sau khi kết thúc recovery, đơn mới trị giá 999.99 được ghi
và đọc lại thành công.

[CSV và diễn giải](../results/INT-20261118-150553/README.md) ·
[Runbook](INTEGRATED_PITR.md).

## Trạng thái môi trường ở cuối các lần thử

- lab13-isolated-primary-1: đã dừng.
- lab13-isolated-replica-1: đã promote thành primary mới.
- Chưa có replica thay thế cho primary mới.
- lab13-backup-source-1: nguồn của bài thử backup/PITR riêng.
- lab13-restore-restore-1: đã kết thúc recovery và kiểm tra đọc/ghi.
- lab13-bootstrap-check: đã promote replica cũ và tạo replica mới từ volume rỗng; primary cũ vẫn dừng.
- lab13-integrated: primary và replica nguồn đều đã áp dụng lệnh xóa; WAL được archive.
- lab13-integrated-restore-restore-1: đã kết thúc recovery và kiểm tra đọc/ghi sau PITR.

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

1. Rà soát [sơ đồ kiến trúc](ARCHITECTURE.md) khi cấu hình hoặc môi trường thay đổi.
2. Đánh giá nhiều lần failover, lỗi đột ngột, thời gian phát hiện lỗi và
   chuyển endpoint ứng dụng nếu muốn đưa ra mục tiêu RPO/RTO rộng hơn
   phép thử có kiểm soát.
3. Hoàn thiện chính sách retention, bản sao ngoài máy và bảo mật. Phân biệt rõ đề xuất với cơ chế đã triển khai, kiểm thử.
4. Hoàn thiện báo cáo, slide và video/demo.

## Giới hạn hiện tại

- Các container chạy trên cùng một Docker host.
- Failover chưa có cơ chế tự động phát hiện sự cố.
- Chưa đánh giá sự cố toàn host, nhiều client đồng thời hoặc nhiều lần failover.
- Đối chiếu failover dựa trên ID giao dịch; PITR có kiểm tra số dòng và checksum.
- Đã có ảnh log PITR, chưa lưu log restore dạng văn bản riêng.

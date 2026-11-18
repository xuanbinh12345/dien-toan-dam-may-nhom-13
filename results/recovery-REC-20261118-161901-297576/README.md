# Đo phục hồi database sau failover có kiểm soát

Run ID: `REC-20261118-161901-297576`, ngày 18/11/2026.
Kế hoạch và mục tiêu được ghi [trước khi chạy](../../docs/RECOVERY_MEASUREMENT_PLAN.md).
Thử trên cụm riêng `lab13-repeat` sau sáu lượt đo tải.

| Mốc UTC | Sự kiện |
|---|---|
| 16:19:01.5314443 | Yêu cầu dừng primary cũ |
| 16:19:02.0329209 | Xác nhận primary cũ đã dừng |
| 16:19:02.3058269 | Xác nhận promote replica |
| 16:19:02.4525896 | Ghi đơn mới được xác nhận |
| 16:19:02.6093895 | Đọc lại đúng đơn mới |

Từ yêu cầu dừng đến đọc lại thành công: **1,078 giây**, dưới mục tiêu
thử nghiệm 30 giây. Đơn mới là
`REC-20261118-161901-297576-POST-001`, amount `999.99`.
Script đã đối chiếu 1132 mã đơn được ACK trong sáu lượt tải trước đó;
**1132/1132 hiện diện, 0 mã thiếu** trên primary mới. Primary cũ được
giữ ở trạng thái dừng.

## Dữ liệu gốc

- [CSV sự kiện](events.csv).
- [CSV tổng kết](summary.csv).
- [Danh sách ACK thiếu](missing-ack-ids.txt): rỗng; file có thể chứa
  BOM UTF-8 khi tạo bằng PowerShell.
- [Script kiểm tra và chạy một lần](../../tests/measure-repeat-recovery.ps1).
- [Bộ sáu lượt tải trước failover](../repeat-lag-20261118/README.md).
- [Ảnh 30 — trạng thái hai container và kết quả đối chiếu](../evidence/tv3/30_phuc_hoi_doc_ghi_sau_failover.png).

## Phạm vi kết luận

Đây là thời gian **phục hồi khả năng ghi và đọc database** từ lúc
người vận hành yêu cầu dừng primary đến lúc truy vấn trên primary mới
thành công. Nó gồm dừng, promote, ghi và đọc, nhưng không gồm tự động
phát hiện sự cố, đổi endpoint ứng dụng, hay kiểm tra từ client ngoài
Docker host. Vì 1132 đơn đã được xác nhận có trên replica trước khi dừng,
đối chiếu này chứng minh bảo toàn dữ liệu đã sao chép; **không đo RPO tại
biên sự cố** hoặc bảo đảm RPO bằng 0 cho replication bất đồng bộ.

Chỉ một lần chuyển đổi được đo trên cùng Docker host. Không suy rộng
1,078 giây thành SLA hoặc kết quả cho lỗi host/lưu trữ.

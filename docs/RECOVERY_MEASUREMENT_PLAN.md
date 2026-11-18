# Kế hoạch đo phục hồi dịch vụ — lab13-repeat

Ngày lập: 18/11/2026. Kế hoạch được ghi **trước** khi dừng primary của
cụm `lab13-repeat`. Đây là phép thử failover do người vận hành kích hoạt,
không phải kiểm thử tự động phát hiện lỗi hay sự cố toàn Docker host.

## Điều kiện đầu

- `lab13-repeat-primary-1` là primary; `lab13-repeat-replica-1` ở recovery
  và streaming/async. Cụm dùng volume riêng, không phải `lab13-isolated`.
- Sáu lượt tải đã tạo 1132 đơn `LOAD-20261118-%`; cả primary và replica
  cùng đếm được 1132 trước khi thử chuyển đổi.
- Không khởi động lại primary cũ sau promote khi chưa có quy trình tái gia
  nhập. Giữ nguyên các volume của cụm để đối chiếu.

## Mục tiêu của lần thử có kiểm soát

1. **RPO quan sát:** không thiếu đơn nào đã được ACK trong tập đơn của
   sáu lượt tải trước failover. Đối chiếu theo `order_id` trên primary mới,
   không chỉ dựa vào tổng số dòng. Mục tiêu này áp dụng cho lần dừng
   primary có kiểm soát; replication async không bảo đảm RPO bằng 0 khi
   primary lỗi đột ngột. Vì 1132 đơn đã được xác nhận trên replica trước
   khi dừng, phép đối chiếu này kiểm tra bảo toàn dữ liệu đã sao chép,
   **không đo RPO tại biên sự cố**. Muốn đánh giá RPO lúc có giao dịch
   đang ghi phải chạy tải liên tục qua thời điểm dừng và đối chiếu ACK.
2. **Thời gian phục hồi dịch vụ database:** mục tiêu không quá 30 giây từ
   lúc gửi yêu cầu dừng primary đến lúc ghi một đơn mới lên primary đã
   promote **và đọc lại đúng đơn đó**. Ghi riêng các mốc dừng xong,
   promote xong, ghi thành công, đọc thành công. Đây là ngưỡng thử nghiệm
   trên cùng Docker host, không phải SLA sản xuất.
3. Ghi `pg_is_in_recovery()` trên nút mới và xác nhận nút cũ đã dừng.
   Không mở lại nút cũ để kiểm tra trong khi nút mới đang nhận ghi.

## Cách báo cáo

- Báo cả giá trị thực tế và việc đạt/chưa đạt mục tiêu; nếu lỗi, giữ lại
  log và sự kiện thay vì chỉ chạy lại rồi chọn lượt tốt nhất.
- Tách `ACK` khỏi giao dịch chưa xác nhận. Tổng số dòng bằng nhau không
  thay thế đối chiếu từng `order_id`.
- Thời gian trên không bao gồm tự động phát hiện sự cố, thay đổi endpoint
  ứng dụng hoặc kiểm tra ngoài Docker host. Ghi rõ phạm vi này khi kết luận.

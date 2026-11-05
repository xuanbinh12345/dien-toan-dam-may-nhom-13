# Hạ tầng PostgreSQL – Thành viên 1

## Nhiệm vụ đầu tiên
Dựng một máy chủ chính (primary) và một máy chủ bản sao (replica).
Kiểm tra việc sao chép bằng cách ghi một đơn hàng trên primary rồi đọc lại đơn hàng đó trên replica.

## Công việc cần thực hiện
- [ ] Thống nhất phiên bản PostgreSQL và báo cho TV2, TV3.
- [ ] Lưu cấu hình dựng primary và replica trong thư mục `infra/`.
- [ ] Dùng file `tests/schema.sql` do TV3 cung cấp để tạo bảng `orders`.
- [ ] Thêm một đơn hàng trên primary và truy vấn cùng `order_id` trên replica.

## Kết quả bàn giao
Bổ sung lệnh khởi động, lệnh kiểm tra và kết quả truy vấn vào README này
để một thành viên khác có thể chạy lại.

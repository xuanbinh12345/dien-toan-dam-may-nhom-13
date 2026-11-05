# Kiểm thử và đo lường – TV3

## Việc bàn giao đầu tiên
- [ ] Tạo `tests/schema.sql` để cả nhóm dùng chung bảng `orders`
      với các cột `order_id`, `amount` và `created_at`.
- [ ] Chạy thử file SQL trên PostgreSQL và gửi link file cho TV1, TV2.
- [ ] Viết script tạo đơn hàng thử nghiệm, mỗi đơn có một mã riêng.
- [ ] Xuất CSV ghi mã đơn, thời điểm UTC và trạng thái giao dịch.
      Chỉ ghi thành công sau khi PostgreSQL xác nhận commit.

## Khi ghép bài
- Cùng TV1 đo thời gian từ lúc primary dừng đến khi ứng dụng ghi lại được.
- Cùng TV2 kiểm tra số bản ghi và checksum sau khi phục hồi về trước lúc xóa.

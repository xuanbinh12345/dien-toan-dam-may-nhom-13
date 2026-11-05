# Sao lưu và phục hồi PostgreSQL – Thành viên 2

Thư mục này chứa các lệnh và hướng dẫn sao lưu PostgreSQL, lưu trữ nhật ký WAL và phục hồi dữ liệu đến một thời điểm xác định (PITR).

## Việc cần làm đầu tiên

- [ ] Tạo một bản sao lưu toàn phần trên môi trường thử nghiệm.
- [ ] Tạo giao dịch mới sau khi sao lưu và kiểm tra tệp WAL đã được lưu trữ thành công.
- [ ] Ghi lại lệnh đã chạy và cách kiểm tra kết quả để thành viên khác có thể làm lại.

## Kịch bản demo

Ghi nhận dữ liệu trước khi xóa một đơn hàng thử nghiệm. Phục hồi trên một PostgreSQL riêng đến thời điểm ngay trước giao dịch xóa, rồi kiểm tra đơn hàng đã xuất hiện trở lại.

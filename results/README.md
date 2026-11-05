# Kết quả thực nghiệm – Nhóm 13

## Thí nghiệm 1 – Primary ngừng hoạt động
TV1 và TV3 lưu độ trễ sao chép trước sự cố, thời điểm primary dừng,
thời điểm ứng dụng ghi thành công trở lại và danh sách giao dịch
đã được xác nhận nhưng còn thiếu trên primary mới (nếu có).

## Thí nghiệm 2 – Phục hồi sau khi xóa nhầm
TV2 và TV3 lưu mốc thời gian cần phục hồi, thời gian thực hiện PITR,
số bản ghi và checksum của bảng orders trước khi xóa và sau khi phục hồi.

## Cách lưu kết quả
Mỗi lần chạy dùng một thư mục riêng, ví dụ `failover/lan-01/` hoặc
`pitr/lan-01/`. Lưu CSV và log của lần chạy đó cùng nhau.
Ghi thời gian theo UTC và đơn vị đo trong tiêu đề cột.

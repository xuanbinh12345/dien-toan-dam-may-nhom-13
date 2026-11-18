# Bảo vệ và lưu giữ backup — đề xuất chưa triển khai

## Hiện trạng

Backup/WAL nằm trong Docker named volume trên cùng máy với database. Cổng chỉ bind localhost; mount vào môi trường restore là chỉ đọc. Đây chưa phải bảo vệ khỏi hỏng ổ đĩa/mất máy, và chưa có kiểm chứng mã hóa, lưu ngoài host hay lịch backup tự động.

## Phương án cần nhóm thống nhất

- Tạo physical base backup định kỳ, ví dụ mỗi ngày; giữ 7 bản ngày và 4 bản tuần tùy dung lượng và yêu cầu báo cáo. Đây là ngưỡng đề xuất, không phải yêu cầu giảng viên hay cấu hình đang chạy.
- Lưu liên tục WAL. Khi giữ một base backup, phải giữ đủ WAL từ lúc bắt đầu backup đó đến mốc phục hồi muốn hỗ trợ. Không xóa WAL chỉ theo tuổi file; cần xét toàn bộ backup còn giữ và timeline.
- Chỉ loại bản cũ sau khi backup mới đã verify, sao chép sang vị trí thứ hai và được thử phục hồi theo lịch. Chưa có lệnh xóa tự động trong gói.
- Sao chép backup + WAL + manifest sang host/object storage khác; một volume khác trên cùng Docker host chưa đáp ứng điều này.
- Dùng quyền truy cập tối thiểu, mã hóa đường truyền và lưu trữ theo hệ thống đích; quản lý khóa riêng khỏi backup. Không đặt thông tin đăng nhập vào Git hoặc ảnh.
- Theo dõi dung lượng, archived_count/failed_count, thời điểm WAL cuối và lỗi archive. archive_timeout 30 giây của lab không phải bảo đảm RPO 30 giây.
- Thử restore định kỳ và ghi RPO/RTO mục tiêu trước khi đo. Kết quả phải gồm cả kiểm tra dữ liệu và khả năng phục vụ đọc/ghi.

## Tiêu chí nghiệm thu bổ sung

Có cấu hình thực thi, log backup/copy, bằng chứng bản sao ngoài host, kiểm tra truy cập, bằng chứng phục hồi từ chính bản sao đó và quy trình xử lý khi thiếu WAL hoặc không đạt target. Chỉ đánh dấu hoàn tất sau khi kiểm chứng thực tế.

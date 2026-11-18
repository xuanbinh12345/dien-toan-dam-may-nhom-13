# Kết quả PITR-20261117-194600

Thời gian UTC. Base backup `base_20261117_193933`; phục hồi tới `2026-11-17 19:46:55.579505+00`.

| File | Nội dung |
|---|---|
| [pitr-info.json](pitr-info.json) | Run ID, source, backup path, target UTC và ba mã đơn bị xóa |
| [insert.sql](insert.sql) | Câu lệnh tạo ba đơn sau backup; dữ liệu lịch sử, không chạy lại trên nguồn hiện tại |
| [before-orders.csv](before-orders.csv) | Snapshot 4 dòng trước xóa, thời điểm tạo quy về UTC |
| [checksum.sql](checksum.sql) | Count và MD5 của JSON từng dòng theo thứ tự order_id, gồm mã đơn/số tiền/thời điểm tạo |
| [before-checksum.csv](before-checksum.csv) | Count 4 và checksum trước xóa |
| [delete.sql](delete.sql), [delete-result.txt](delete-result.txt) | Xóa riêng ba mã đơn, kết quả DELETE 3 |
| [restore-prepare-started-utc.txt](restore-prepare-started-utc.txt), [restore-prepare-finished-utc.txt](restore-prepare-finished-utc.txt) | Mốc chuẩn bị volume; không suy diễn là benchmark copy thuần |
| [restore-started-utc.txt](restore-started-utc.txt), [restore-to-pause.csv](restore-to-pause.csv) | Mốc khởi động và quan sát pause; 1,935 giây theo Stopwatch |
| [after-checksum.csv](after-checksum.csv), [checksum-comparison.csv](checksum-comparison.csv) | 4/4 dòng; checksum cả hai phía `32af3014e87e8c2c10683e8873cd2e9d`; hai kiểm tra True |
| [post-restore-write.sql](post-restore-write.sql) | Lượt ghi sau khi kết thúc recovery |
| [post-restore-read.csv](post-restore-read.csv), [post-restore-rw.csv](post-restore-rw.csv) | Kết nối mới đọc lại đơn POST-PITR, amount 999.99; ACK/OK, 1 dòng |
| [Thông tin base backup](../backup-base_20261117_193933.csv) | Mốc backup và kết quả verify |
| [Ảnh](../evidence/tv2/README.md) | 11 ảnh của các bước 12–16 |

## Kết luận có thể sử dụng

Trong lần thử, phục hồi về trước thao tác xóa đã lấy lại ba đơn tạo sau backup. Bảng phục hồi có 4 dòng, checksum khớp mẫu trước xóa. Sau khi kết thúc recovery, một lượt ghi mới được xác nhận và đọc lại thành công qua kết nối psql khác.

1,935 giây là thời gian khởi động tới quan sát pause, chưa bao gồm chuẩn bị, kiểm tra thủ công hoặc mở ghi. Không trình bày là tổng RTO. MD5 ở đây dùng đối chiếu dữ liệu, không phải xác thực an ninh/chống giả mạo. Chưa có log restore text; ảnh 15a chứa log gốc đã được người thực hiện chụp. Snapshot 4 dòng không bị thay thế sau khi kiểm thử ghi thêm dòng thứ 5.

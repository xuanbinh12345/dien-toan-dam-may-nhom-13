# Kế hoạch kiểm tra ACK tại biên failover — lab13-rpo

Lập trước khi dừng primary của cụm mới `lab13-rpo`. Cụm này dùng cổng
5583/5584 và volume riêng. Không chạy các lệnh dừng/promote trên những
cụm đã lưu minh chứng.

## Mục tiêu và phạm vi

- Chạy tải ghi liên tục trong lúc người vận hành dừng primary, promote
  replica và chuyển đích ghi. Mục tiêu của **lần dừng có kiểm soát**:
  không thiếu mã đơn nào đã được client xác nhận `ACK` trên primary mới.
- Ghi riêng `UNCONFIRMED`; giao dịch này có thể có hoặc không có trong
  database và không được gộp vào số ACK bị mất.
- Đo từ `stop_requested` đến ACK đầu tiên trên primary mới; ghi rõ đây
  là thời gian chuyển ghi quan sát, **không** gồm tự động phát hiện lỗi
  hoặc kiểm tra đọc qua endpoint ứng dụng.
- Replication là bất đồng bộ. Kết quả một lần dừng có kiểm soát không
  bảo đảm RPO bằng 0 khi primary chết đột ngột hoặc lỗi toàn host.

## Điều kiện trước khi dừng

1. `lab13-rpo-primary-1`: `pg_is_in_recovery() = f`.
   `lab13-rpo-replica-1`: `pg_is_in_recovery() = t`.
   Primary thấy replica `streaming/async`.
2. `public.orders` tồn tại trên cả hai nút; chỉ một tải failover chạy.
3. File `results/write-target.txt` được đặt thành
   `lab13-rpo-primary-1` ngay trước khi bắt đầu tải. File này được Git
   bỏ qua và sẽ được script chuyển sang replica sau promote.
4. Ghi lại đúng `Run ID` từ terminal tải. Khi chuyển đổi, truyền
   `-RunId` để không chọn nhầm CSV của lần thử trước.

## Thứ tự thao tác dự kiến

1. Terminal A chạy `failover-workload.ps1` với đúng hai container
   `lab13-rpo-*`, thời lượng 240 giây, khoảng nghỉ 1000 ms.
2. Sau khi đã thấy ACK trên primary cũ, terminal B chạy
   `invoke-failover.ps1` với cùng tên container, target file và Run ID.
   Script kiểm tra role, ACK gần nhất và trạng thái target trước khi dừng.
3. Đợi terminal A `DONE`. Giữ primary cũ dừng. Chạy
   `verify-failover.ps1` với Run ID và hai container để đối chiếu từng
   mã đơn được ACK/UNCONFIRMED trên primary mới.
4. Lưu CSV tải, CSV sự kiện, bảng đối chiếu và ảnh chụp trạng thái;
   không chạy lại script promote trên cùng cụm.

Nếu bất kỳ bước nào lỗi, ghi lại lỗi và trạng thái thực tế. Không bật
primary cũ hoặc chạy lại toàn bộ Compose để “sửa” khi replica đã promote.

# Vận hành tài nguyên, chi phí và rủi ro bảo mật

Tài liệu mô tả môi trường thử trên máy cá nhân và hướng dẫn dọn sau khi
đã lưu bằng chứng. Các thao tác dừng/xóa trong phần dưới là hướng dẫn,
không có nghĩa chúng đã được thực hiện.

## Kiểm tra và dọn tài nguyên

1. Ghi lại trạng thái trước khi dọn: `docker ps -a`, `docker volume ls`,
   `docker system df` và `git status --short --branch`. Xác nhận CSV,
   ảnh và runbook đã được lưu. Bản backup/WAL thực được giữ ngoài Git.
2. Xác định đúng project bằng lệnh read-only `docker compose ls -a`.
   Kiểm tra từng container/volume bằng `docker inspect` hoặc
   `docker volume inspect` trước khi thay đổi; đối chiếu với
   [sơ đồ kiến trúc](ARCHITECTURE.md).
3. Để **dừng** một project khi không cần chạy nữa, dùng đúng project và
   đúng các file Compose đã dùng cho nó. Ví dụ sau chỉ áp dụng cho
   `lab13-integrated` và sẽ dừng cả primary/replica của cụm này:

   ```powershell
   docker compose -p lab13-integrated --env-file infra/.env `
     -f infra/compose-integrated.yaml stop
   ```

   Không dừng cụm đang phục vụ thử nghiệm; sau failover không chạy `up`
   toàn bộ để khởi động lại primary cũ. Lệnh `stop` giữ container/volume.
4. Nếu cần gỡ container/network của một project, kiểm tra lại trạng thái
   và dùng `docker compose ... down` với **đúng project, file và env**.
   `down` sẽ gỡ container/network của project; mặc định giữ named volume.
   Không dùng `-v` khi còn cần dữ liệu. Kiểm tra cẩn thận các volume
   external được chia sẻ giữa source và restore.
5. Chỉ xóa volume hoặc bản sao trên ổ D sau khi nhóm xác định không cần
   dữ liệu đó và đã xác minh bản sao cần giữ. Các volume là dữ liệu thật:
   không chạy `docker system prune --volumes` hay xóa hàng loạt để giải
   phóng ổ C. Không có lệnh xóa tự động trong repository.

## Ước tính và kiểm soát chi phí

Các run đã lưu dùng Docker Desktop trên một máy cá nhân, PostgreSQL image
và dữ liệu tổng hợp; chưa có bằng chứng sử dụng dịch vụ cloud trả phí.
Không suy ra chi phí điện, bản quyền hoặc chi phí lưu trữ bằng 0. Ghi mức
sử dụng thực tế khi báo cáo: thời gian máy chạy, dung lượng backup/WAL,
và nếu dùng tài nguyên trả phí thì dịch vụ, đơn giá, thời gian, vùng,
lưu trữ và truyền dữ liệu.

Với phương án cloud dự kiến, ước tính riêng theo công thức: chi phí máy
= số giờ × đơn giá/giờ; lưu trữ = dung lượng trung bình × thời gian ×
đơn giá; cộng truyền dữ liệu và dịch vụ liên quan. Kiểm tra bảng giá của
nhà cung cấp tại thời điểm triển khai, đặt ngân sách/cảnh báo nếu dùng tài
nguyên có phí; hiện chưa có số tiền thực tế được xác nhận trong repo.

Trong lần kiểm tra ngày 19/11, `docker system df` báo local volumes khoảng
2,302 GB, ổ C còn khoảng 4,1 GiB. Đây là ảnh chụp một thời điểm, không
phải mức dùng cố định. Theo dõi dung lượng để tránh đầy ổ khi lưu WAL.

## Rủi ro và đề xuất

| Rủi ro | Bằng chứng / trạng thái | Hướng xử lý |
|---|---|---|
| Mất host hoặc thiết bị lưu trữ | Các cụm và bản sao ổ D cùng máy | Đề xuất bản sao backup/WAL ngoài miền lỗi, kiểm thử phục hồi từ chính bản sao đó; chưa kiểm thử. |
| Xóa nhầm/ransomware lan sang replica hoặc bản sao | Xóa đã lan sang replica trong run tích hợp | PITR đã thử; đề xuất quyền tối thiểu, bản sao bất biến và kiểm thử phục hồi định kỳ. |
| Lộ mật khẩu hoặc dữ liệu backup | File `.env` và dữ liệu backup không đưa vào Git theo quy ước | Kiểm tra trước khi commit/chụp ảnh; phân quyền, mã hóa đường truyền/lưu trữ và quản lý khóa riêng là đề xuất, chưa kiểm chứng. |
| Đầy dung lượng WAL/backup | Archive liên tục, không có lịch dọn đã kiểm thử | Theo dõi dung lượng và trạng thái archiver; lập lịch backup/retention theo [đề xuất](../backup/RETENTION.md). Không xóa WAL chỉ theo tuổi file. |
| Split-brain sau promote | Primary cũ phải giữ dừng; chưa thử tái gia nhập node cũ | Xác nhận node cũ dừng; chỉ tái gia nhập khi có quy trình và kiểm chứng riêng. |
| Image tag thay đổi | `postgres:16` là tag động; đã quan sát PostgreSQL 16.15 | Ghi phiên bản, digest và kiểm chứng tái lập; chưa khóa digest cho toàn bộ hệ thống. |

## Bàn giao và tái lập

- Repo cần README, sơ đồ, cấu hình, script, CSV/JSON thô và runbook;
  phiên bản PostgreSQL 16.15 là phiên bản quan sát, còn Docker/Compose
  cần ghi từ máy làm demo bằng `docker --version` và
  `docker compose version`. Không ghi số phiên bản khi chưa đo.
- [Bảng RPO/RTO](RPO_RTO_SUMMARY.md) phân biệt mục tiêu và quan sát.
  Trước nghiệm thu cần xác nhận lịch sử đóng góp của ba thành viên,
  kiểm tra bí mật/ảnh và tạo Git tag cho commit được nhóm chọn.
- Báo cáo theo đề dài 20–35 trang; video 8–12 phút hoặc demo 15–20 phút.
  Demo cần có luồng bình thường và ít nhất một tình huống lỗi.

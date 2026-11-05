# Nhóm 13 | Thiết kế cơ sở dữ liệu quan hệ sẵn sàng cao với sao lưu phục hồi đến thời điểm

**Môn học:** Điện toán đám mây 

Nhóm nghiên cứu cách phối hợp replication và backup để vừa giảm thời gian gián đoạn khi máy chủ chính dừng, vừa lấy lại dữ liệu khi người dùng xóa nhầm. Nhóm sẽ kiểm chứng bằng hai thí nghiệm trên dữ liệu đơn hàng giả lập.

Mở [3 Issue phân công](https://github.com/xuanbinh12345/dien-toan-dam-may-nhom-13/issues), tìm vai trò của mình trong bảng dưới, rồi làm theo mục **Bắt đầu trên máy cá nhân**. Mỗi người phụ trách một mảng kỹ thuật. Trưởng nhóm nhận một trong ba mảng và phụ trách thêm việc ghép bài.

## 1. Ai làm gì và bàn giao cho ai?

| Vai trò | Người nhận | Công việc và sản phẩm đầu tiên | Khi ghép bài |
|---|---|---|---|
| TV1 · Hạ tầng | [ tên] | Chốt phiên bản PostgreSQL, báo vào Issue. Dựng primary và replica bằng Docker Compose. Bàn giao cấu hình, cách khởi động và kết quả truy vấn cùng một mã đơn trên hai máy chủ trong `infra/`. | Cung cấp địa chỉ kết nối cho TV2, TV3. Đo độ trễ sao chép cùng TV3. Viết và chạy quy trình dừng primary, cô lập máy cũ, nâng replica thành primary mới rồi chuyển kết nối ứng dụng. |
| TV2 · Sao lưu và phục hồi | [ tên] | Dùng PostgreSQL riêng để thử sao lưu toàn phần và lưu trữ WAL (nhật ký ghi trước). Bàn giao lệnh backup, cách kiểm tra WAL và hướng dẫn khôi phục vào một môi trường riêng trong `backup/`. | Áp dụng cấu hình lên môi trường chung với TV1. Phục hồi đến mốc ngay trước khi xóa đơn hàng. Giao địa chỉ máy đã phục hồi cho TV3 kiểm tra. |
| TV3 · Dữ liệu và kiểm thử | [ tên] | Đưa `tests/schema.sql` lên trước để hai bạn dùng chung. Viết script tạo tải đọc/ghi, ghi nhận kết quả từng giao dịch ra CSV và hướng dẫn chạy trong `tests/`. | Giữ log phía ứng dụng, đo thời gian gián đoạn, tìm giao dịch thiếu, kiểm tra dữ liệu sau phục hồi và tạo lại bảng/biểu đồ từ số liệu thô. |

**Việc của leader trong buổi đầu:** điền ba tên ở bảng trên, ghi hạn bàn giao vào từng Issue và chốt lịch ghép bài. Trước buổi đo, cả nhóm ghi mục tiêu RPO/RTO cho từng kịch bản và lý do chọn ngưỡng. RPO thể hiện khoảng mất dữ liệu có thể chấp nhận, RTO thể hiện thời gian gián đoạn có thể chấp nhận.

## 2. Phần mềm và công cụ

Phương án đề xuất cho máy cá nhân là **Docker Compose + PostgreSQL**, dùng Python cho chương trình kiểm thử. TV1 ghi phiên bản PostgreSQL đã chốt tại đây: **[điền phiên bản/tag]**. Cả nhóm dùng cùng tag khi triển khai.

| Ai dùng | Công cụ | Dùng vào việc gì? |
|---|---|---|
| Cả nhóm | Git, tài khoản GitHub, PowerShell hoặc Terminal | Tải repo, tạo nhánh, đưa bài làm lên và theo dõi Issue. |
| Cả nhóm | Docker Desktop trên Windows/macOS, hoặc Docker Engine kèm Compose trên Linux | Chạy môi trường lab theo cùng cấu hình. Mở Docker trước khi khởi động lab. |
| Cả nhóm | Trình soạn thảo, ví dụ VS Code | Sửa SQL, YAML, Python và hướng dẫn Markdown. |
| TV1, TV2, TV3 | PostgreSQL và psql trong container | Tạo bảng, đọc/ghi dữ liệu và kiểm tra trạng thái. Có thể dùng thêm pgAdmin nếu muốn xem bảng bằng giao diện. |
| TV1 | Docker Compose, công cụ quản trị PostgreSQL | Dựng hai dịch vụ, kiểm tra replication và chuyển vai trò khi primary dừng. |
| TV2 | pg_basebackup và cơ chế lưu WAL của PostgreSQL | Tạo bản sao lưu vật lý, lưu WAL và phục hồi đến thời điểm đã chọn (PITR). |
| TV3 | Python 3, psycopg, mô-đun csv; matplotlib khi vẽ biểu đồ | Kết nối database, tạo giao dịch, ghi log và phân tích số liệu. TV3 ghi phiên bản thư viện đã thử vào `tests/requirements.txt`. |

## 3. Cấu trúc dự án

Các thư mục chia theo phần việc. Các file triển khai bên dưới là **đầu ra dự kiến** để từng người bổ sung khi hoàn thành task.

| Đường dẫn | Nội dung |
|---|---|
| `README.md` | Hướng dẫn chung, phân công, quy ước và trình tự ghép bài. |
| [infra/](infra/) | Hướng dẫn hạ tầng của TV1. Dự kiến có `compose.yaml`, cấu hình sao chép và quy trình failover. |
| [backup/](backup/) | Hướng dẫn của TV2, cấu hình lưu WAL, lệnh backup/restore và cách chọn mốc phục hồi. |
| [tests/](tests/) | Hướng dẫn của TV3, `schema.sql`, script tạo tải, truy vấn kiểm tra và script phân tích số liệu. |
| `results/failover/lan-01/` | CSV và log của một lần thử dừng primary. Tạo thư mục mới cho mỗi lần đo. |
| `results/pitr/lan-01/` | Mốc phục hồi, log và kết quả kiểm tra trước/sau của một lần thử xóa nhầm. |

## 4. Bắt đầu trên máy cá nhân

**Bước 1.** Mở PowerShell hoặc Terminal. Kiểm tra công cụ.

```sh
git --version
docker --version
docker compose version
docker info
```

TV3 kiểm tra thêm bằng `py --version` trên Windows hoặc `python3 --version` trên Linux/macOS. Nếu `docker info` báo lỗi kết nối, mở Docker Desktop hoặc khởi động Docker Engine rồi thử lại.

**Bước 2.** Tải repo lần đầu. Chạy từng dòng:

```sh
git clone https://github.com/xuanbinh12345/dien-toan-dam-may-nhom-13.git
cd dien-toan-dam-may-nhom-13
git status
```

Nếu đã tải repo, mở terminal trong thư mục dự án, chuyển về `main` rồi lấy bản mới bằng `git pull --ff-only`. Lưu công việc đang làm trước khi chuyển nhánh.

**Bước 3.** Mỗi người tạo một nhánh cho task mình nhận. Chạy **một** trong các lệnh dưới đây:

| Người thực hiện | Lệnh |
|---|---|
| TV1 | `git switch -c tv1/ha` |
| TV2 | `git switch -c tv2/backup-pitr` |
| TV3 | `git switch -c tv3/workload` |

**Bước 4.** Làm song song. TV1 chuẩn bị cụm và công bố phiên bản. TV3 tạo bảng trên một PostgreSQL thử nghiệm, gửi riêng phần `schema.sql` để leader ghép sớm vào main. TV2 thử cơ chế sao lưu trên máy riêng. Thống nhất database `ha_lab`, bảng `orders`, các cột `order_id` (mã duy nhất), `amount` và `created_at`. Dùng cùng file schema và giờ UTC cho các lần thử.

**Bước 5.** Khi TV1 đã bàn giao `infra/compose.yaml` và hướng dẫn biến môi trường, đứng ở thư mục gốc repo rồi chạy:

```sh
docker compose -f infra/compose.yaml config --quiet
docker compose -f infra/compose.yaml up -d
docker compose -f infra/compose.yaml ps
```

TV1 bổ sung vào `infra/README.md` tên dịch vụ thật, cổng truy cập, cách nạp schema và câu lệnh kiểm tra replication. Cả nhóm chỉ bắt đầu đo khi ghi một đơn trên primary và đọc lại đúng mã đơn trên replica. Khi kết thúc buổi thử, dừng cụm bằng `docker compose -f infra/compose.yaml stop` để giữ dữ liệu cho buổi sau.

## 5. Quy trình giao và nhận bài trên GitHub

1. Người nhận mở Issue và ghi ngày dự kiến bàn giao. Nếu cần đầu vào, bình luận rõ tên file hoặc thông tin cần từ bạn nào.
2. Làm và kiểm tra trên nhánh riêng. Ví dụ TV1 chạy `git add infra/`, `git commit -m "Dựng cụm primary và replica"`, rồi `git push -u origin tv1/ha`. TV2, TV3 thay bằng thư mục và nhánh tương ứng. Để đẩy lên repo chung, thành viên cần nhận lời mời cộng tác của leader.
3. Trên GitHub, mở **Pull request** vào `main`. Ghi Issue liên quan, thay đổi đã làm, lệnh chạy và kết quả mong đợi.
4. Một người khác chạy lại theo README của thư mục. Khi kết quả đúng, leader ghép thay đổi và đóng Issue đã hoàn thành. Mỗi người cập nhật hướng dẫn cùng lúc với cấu hình hoặc script.

Repo công khai. Chỉ đưa dữ liệu giả lập, mã nguồn, ví dụ cấu hình và log đã kiểm tra lên GitHub. Giữ mật khẩu, file `.env`, thư mục dữ liệu PostgreSQL, bản sao lưu thật và WAL trên máy lab. TV1 bổ sung `.gitignore` và ví dụ biến môi trường trước lần đưa cấu hình lên đầu tiên.

## 6. Chạy hai thí nghiệm chung

### A. Primary dừng trong lúc ứng dụng đang ghi

1. TV3 chạy tải liên tục, ghi log phía ứng dụng gồm mã đơn, thời điểm UTC và kết quả. Chỉ đánh dấu thành công sau khi nhận xác nhận commit; ghi riêng các giao dịch mất kết nối trước khi biết kết quả.
2. TV1 thu số liệu độ trễ sao chép, ghi rõ đơn vị và thời điểm lấy mẫu. Dừng primary và đánh dấu thời điểm sự cố.
3. TV1 thực hiện failover theo hướng dẫn. TV3 ghi thời điểm ứng dụng commit thành công đầu tiên trên primary mới.
4. Tính thời gian gián đoạn từ lúc primary dừng đến lần commit thành công đó. Đối chiếu các mã đơn đã được xác nhận trước sự cố với dữ liệu trên primary mới; lưu danh sách và số lượng mã thiếu.

### B. Xóa nhầm đơn hàng và phục hồi bằng PITR

1. Trên môi trường đã chuẩn bị lại, TV2 kiểm tra bản backup và WAL. TV3 tạo dữ liệu mẫu, ghi nhận mã đơn, số dòng và checksum. Tạm dừng ghi khi lấy mẫu chuẩn để có thể so sánh đúng trạng thái.
2. Ghi mốc UTC cần phục hồi ngay trước thao tác xóa. Thực hiện và commit lệnh xóa thử; TV1 kiểm tra thao tác đã lan sang replica. TV2 xác nhận WAL cần cho lần thử đã được lưu.
3. TV2 dùng backup và WAL để phục hồi vào một PostgreSQL riêng đến mốc đã chọn. Ghi thời điểm bắt đầu, kết thúc và cung cấp địa chỉ kết nối cho TV3.
4. TV3 so sánh mã đơn, số dòng và checksum với mẫu chuẩn, sau đó thử đọc/ghi từ ứng dụng. Lưu kết quả vào thư mục riêng của lần chạy.

## 7. Ghi số liệu và nghiệm thu

| Trước khi đo | Sau mỗi lần chạy |
|---|---|
| Ghi phiên bản, điều kiện tải, chế độ sao chép, mục tiêu RPO/RTO và mốc bắt đầu/kết thúc phép đo. | Lưu CSV thô, log UTC, số lần chạy, độ trễ, thời gian gián đoạn/phục hồi và kết quả kiểm tra dữ liệu. |
| Chọn cách đánh giá mức mất dữ liệu theo thời gian; ghi thêm mã giao dịch để đối chiếu. | Báo cáo riêng số giao dịch thiếu và khoảng thời gian mất dữ liệu quan sát được. Nếu thiếu mốc đo, ghi rõ giới hạn. |
| Thống nhất ai chạy, ai quan sát, ai lưu kết quả. | So sánh mục tiêu với số liệu thực tế. Mỗi biểu đồ có tên trục, đơn vị, điều kiện đo và số lần lặp. |

**Nhóm bàn giao:** cấu hình và mã nguồn có lịch sử đóng góp của ba thành viên, sơ đồ kiến trúc và luồng backup/WAL, hướng dẫn tái lập, dữ liệu thô và script vẽ biểu đồ. Báo cáo 20–35 trang trình bày hai kịch bản, kết quả, giới hạn khi chạy trên cùng một máy, lịch sao lưu, thời gian lưu giữ và phương án giữ bản sao ngoài máy chủ. Chuẩn bị video 8–12 phút hoặc demo trực tiếp 15–20 phút theo hướng dẫn học phần.

## 8. Tài liệu tham khảo

1. Bài giảng Chương 3 – Lưu trữ và xử lý dữ liệu.
2. Bài giảng Chương 4 – An toàn và bảo mật đám mây.
3. [NIST SP 800-34 Rev. 1 – Contingency Planning Guide for Federal Information Systems](https://doi.org/10.6028/NIST.SP.800-34r1).
4. [PostgreSQL Documentation](https://www.postgresql.org/docs/) – chọn đúng phiên bản nhóm triển khai khi tra cứu replication, failover, backup và PITR.

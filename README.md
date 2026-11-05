# Đề tài 13 – Thiết kế cơ sở dữ liệu quan hệ sẵn sàng cao với sao lưu phục hồi đến thời điểm

**Môn học:** Điện toán đám mây   
**Hệ quản trị cơ sở dữ liệu:** PostgreSQL

## 1. Câu hỏi nghiên cứu

Cơ chế replication và backup cần phối hợp ra sao để vừa giảm gián đoạn vừa tránh mất dữ liệu do lỗi thao tác?

## 2. Mục tiêu

- Triển khai một máy chủ chính (primary) và ít nhất một máy chủ bản sao (replica), có giám sát độ trễ sao chép.
- Thiết lập sao lưu toàn phần và lưu trữ nhật ký WAL để phục hồi cơ sở dữ liệu về một thời điểm xác định (PITR).
- Thử nghiệm hai tình huống: máy chủ chính ngừng hoạt động và người dùng xóa nhầm dữ liệu. Đối chiếu kết quả đo với mục tiêu RPO/RTO đã đặt trước.

## 3. Phân công và việc làm đầu tiên

| Vai trò | Người phụ trách | Việc làm đầu tiên | Kết quả cần bàn giao |
|---|---|---|---|
| TV1 – Hạ tầng và failover | [Tên người nhận TV1] | Dựng primary và replica. Thêm một đơn hàng trên primary rồi đọc lại trên replica. | File cấu hình, các lệnh chạy và kết quả truy vấn cho thấy cùng một mã đơn trên hai máy chủ. |
| TV2 – Sao lưu và PITR | [Tên người nhận TV2] | Trên PostgreSQL riêng, tạo bản sao lưu toàn phần, phát sinh giao dịch mới và kiểm tra WAL đã được lưu trữ. | Các lệnh sao lưu, nhật ký chạy và tên tệp WAL đã lưu. |
| TV3 – Dữ liệu và kiểm thử | [Tên người nhận TV3] | Tạo file `tests/schema.sql` cho bảng `orders`, sau đó viết script tạo giao dịch thử. | File SQL dùng chung, script chạy thử và CSV ghi mã đơn, thời điểm, trạng thái giao dịch. |

## 4. Quy ước để làm song song

- TV3 đưa `tests/schema.sql` lên repo trước để cả nhóm dùng cùng cấu trúc bảng `orders`.
- TV2 và TV3 bắt đầu trên PostgreSQL riêng. Khi cụm của TV1 sẵn sàng, cả nhóm chạy cùng bộ kiểm thử trên cụm chung.
- Môi trường đề xuất: Docker Compose trên máy cá nhân. Phiên bản PostgreSQL cụ thể sẽ được ghi tại đây sau khi nhóm thống nhất.
- Dùng giờ UTC trong log để đối chiếu thời điểm xảy ra sự cố và thời điểm phục hồi.
- Dùng dữ liệu đơn hàng giả lập. Giữ mật khẩu và file `.env` thật trên máy cá nhân.

## 5. Hai kịch bản demo

| Kịch bản | Cách kiểm chứng |
|---|---|
| Primary ngừng hoạt động | Dừng primary, chuyển replica thành primary mới. Đo thời gian đến khi ứng dụng ghi thành công trở lại và đối chiếu các mã giao dịch đã được xác nhận trước sự cố. |
| Xóa nhầm dữ liệu | Ghi nhận trạng thái bảng trước khi xóa. Xác nhận thao tác xóa đã lan sang replica, rồi dùng bản sao lưu và WAL để phục hồi về ngay trước giao dịch xóa. Kiểm tra số bản ghi, checksum và thử đọc/ghi sau phục hồi. |

## 6. Tài liệu tham khảo

1. Bài giảng Chương 3.
2. Bài giảng Chương 4.
3. [NIST SP 800-34 Rev. 1](https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-34r1.pdf) – *Contingency Planning Guide for
Federal Information Systems*.
4. [PostgreSQL Documentation](https://www.postgresql.org/docs/).

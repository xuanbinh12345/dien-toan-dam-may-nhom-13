# Nhóm 13 — PostgreSQL HA, Backup và PITR

**Môn học:** Điện toán đám mây.

Dự án thử nghiệm streaming replication, chuyển đổi primary khi
primary cũ dừng và khôi phục dữ liệu đến thời điểm trước khi xóa nhầm.

Môi trường triển khai: Docker Desktop, Docker Compose, PostgreSQL
và các script PowerShell gọi psql trong container.

## 1. Tiến độ hiện tại

Đã tích hợp phần việc của ba thành viên vào main:

| Phần việc | Nội dung đã bàn giao | Pull request |
|---|---|---|
| TV1 — Hạ tầng | Primary–replica, kiểm tra replication, script và quy trình failover, minh chứng | [#4](https://github.com/xuanbinh12345/dien-toan-dam-may-nhom-13/pull/4) |
| TV3 — Tải và đo lường | Script tải, đo lag, đối chiếu giao dịch, CSV và minh chứng | [#6](https://github.com/xuanbinh12345/dien-toan-dam-may-nhom-13/pull/6) |
| TV2 — Backup/PITR | Base backup, WAL archive, phục hồi theo thời điểm, kiểm tra dữ liệu và đọc/ghi | [#5](https://github.com/xuanbinh12345/dien-toan-dam-may-nhom-13/pull/5) |

Xem [tiến độ và công việc còn lại](docs/PROGRESS.md).

Các phép thử hạ tầng, tải/đo, backup/PITR và kết hợp replication với PITR
đã có kết quả và dữ liệu lưu trong repository. Dự án còn cần đo bổ sung,
hoàn thiện sơ đồ và báo cáo.

## 2. Môi trường thử nghiệm

Image của môi trường nguồn: `postgres:16`.
Phiên bản quan sát trong các lần thử đã lưu: PostgreSQL 16.15.
Tag `postgres:16` có thể thay đổi theo các bản cập nhật.

| Môi trường | Container | Cổng trên máy host |
|---|---|---|
| HA — primary ban đầu | lab13-isolated-primary-1 | 5543 |
| HA — replica ban đầu | lab13-isolated-replica-1 | 5544 |
| Nguồn backup/PITR riêng | lab13-backup-source-1 | 5545 |
| PostgreSQL phục hồi | lab13-restore-restore-1 | 5546 |
| Cụm tích hợp — primary | lab13-integrated-primary-1 | 5563 |
| Cụm tích hợp — replica | lab13-integrated-replica-1 | 5564 |
| Bản phục hồi từ cụm tích hợp | lab13-integrated-restore-restore-1 | 5565 |

Cổng PostgreSQL bên trong container là 5432.
Database thử nghiệm là `ha_lab`, bảng dữ liệu là `public.orders`.

Đã thực hiện hai bài thử riêng và một bài thử tích hợp replication với
backup/PITR trên cụm `lab13-integrated`.

### Trạng thái cuối các lần thử

- Primary cũ của cụm HA đã dừng.
- Replica cũ đã được promote thành primary mới; tên container giữ nguyên.
- Cụm `lab13-isolated` chưa có replica thay thế; trên cụm thử
  `lab13-bootstrap-check` đã tạo replica mới sau failover.
- PostgreSQL phục hồi đã kết thúc recovery và kiểm tra đọc/ghi thành công.

Không chạy lại toàn bộ cụm HA hoặc khởi động primary cũ trên dữ liệu
hiện có khi chưa thực hiện quy trình tái gia nhập phù hợp.
Trạng thái trên được ghi nhận cuối lần thử, không phải trạng thái giám sát trực tiếp.

## 3. Kết quả chính

| Phép thử | Kết quả quan sát |
|---|---|
| Tải bình thường | 444 ACK; 444 lần đọc thấy đơn hàng trên replica |
| Replication lag | Trong 258 mẫu khi có tải: mean 1,326 ms; p95 1,797 ms; max 10,411 ms |
| Tải khi failover | 511 lần thử ghi: 510 ACK và 1 UNCONFIRMED |
| Đối chiếu failover | 510/510 ACK hiện diện trên primary mới |
| Khôi phục ghi sau yêu cầu dừng | 2,316 giây đến ACK đầu tiên trên primary mới |
| Base backup | pg_verifybackup thành công |
| PITR trước khi xóa | Khôi phục 3 đơn hàng đã xóa; tổng số dòng trở lại 4 |
| Kiểm tra dữ liệu PITR | Số dòng và checksum trước/sau khớp |
| Khởi động restore đến quan sát paused | 1,935 giây |
| Đọc/ghi sau PITR | Ghi đơn hàng mới thành công và đọc lại được |
| HA kết hợp PITR | Xóa 3 đơn đã lan sang replica; bản PITR có lại 4 dòng, checksum khớp và đọc/ghi thành công |
| Đo lag lặp | 6 lượt ở 3 mức nghỉ; 1132/1132 ACK và 1132/1132 lần đọc thấy đơn |
| Failover khi có tải | 204/204 ACK hiện diện; 1 UNCONFIRMED không hiện diện; 1,333 giây đến ACK đầu tiên trên node mới |
| Phục hồi database có kiểm soát | 1,078 giây từ yêu cầu dừng đến ghi và đọc lại thành công; không gồm phát hiện lỗi hay chuyển endpoint |
| PITR từ bản sao ổ D | Backup verify thành công; 4 dòng và checksum khớp, ghi/đọc thành công; bản sao nằm cùng host |

Chi tiết, run ID và dữ liệu thô: [results/README.md](results/README.md).

**Giới hạn diễn giải:**

- Failover được người vận hành kích hoạt bằng script, chưa tự động phát hiện lỗi.
- 2,316 giây tính từ yêu cầu dừng primary đến ACK đầu tiên trên primary mới,
  bao gồm thời gian điều khiển và chờ lượt ghi.
- Không coi giao dịch UNCONFIRMED là giao dịch ACK bị mất.
- Không thiếu ACK trong một lần thử không chứng minh RPO luôn bằng 0.
- 1,935 giây chưa phải RTO toàn bộ quá trình PITR.
- Các container chạy trên cùng một Docker host.
- Bài thử kết hợp được thực hiện một lần trên cùng Docker host;
  chưa đo RTO toàn bộ quy trình hoặc sự cố toàn host.
- Sáu lượt đo lag là tải tuần tự qua Docker CLI; không phải benchmark
  nhiều client đồng thời. Bản sao trên ổ D chưa phải bản sao ngoài host.
- 1,333 giây là từ yêu cầu dừng đến ACK đầu tiên; 1,078 giây là đến khi
  ghi và đọc lại thành công trong một run khác. Không coi hai số là SLA.

## 4. Cấu trúc và hướng dẫn

| Đường dẫn | Nội dung |
|---|---|
| [docs/PROGRESS.md](docs/PROGRESS.md) | Tiến độ, trạng thái cuối lần thử và công việc còn lại |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Sơ đồ các môi trường HA, PITR tích hợp và bản sao trên ổ D |
| [infra/README.md](infra/README.md) | Hướng dẫn hạ tầng |
| [infra/compose-isolated.yaml](infra/compose-isolated.yaml) | Cấu hình cụm HA dùng trong lần thử đã lưu |
| [infra/FAILOVER.md](infra/FAILOVER.md) | Quy trình chuyển đổi primary |
| [infra/REJOIN.md](infra/REJOIN.md) | Tạo replica mới sau failover trên cụm thử |
| [infra/compose-integrated.yaml](infra/compose-integrated.yaml) | Cụm replication có WAL archive và base backup |
| [backup/README.md](backup/README.md) | Tổng quan backup/PITR |
| [backup/RUNBOOK.md](backup/RUNBOOK.md) | Hướng dẫn thực hiện backup và phục hồi |
| [backup/RETENTION.md](backup/RETENTION.md) | Đề xuất lưu giữ và bảo vệ bản sao |
| [docs/INTEGRATED_PITR.md](docs/INTEGRATED_PITR.md) | Runbook thử nghiệm kết hợp replication và PITR |
| [tests/README.md](tests/README.md) | Cách chạy script tải và kiểm tra |
| [tests/schema.sql](tests/schema.sql) | Schema dùng chung |
| [results/README.md](results/README.md) | Dữ liệu thô và diễn giải kết quả |
| [results/INT-20261118-150553/README.md](results/INT-20261118-150553/README.md) | CSV và kết quả thử nghiệm kết hợp |
| [results/evidence/](results/evidence/) | Ảnh minh chứng theo phần việc |

## 5. Bắt đầu trên máy cá nhân

Cài Git, Docker Desktop và sử dụng PowerShell.
Có thể dùng VS Code để chỉnh sửa SQL, YAML, PowerShell và Markdown.

Các script kiểm thử hiện có sử dụng PowerShell và psql trong container;
không yêu cầu cài PostgreSQL hoặc Python trên host để chạy các script này.

Kiểm tra công cụ:

```powershell
git --version
docker --version
docker compose version
docker info

```

Đọc hướng dẫn tương ứng trong infra/, backup/ và tests/.
Chuẩn bị các file môi trường theo mẫu, dùng mật khẩu riêng cho máy lab.

Nếu đã có repository, không clone thêm vào bên trong thư mục dự án.
Lưu các thay đổi chưa commit trước khi chuyển nhánh hoặc cập nhật code.

Không chạy lại thử nghiệm trên volume hiện có chỉ để lấy ảnh.
Khi tái lập, dùng môi trường riêng và làm theo điều kiện đầu vào của runbook.

## 6. Quy ước làm việc và dữ liệu

- Thực hiện thay đổi trên nhánh riêng, kiểm tra rồi tạo PR vào main.
- Mô tả chính xác phần đã thực hiện và kết quả kiểm thử trong PR.
- Chỉ thêm vào commit các file thuộc phạm vi thay đổi.
- Giữ nguyên run ID để ghép đúng CSV, mốc thời gian và minh chứng.
- Thời gian dùng UTC; ghi rõ đơn vị trong bảng và biểu đồ.
- Không commit mật khẩu, file .env, volume dữ liệu, base backup hoặc WAL thật.
- results/write-target.txt là trạng thái cục bộ, được Git bỏ qua.
- Tài liệu retention là đề xuất; không coi là cơ chế tự động đã kiểm thử.

## 7. Công việc còn lại và sản phẩm cuối

- Đánh giá thêm failover đột ngột, nhiều client đồng thời và nhiều lần
  thử; đặt mục tiêu RPO/RTO trước từng phép thử bổ sung.
- Đo thêm thời gian phát hiện lỗi và chuyển endpoint ứng dụng nếu cần
  đánh giá thời gian phục hồi dịch vụ đầu cuối.
- Hoàn thiện hướng dẫn và chính sách bảo vệ bản sao; kiểm thử bản sao
  trên thiết bị khác nếu có điều kiện.
- Hoàn thiện báo cáo 20–35 trang, slide và video 8–12 phút
  hoặc demo trực tiếp 15–20 phút theo hướng dẫn học phần.

## 8. Tài liệu tham khảo

1. Bài giảng Chương 3 — Lưu trữ và xử lý dữ liệu.
2. Bài giảng Chương 4 — An toàn và bảo mật đám mây.
3. [NIST SP 800-34 Rev. 1](https://doi.org/10.6028/NIST.SP.800-34r1).
4. [PostgreSQL 16 Documentation](https://www.postgresql.org/docs/16/).

# Hướng dẫn dựng slide bảo vệ dự án — Nhóm 13

Tài liệu này là kịch bản cho **30 slide nội dung**. Trang bìa, giới thiệu thành viên, mục lục, tài liệu tham khảo và hỏi đáp nằm ngoài số 30 này. Dùng kết quả trong repository tại thời điểm làm slide; nếu có phép đo mới, cập nhật số liệu và nguồn trước khi xuất bản.

## Quy cách chung

- Khung hình 16:9; nền sáng, chữ tối; một màu nhấn cho HA/replication và một màu nhấn cho backup/PITR.
- Mỗi slide có **một kết luận** làm tiêu đề hoặc dòng chốt. Phần thân tối đa 3 ý ngắn; tránh chụp toàn màn hình terminal khi chỉ cần một kết quả.
- Bố cục ưu tiên: trái 35–40% là sơ đồ hoặc ảnh, phải 60–65% là diễn giải; với biểu đồ cho biểu đồ chiếm 70–80% diện tích.
- Chữ tiêu đề khoảng 28–34 pt, nội dung 20–24 pt, chú thích ảnh 12–16 pt. Giữ chữ trong ảnh đủ lớn khi trình chiếu.
- Ảnh lấy từ các đường dẫn bên dưới. Cắt phần thừa của ảnh khi đặt lên slide nhưng giữ lệnh, kết quả và tên môi trường đủ để kiểm chứng. Không sửa số liệu trong ảnh.
- Dưới ảnh/biểu đồ ghi nguồn ngắn, ví dụ `Nguồn: results/evidence/tv3/19_...png; run LOAD-20261117-141855`.
- Có ba môi trường khác nhau: `lab13-isolated` (HA/failover), môi trường backup/PITR riêng, và `lab13-integrated` (replication + PITR). Không ghép ảnh của môi trường này thành một lần chạy của môi trường khác.
- Những số liệu failover, lag và PITR chỉ thuộc **một lần thử**. Không ghi “RPO = 0”, “RTO = 2,316 giây” hoặc “tự động failover”.

Đường dẫn ảnh trong bảng tính từ gốc repository. Nếu PowerPoint không mở liên kết tương đối, dùng File Explorer để chèn ảnh từ `results/evidence/`.

## Trang phụ, không tính vào 30 slide nội dung

1. Bìa: tên học phần, đề tài, nhóm, giảng viên, ngày.
2. Giới thiệu nhóm: TV1/TV2/TV3 và phần việc thực tế. Ghi tác giả theo đóng góp thật trong Git, không gán các phép thử tích hợp cho riêng TV1 hoặc TV2.
3. Mục lục: 4 phần — kiến trúc, HA, backup/PITR, kết quả và giới hạn.
4. Cuối bài: tài liệu tham khảo và hỏi đáp.

## Phần A — Bài toán và thiết kế

### Slide 01 — Hai dạng sự cố cần xử lý

- **Thông điệp:** Dừng primary và xóa nhầm dữ liệu cần hai cách phục hồi khác nhau.
- **Chữ trên slide:** `Primary dừng → cần chuyển vai trò`; `Xóa nhầm → lệnh xóa cũng được sao chép`; `PITR → quay về trước thời điểm xóa`.
- **Bố cục:** Hai nhánh từ một database: “mất primary” và “xóa dữ liệu”, phía dưới là failover/PITR. Tự vẽ bằng hình khối, không cần ảnh terminal.

### Slide 02 — Mục tiêu và phạm vi kiểm chứng

- **Thông điệp:** Nhóm kiểm thử cả tính liên tục ghi và khôi phục dữ liệu, trong phạm vi một Docker host.
- **Chữ:** Dựng primary–replica; chạy tải và đo lag; failover thủ công; backup/WAL/PITR; thử xóa lan sang replica rồi PITR.
- **Bố cục:** 5 thẻ mục tiêu, mỗi thẻ một biểu tượng. Chân trang ghi `Môi trường lab, chưa kiểm thử lỗi toàn host`.
- **Nguồn:** [README](../README.md), [tiến độ](PROGRESS.md).

### Slide 03 — Kiến trúc tổng thể

- **Thông điệp:** Replication phục vụ chuyển vai trò; backup và WAL archive phục vụ quay lại trạng thái cũ.
- **Chữ:** Primary → replica (streaming async); primary → WAL archive + base backup → restore.
- **Bố cục:** Vẽ lại sơ đồ rõ ràng, không dùng ảnh cũ như cấu hình duy nhất của mọi lần thử.
- **Ảnh tham khảo:** [Sơ đồ hiện tại](../results/evidence/tv1/02_so_do_kien_truc_hien_tai.png). Đối chiếu với [Compose tích hợp](../infra/compose-integrated.yaml) trước khi vẽ.

### Slide 04 — Ba môi trường thử nghiệm

- **Thông điệp:** Các kết quả đến từ ba môi trường tách biệt.
- **Chữ:** `lab13-isolated`: tải/failover; `lab13-backup-source` + restore: PITR riêng; `lab13-integrated` + restore: xóa lan sang replica rồi PITR.
- **Bố cục:** Bảng 3 hàng gồm môi trường, mục đích, kết quả chính. Không nối các run thành một chuỗi thời gian duy nhất.

### Slide 05 — Công cụ và cách tái lập

- **Thông điệp:** Docker Compose cấu hình cụm; PowerShell và `psql` chạy phép thử, CSV lưu kết quả.
- **Chữ:** PostgreSQL 16; Docker Compose; PowerShell; `pg_basebackup`, `pg_verifybackup`, `psql`.
- **Bố cục:** Sơ đồ “cấu hình → chạy → đo → lưu bằng chứng”.
- **Ảnh:** [Phiên bản công cụ](../results/evidence/tv1/01_phien_ban_docker_compose_postgresql.png).

### Slide 06 — Cấu trúc repository và run ID

- **Thông điệp:** Mỗi phép thử có cấu hình, script, dữ liệu và ảnh để đối chiếu.
- **Chữ:** `infra/` hạ tầng; `backup/` phục hồi; `tests/` tải/đo; `results/` CSV, biểu đồ, ảnh. Nêu ví dụ run ID `LOAD-20261117-141855`, `FO-20261117-151645-24e67c`, `INT-20261118-150553`.
- **Bố cục:** Cây thư mục đơn giản tự vẽ; không đưa ảnh màn hình Explorer quá nhiều chữ.

### Slide 07 — Schema và đơn hàng đối chiếu

- **Thông điệp:** `order_id` giúp đối chiếu giao dịch; `amount` và thời điểm tạo giúp kiểm tra PITR.
- **Chữ:** Bảng `public.orders`; khóa chính `order_id`; `amount > 0`. Run ID nằm trong mã đơn thử nghiệm.
- **Bố cục:** Bảng 3 cột và một đơn hàng mẫu.
- **Ảnh:** [Cấu trúc bảng](../results/evidence/tv3/04_cau_truc_bang_orders.png); [SQL schema](../tests/schema.sql).

## Phần B — Replication, tải và failover

### Slide 08 — Streaming replication bất đồng bộ

- **Thông điệp:** Replica nhận WAL từ primary và ở trạng thái recovery khi chưa promote.
- **Chữ:** `state = streaming`, `sync_state = async`, `pg_is_in_recovery() = true` trên replica.
- **Bố cục:** Sơ đồ mũi tên WAL ở trái, trích hai dòng kết quả ở phải.
- **Ảnh:** [Trạng thái replication](../results/evidence/tv1/05_trang_thai_replication.png).

### Slide 09 — Khởi tạo lại từ volume rỗng

- **Thông điệp:** Nhóm đã dựng riêng một cụm mới, không phụ thuộc dữ liệu còn trên volume cũ.
- **Chữ:** Project `lab13-bootstrap-check`, primary healthy, replica streaming/async.
- **Bố cục:** Ảnh lớn 2/3 slide; cạnh phải ghi ba bước: volume mới → khởi động → kiểm tra.
- **Ảnh:** [Dựng mới và replication](../results/evidence/tv1/20_dung_moi_tu_volume_rong_va_replication.png).

### Slide 10 — Kiểm chứng cùng đơn trên primary và replica

- **Thông điệp:** Ghi trên primary, đọc lại được trên replica.
- **Chữ:** Chỉ một đơn mẫu và hai kết quả đọc; nêu đây là kiểm tra chức năng, không phải đo RPO.
- **Bố cục:** Hai ô song song “primary” và “replica”, đánh dấu cùng `order_id`.
- **Ảnh:** [Cùng đơn hàng](../results/evidence/tv1/06_cung_don_hang_primary_replica.png).

### Slide 11 — Thiết kế phép thử tải

- **Thông điệp:** Script ghi đơn trên primary và kiểm tra sự xuất hiện trên replica.
- **Chữ:** Run `LOAD-20261117-141855`; ghi ACK, thời gian ghi, trạng thái đọc vào CSV.
- **Bố cục:** Dòng thời gian 3 bước: ghi → ACK → đọc replica.
- **Ảnh:** [Tải đọc/ghi](../results/evidence/tv3/07_tai_doc_ghi_primary_replica.png); [CSV gốc](../results/workload-LOAD-20261117-141855.csv).

### Slide 12 — Kết quả tải thường

- **Thông điệp:** Trong lần chạy đã lưu, 444 giao dịch được ACK và 444 lần đọc thấy đơn.
- **Chữ:** `444 ACK`; `444 đọc OK`; không suy rộng thành cam kết cho mọi mức tải.
- **Bố cục:** Hai số lớn, phần dưới là ảnh kết quả.
- **Ảnh:** [Tổng kết 444 giao dịch](../results/evidence/tv3/07b_tong_ket_tai_444_giao_dich.png).

### Slide 13 — Phương pháp đo lag

- **Thông điệp:** Chỉ tính các mẫu trùng với khoảng thời gian chạy tải.
- **Chữ:** CSV thô 270 mẫu; 258 mẫu trong khoảng tải; 0 lag NULL. CSV gốc có lỗi định dạng giờ `THH24`, chỉ sửa trong bộ nhớ khi phân tích run này.
- **Bố cục:** Trục thời gian tải và các dấu lấy mẫu. Chú thích rõ việc sửa timestamp.
- **Nguồn:** [CSV lag](../results/replication-lag-20261117-141920.csv), [giải thích phương pháp](../results/README.md).

### Slide 14 — Số liệu lag khi có tải

- **Thông điệp:** Mẫu trong khoảng tải có mean 1,326 ms, P95 1,797 ms, max 10,411 ms.
- **Chữ:** 258 mẫu; mean/P95/max; WAL gap max 232 byte.
- **Bố cục:** Bốn thẻ số; ảnh kết quả nhỏ phía dưới.
- **Ảnh:** [Thống kê](../results/evidence/tv3/18_thong_ke_do_tre_replication_khi_co_tai.png); [CSV tóm tắt](../results/lag-summary-LOAD-20261117-141855.csv).

### Slide 15 — Biểu đồ lag

- **Thông điệp:** Lag đa phần gần mức trung bình nhưng có một đỉnh 10,411 ms.
- **Chữ:** Nêu mean, P95 và max; không suy ra nguyên nhân đỉnh từ một biểu đồ.
- **Bố cục:** Biểu đồ chiếm gần cả slide, kết luận một dòng bên dưới.
- **Hình:** [SVG biểu đồ](../results/lag-chart-LOAD-20261117-141855.svg) hoặc [ảnh 19](../results/evidence/tv3/19_bieu_do_do_tre_replication_khi_co_tai.png).

### Slide 16 — Kịch bản failover thủ công

- **Thông điệp:** Người vận hành dừng primary, promote replica rồi chuyển đích ghi.
- **Chữ:** Run `FO-20261117-151645-24e67c`; bốn mốc: yêu cầu dừng → dừng xong → promote → đổi write target.
- **Bố cục:** Timeline ngang, phân biệt điều khiển và giao dịch.
- **Ảnh:** [Các mốc failover](../results/evidence/tv1/09b_cac_moc_thoi_gian_failover.png); [CSV sự kiện](../results/events-FO-20261117-151645-24e67c.csv).

### Slide 17 — Trạng thái sau promote

- **Thông điệp:** Replica cũ nhận vai trò primary mới; container primary cũ dừng.
- **Chữ:** Nêu tên container vẫn là `replica-1` dù vai trò PostgreSQL đã đổi. Failover không tự động.
- **Bố cục:** Trước/sau bằng hai sơ đồ nhỏ, ảnh terminal ở góc phải.
- **Ảnh:** [Primary dừng, replica promote](../results/evidence/tv1/09_primary_dung_replica_da_promote.png).

### Slide 18 — Ghi thành công sau failover

- **Thông điệp:** Sau chuyển đích ghi, primary mới nhận ACK.
- **Chữ:** Nêu lệnh ghi và truy vấn đọc minh họa, không dùng một ảnh để kết luận toàn bộ giao dịch.
- **Bố cục:** Ảnh chính bên trái; phía phải ba bước “promote → ghi → đọc”.
- **Ảnh:** [Ghi sau failover](../results/evidence/tv3/10_ghi_thanh_cong_sau_failover_va_thoi_gian_khoi_phuc.png).

### Slide 19 — Đối chiếu giao dịch sau failover

- **Thông điệp:** 510/510 ACK hiện diện; 1 lượt `UNCONFIRMED` không được tính là ACK bị mất.
- **Chữ:** 20 ACK trên primary cũ + 490 ACK trên primary mới; 0 ACK thiếu; 1 UNCONFIRMED không hiện diện.
- **Bố cục:** Bảng đối chiếu gọn và một ô giải thích `UNCONFIRMED`.
- **Ảnh:** [Đối chiếu](../results/evidence/tv3/11_doi_chieu_giao_dich_sau_failover.png); [CSV tóm tắt](../results/comparison-summary-FO-20261117-151645-24e67c.csv).

### Slide 20 — Thời gian chuyển ghi quan sát được

- **Thông điệp:** 2,316 giây từ yêu cầu dừng đến ACK đầu tiên trên primary mới trong lần thử này.
- **Chữ:** Ghi rõ mốc bắt đầu `stop_requested`, mốc kết thúc `first ACK`; phép đo gồm thời gian chờ lượt ghi. Đây không phải RTO toàn bộ dịch vụ.
- **Bố cục:** Hai mốc UTC trên timeline, số `2,316 s` ở giữa.
- **Nguồn:** [CSV thời gian](../results/recovery-summary-FO-20261117-151645-24e67c.csv), [diễn giải](../results/README.md).

### Slide 21 — Tái lập replica sau failover

- **Thông điệp:** Trên cụm thử `lab13-bootstrap-check`, nhóm tạo replica mới từ volume rỗng của primary mới.
- **Chữ:** Primary mới thấy `streaming/async`; replica mới đọc được đơn `REJOIN-20261118-001` trị giá 456,78.
- **Bố cục:** Sơ đồ primary mới → replica mới, kèm ảnh kết quả.
- **Ảnh:** [Replica mới nhận dữ liệu](../results/evidence/tv1/21_replica_moi_sau_failover_nhan_du_lieu.png); [runbook](../infra/REJOIN.md).

## Phần C — Backup và phục hồi

### Slide 22 — Vì sao replication chưa đủ để sửa xóa nhầm

- **Thông điệp:** Lệnh xóa hợp lệ được sao chép sang replica; cần backup và WAL để quay về trước lệnh xóa.
- **Chữ:** “Replica giữ bản hiện tại” và “PITR giữ khả năng chọn mốc thời gian”. Đây là kết quả được minh họa bằng bài thử tích hợp ở phần sau.
- **Bố cục:** Hai trục thời gian: dữ liệu hiện tại trên hai node và điểm phục hồi trước xóa.

### Slide 23 — Cơ chế base backup và WAL archive

- **Thông điệp:** Base backup là điểm bắt đầu; WAL archive cung cấp các thay đổi sau backup.
- **Chữ:** `pg_basebackup` → `pg_verifybackup` → lưu WAL → restore đến mốc chọn.
- **Bố cục:** Sơ đồ bốn hộp, chú thích volume tách biệt trên cùng Docker host.
- **Ảnh:** [Cấu hình WAL](../results/evidence/tv2/12b_cau_hinh_wal_archive.png), [WAL archive](../results/evidence/tv2/13_wal_archive_hoat_dong.png).

### Slide 24 — Kiểm tra base backup

- **Thông điệp:** Bản sao được kiểm tra bằng `pg_verifybackup` trước khi dùng.
- **Chữ:** Hai lần thử có backup được verify; không ghi “bản sao ngoài máy” vì chưa có.
- **Bố cục:** Ảnh kết quả chiếm 2/3, bên phải giải thích ý nghĩa manifest.
- **Ảnh:** [Base backup TV2](../results/evidence/tv2/12_basebackup_va_kiem_tra_thanh_cong.png), hoặc [base backup tích hợp](../results/evidence/integrated/23_base_backup_cum_tich_hop.png). Chọn một run và ghi rõ run đó.

### Slide 25 — PITR trên môi trường backup riêng

- **Thông điệp:** Ba đơn đã xóa được khôi phục bằng điểm thời gian trước lệnh xóa.
- **Chữ:** Run `PITR-20261117-194600`; nguồn và restore tách khỏi `lab13-isolated`; mốc UTC `2026-11-17 19:46:55.579505+00`.
- **Bố cục:** Timeline backup → ghi → xóa → target → restore.
- **Ảnh:** [Trước xóa](../results/evidence/tv2/14a_du_lieu_va_moc_phuc_hoi_truoc_khi_xoa.png), [PITR paused](../results/evidence/tv2/15a_pitr_dung_tai_moc_phuc_hoi.png).

### Slide 26 — Kiểm tra PITR riêng

- **Thông điệp:** Trước xóa và sau phục hồi đều 4 dòng, checksum khớp; sau recovery đọc/ghi được.
- **Chữ:** Checksum `32af3014e87e8c2c10683e8873cd2e9d`; quan sát đến paused 1,935 giây, chưa phải RTO đầy đủ.
- **Bố cục:** Trái là so sánh trước/sau, phải là trạng thái đọc/ghi.
- **Ảnh:** [Checksum](../results/evidence/tv2/16a_doi_chieu_so_dong_va_checksum_sau_pitr.png), [đọc/ghi](../results/evidence/tv2/16b_kiem_tra_doc_ghi_sau_phuc_hoi.png).

## Phần D — Thử nghiệm tích hợp và đánh giá

### Slide 27 — Cụm tích hợp replication + PITR

- **Thông điệp:** Bài thử `INT-20261118-150553` dùng cùng một cụm nguồn cho replica, base backup và WAL archive.
- **Chữ:** `lab13-integrated` gồm primary/replica; restore dùng volume dữ liệu mới, đọc volume backup/WAL nguồn.
- **Bố cục:** Sơ đồ kiến trúc riêng cho run này, khác sơ đồ thử PITR TV2.
- **Ảnh:** [Cụm tích hợp](../results/evidence/integrated/22_cum_tich_hop_replication_va_wal_archive.png); [Compose](../infra/compose-integrated.yaml).

### Slide 28 — Xóa lan sang replica, PITR lấy lại dữ liệu

- **Thông điệp:** Sau xóa, primary và replica đều còn 0 đơn thử nghiệm; bản restore về trước xóa có lại 4 dòng.
- **Chữ:** Mốc target `2026-11-18 08:08:44.585216+00`; restore dừng trước commit xóa lúc `08:09:48.000605+00`.
- **Bố cục:** Timeline ngang và ba ô kết quả: primary 0, replica 0, restore 4.
- **Ảnh:** [Xóa lan sang replica](../results/evidence/integrated/24_xoa_don_da_lan_sang_replica.png), [PITR paused](../results/evidence/integrated/26_pitr_cum_tich_hop_dung_truoc_lenh_xoa.png).

### Slide 29 — Đối chiếu và đọc/ghi sau PITR tích hợp

- **Thông điệp:** 4/4 dòng và checksum khớp trước/sau; sau recovery ghi và đọc lại đơn mới 999,99.
- **Chữ:** Checksum `d86a2624608b97232e95955f5c8246fb`; đơn sau PITR `INT-POST-PITR-20261118-001`. Checksum được chụp **trước** khi thêm đơn mới.
- **Bố cục:** Trái là so sánh checksum, phải là kiểm tra ghi/đọc.
- **Ảnh:** [Đối chiếu](../results/evidence/integrated/27_doi_chieu_checksum_pitr_cum_tich_hop.png), [đọc/ghi](../results/evidence/integrated/28_doc_ghi_sau_pitr_cum_tich_hop.png); [CSV](../results/INT-20261118-150553/README.md).

### Slide 30 — Kết luận, giới hạn và hướng tiếp theo

- **Thông điệp:** Nhóm đã chứng minh các kịch bản trên môi trường lab; kết quả chưa đại diện cho mọi lỗi và mọi mức tải.
- **Chữ:** Đã làm: replication, failover thủ công, backup/PITR, xóa lan sang replica rồi PITR. Giới hạn: một Docker host, chưa có failover tự động, chưa đo RTO đầy đủ hoặc thử nhiều mức tải. Tiếp theo: mục tiêu RPO/RTO định trước, đo lặp, bản sao ngoài host, retention/bảo mật.
- **Bố cục:** Hai cột “Đã kiểm chứng” và “Cần hoàn thiện”; cuối slide một câu kết luận ngắn.
- **Nguồn:** [Tiến độ](PROGRESS.md), [kết quả](../results/README.md).

## Kiểm tra trước khi chia sẻ slide

- Đếm đủ **30 slide nội dung**, không tính các trang phụ.
- Mỗi ảnh dùng đúng run và đúng môi trường; các ảnh `01`–`05` và `08` cũ ở gốc `results/evidence/` đã bỏ.
- Ảnh số **25** của lần thử tích hợp chưa được lưu; không tạo slide hoặc chú thích như thể đã có ảnh này. Số liệu WAL archive được ghi trong [kết quả lần thử](../results/INT-20261118-150553/README.md).
- Kết luận “510/510 ACK còn hiện diện” chỉ áp dụng cho run failover; giao dịch `UNCONFIRMED` tách riêng.
- `2,316 giây` là thời gian quan sát từ yêu cầu dừng đến ACK đầu tiên; `1,935 giây` là từ khởi động restore riêng đến quan sát paused. Không gọi hai số này là RTO toàn bộ dịch vụ.
- Đặt nguồn CSV/ảnh dưới mỗi slide có số liệu. Kiểm tra chữ trong ảnh trên màn hình trình chiếu, không chỉ ở chế độ chỉnh sửa.

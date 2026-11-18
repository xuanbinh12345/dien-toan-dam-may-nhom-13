# Kiểm thử PITR từ bản sao trên ổ D

Thực hiện ngày 19/11/2026 (giờ máy). Bản sao được đặt tại
`D:\lab13-ban-sao-20261119-002132`, ngoài Docker volume nhưng **trên
cùng máy** với Docker host. Bản sao chứa base backup và WAL archive từ
cụm `lab13-integrated`; không đưa dữ liệu backup hoặc WAL vào Git.

## Trình tự và kết quả đã quan sát

1. `docker cp` sao chép `/backups` (khoảng 48,6 MB) và `/wal_archive`
   (khoảng 201 MB) từ nguồn sang hai thư mục trên ổ D. Trước sao chép,
   `pg_stat_archiver` báo `failed_count = 0`, WAL cuối `...000C`.
2. Bản backup `base_integrated_20261118_150553` trên ổ D được gắn chỉ
   đọc vào container và `pg_verifybackup` trả thành công. Ảnh:
   [32 — verify bản sao](evidence/tv2/32_verify_backup_ban_sao_o_D.png).
3. SHA-256 của bốn WAL segment `...0008`, `...0009`, `...000A`, `...000B`
   trên ổ D khớp với nguồn tại thời điểm đối chiếu. Đây là bốn segment
   được kiểm tra hash, không phải xác minh toàn bộ archive.
4. Project `lab13-host-copy-restore` dùng
   [Compose override](../backup/compose-host-copy-restore.yaml), gắn
   backup/WAL từ ổ D chỉ đọc và tạo volume restore mới. `prepare` verify
   backup thành công; PostgreSQL dừng recovery tại
   `2026-11-18 08:08:44.585216+00`, trước commit xóa.
5. Khi paused: `pg_is_in_recovery() = t`, có lại 4 dòng. Số dòng và
   checksum trước xóa/đã khôi phục cùng là 4 và
   `d86a2624608b97232e95955f5c8246fb`.
   [Ảnh 33 — đối chiếu](evidence/tv2/33_doi_chieu_pitr_tu_ban_sao_o_D.png).
6. Sau `pg_wal_replay_resume()`, `pg_is_in_recovery() = f`,
   `transaction_read_only = off`; ghi đơn
   `HOSTCOPY-POST-PITR-20261119-001` trị giá 999,99 và đọc lại được.
   [Ảnh 34 — ghi và đọc lại](evidence/tv2/34_doc_ghi_sau_pitr_tu_ban_sao_o_D.png).

Checksum được so sánh trước khi thêm đơn kiểm tra. Mốc UTC và dữ liệu
trước xóa lấy từ [run tích hợp gốc](INT-20261118-150553/README.md).

## Giới hạn

Lần thử chứng minh PITR và đọc/ghi từ bản sao trên ổ D. Nó không kiểm
chứng khôi phục khi mất máy, không phải bản sao ngoài host và không đo
RTO toàn bộ. Các ảnh và kết quả kiểm tra là bằng chứng của lần chạy;
không có log restore dạng văn bản đã lưu cho run này. Chưa kiểm thử lưu
giữ tự động, mã hóa hoặc phục hồi từ thiết bị thứ hai.

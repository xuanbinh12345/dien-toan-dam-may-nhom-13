# Bàn giao TV2 — Backup và PITR

Đóng gói ngày 18/11/2026 (giờ Việt Nam). Lần thử có run ID `PITR-20261117-194600`; các thời điểm trong kết quả dùng UTC.

## Đọc theo thứ tự

1. [Tình trạng và cấu hình](backup/README.md).
2. [Quy trình backup/restore](backup/RUNBOOK.md).
3. [Số liệu của lần thử](results/PITR-20261117-194600/README.md).
4. [11 ảnh minh chứng](results/evidence/tv2/README.md).
5. [Đề xuất bảo vệ và lưu giữ backup](backup/RETENTION.md) — chưa triển khai.

## Thành phần gói

- Hai file Compose được sao chép nguyên bản từ cấu hình đã dùng.
- Schema `orders` dùng chung; file này đã có trong repo, không tạo đóng góp mới nếu nội dung không đổi.
- CSV/JSON/SQL và các mốc thời gian gốc của lần thử; không sửa số liệu.
- 11 ảnh từ thiết lập backup đến xác minh dữ liệu và đọc/ghi sau phục hồi. Ảnh 16a/16b là minh chứng nghiệm thu phối hợp TV2–TV3, không xác định tác giả chỉ theo vị trí thư mục.
- README/runbook được biên soạn khi bàn giao. Đây là tài liệu tổng hợp; chưa chạy lại toàn bộ trên máy mới sau khi đóng gói.
- `MANIFEST_SHA256.csv` liệt kê checksum các file trong gói (không tự liệt kê chính manifest).

Không có `.env`, `.env.restore`, mật khẩu thực, thư mục `.git`, Docker volume, base backup thật hoặc WAL thật. Gói này là mã nguồn và minh chứng, không phải một bản backup có thể đem restore trực tiếp trên máy khác. Tag image cục bộ cũng không được truyền theo ZIP.

## Nhận vào repo

TV2 dùng tài khoản của mình và nhánh `tv2/backup-pitr` tạo từ main sạch. Chép nội dung `backup/`, `results/PITR-20261117-194600/`, file `results/backup-base_20261117_193933.csv` và `results/evidence/tv2/` vào đúng vị trí tương ứng. Giữ nguyên các phần TV1/TV3 khác. Chỉ chép `tests/schema.sql` nếu cần, đối chiếu trước khi thay bản có sửa riêng.

`BAN_GIAO_TV2.md` và manifest là tài liệu gói, có thể giữ riêng; không cần commit vào gốc repo. Khi TV2 kiểm tra, mô tả rõ đã tiếp nhận, đọc, sửa hoặc chạy lại những gì; không ghi rằng một phép thử được chạy trên máy TV2 nếu chưa thực hiện.

Sau khi rà soát, stage theo phạm vi cụ thể, không dùng `git add .`:

```powershell
git add -- backup/README.md backup/RUNBOOK.md backup/RETENTION.md backup/.gitignore backup/.env.example backup/restore.env.example backup/compose-backup.yaml backup/compose-restore.yaml
git add -- results/backup-base_20261117_193933.csv results/PITR-20261117-194600/ results/evidence/tv2/
git diff --cached --stat
git diff --cached
```

Tạo commit và PR sau khi tự kiểm tra. Việc đóng gói này không commit hoặc push thay TV2.

## Những điểm chưa hoàn tất

- Chưa tích hợp Backup/PITR vào cụm HA `lab13-isolated` và chưa chứng minh xóa lan sang replica trong môi trường chung.
- Chưa có bản sao ngoài Docker host, lịch backup tự động, retention thực thi hoặc mã hóa backup.
- Chưa đo nhiều lần, chưa có mục tiêu RPO/RTO được ghi trước lần thử đã lưu.
- Chưa có log restore dạng text trong dữ liệu nhận được; có ảnh log 15a. Runbook có lệnh xuất log nếu container gốc vẫn còn.
- Kết quả 1,935 giây chỉ là khởi động tới quan sát pause, không phải tổng RTO. Các khoảng chờ thao tác/chụp ảnh không được trình bày như tốc độ restore thuần.

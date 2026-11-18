# Minh chứng TV2 — Backup/PITR

Ảnh chụp do người thực hiện cung cấp, sao chép nguyên bản. Các ảnh đối chiếu và đọc/ghi là minh chứng nghiệm thu phối hợp với TV3.

| Ảnh | Nội dung |
|---|---|
| [12](12_basebackup_va_kiem_tra_thanh_cong.png) | Tạo base backup và pg_verifybackup thành công |
| [12a](12a_moi_truong_backup_dang_chay.png) | Container nguồn healthy, cổng 5545 |
| [12b](12b_cau_hinh_wal_archive.png) | wal_level, archive_mode, archive_timeout và archive_command |
| [13](13_wal_archive_hoat_dong.png) | Archive WAL ban đầu |
| [13b](13b_wal_archive_sau_khi_xoa.png) | WAL yêu cầu ...000A đã tồn tại; archive tới ...000B, failed_count = 0 |
| [14a](14a_du_lieu_va_moc_phuc_hoi_truoc_khi_xoa.png) | Mẫu 4 dòng, checksum và mốc UTC trước xóa |
| [14b](14b_du_lieu_sau_khi_xoa.png) | DELETE 3, nhóm đơn thử nghiệm còn 0 |
| [15a](15a_pitr_dung_tai_moc_phuc_hoi.png) | Log đạt recovery target và pause; số đo 1,935 giây |
| [15b](15b_du_lieu_duoc_phuc_hoi_truoc_khi_xoa.png) | Ba đơn trở lại, tổng 4 dòng khi recovery paused |
| [16a](16a_doi_chieu_so_dong_va_checksum_sau_pitr.png) | Count/checksum trước và sau khớp |
| [16b](16b_kiem_tra_doc_ghi_sau_phuc_hoi.png) | Ghi ACK và đọc OK qua kết nối mới |

Xem [dữ liệu thô và giới hạn](../../PITR-20261117-194600/README.md), [runbook](../../../backup/RUNBOOK.md).

# Quy trình backup và PITR

## 1. Phạm vi và điều kiện

Chạy PowerShell từ thư mục gốc repo, có Docker đang hoạt động. Hai Compose project có tên cố định `lab13-backup` và `lab13-restore`. Quy trình tái lập dưới đây dành cho máy mới hoặc môi trường chưa có hai project đó. Nếu container/volume đã tồn tại, dừng để xác định vai trò và dữ liệu; không xóa volume hoặc chạy lại prepare để làm sạch lỗi.

```powershell
docker ps -a --filter 'label=com.docker.compose.project=lab13-backup'
docker ps -a --filter 'label=com.docker.compose.project=lab13-restore'
docker volume ls --filter 'name=lab13-backup'
docker volume ls --filter 'name=lab13-restore'
```

Trên máy thực nghiệm hiện tại, restore đã hoàn tất và có dữ liệu đọc/ghi mới. Không chạy lại toàn bộ quy trình trên các volume đó. Các lệnh SQL insert/delete trong thư mục kết quả là bằng chứng lịch sử, không tự chạy chúng trên nguồn đang dùng.

Trước một lần đo mới, ghi mục tiêu RPO/RTO, điều kiện tải và phạm vi đo. Không áp mục tiêu đặt sau vào lần thử cũ. Các lệnh có thay đổi dữ liệu dưới đây chỉ dùng container backup/restore riêng, không dùng cụm HA.

## 2. Dựng source và archive WAL

Tạo `backup/.env` từ `backup/.env.example`, thay mật khẩu mẫu bằng mật khẩu lab riêng. Không đưa file này vào Git. Chạy:

```powershell
docker compose --env-file backup/.env -f backup/compose-backup.yaml config --quiet
docker compose --env-file backup/.env -f backup/compose-backup.yaml up -d
docker compose --env-file backup/.env -f backup/compose-backup.yaml ps
docker exec lab13-backup-source-1 postgres --version
docker exec lab13-backup-source-1 psql -U postgres -d ha_lab -c 'SHOW wal_level; SHOW archive_mode; SHOW archive_timeout; SHOW archive_command;'
Get-Content -Raw tests/schema.sql | docker exec -i lab13-backup-source-1 psql -U postgres -d ha_lab -v ON_ERROR_STOP=1
docker exec lab13-backup-source-1 psql -U postgres -d ha_lab -v ON_ERROR_STOP=1 -c "INSERT INTO public.orders(order_id, amount) VALUES ('PITR-SETUP-001',100.00);"
docker exec lab13-backup-source-1 psql -U postgres -d ha_lab -c 'SELECT pg_walfile_name(pg_switch_wal()) AS wal_to_archive;'
```

Chỉ chạy lệnh sau khi lệnh trước thành công. Đợi archive rồi kiểm tra:

```powershell
docker exec lab13-backup-source-1 psql -U postgres -d ha_lab -c 'SELECT archived_count,last_archived_wal,last_archived_time,failed_count,last_failed_wal FROM pg_stat_archiver;'
docker exec lab13-backup-source-1 ls -lh /wal_archive
```

File WAL yêu cầu phải có trong archive; xử lý lỗi trước khi backup. Chụp 12a, 12b và 13. pg_stat_archiver đếm cả các file như lịch sử backup; archived_count không luôn bằng số WAL segment.

## 3. Base backup và verify

```powershell
$backupName = 'base_' + [DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss')
$backupPath = "/backups/$backupName"
$backupStartedUtc = [DateTime]::UtcNow.ToString('o')
docker exec -u postgres lab13-backup-source-1 pg_basebackup -U postgres -D $backupPath -Fp -Xs -P --checkpoint=fast --manifest-checksums=SHA256
if ($LASTEXITCODE -ne 0) { throw 'Backup failed: stop here' }
$backupFinishedUtc = [DateTime]::UtcNow.ToString('o')
docker exec -u postgres lab13-backup-source-1 pg_verifybackup $backupPath
if ($LASTEXITCODE -ne 0) { throw 'Verification failed: stop here' }
New-Item -ItemType Directory -Force results | Out-Null
[PSCustomObject]@{
    backup_name=$backupName; backup_path=$backupPath
    container='lab13-backup-source-1'
    started_utc=$backupStartedUtc; finished_utc=$backupFinishedUtc
    verified_utc=[DateTime]::UtcNow.ToString('o'); verification='passed'
} | Export-Csv ".\results\backup-$backupName.csv" -NoTypeInformation -Encoding UTF8
```

Chụp ảnh 12 có `backup successfully verified` và backup path. Không sửa nội dung base backup đã verify. Verify không thay thế test restore.

## 4. Ghi dữ liệu sau backup, snapshot và target

Dừng mọi chương trình khác ghi vào source trong giai đoạn snapshot/target. Tạo run ID mới và thư mục mới; không ghi đè dữ liệu thực nghiệm cũ.

```powershell
$run = 'PITR-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')
$out = ".\results\$run"
New-Item -ItemType Directory -Path $out -ErrorAction Stop | Out-Null
$insert = "INSERT INTO public.orders(order_id,amount) VALUES ('$run-001',111.00),('$run-002',222.00),('$run-003',333.00);"
$insert | Set-Content "$out\insert.sql" -Encoding UTF8
docker exec lab13-backup-source-1 psql -X -U postgres -d ha_lab -v ON_ERROR_STOP=1 -c $insert
if ($LASTEXITCODE -ne 0) { throw 'Insert failed' }
$snapshotSql = "SELECT order_id,amount,created_at AT TIME ZONE 'UTC' AS created_at_utc FROM public.orders ORDER BY order_id;"
$snapshot = docker exec lab13-backup-source-1 psql -X --csv -U postgres -d ha_lab -v ON_ERROR_STOP=1 -c $snapshotSql
if ($LASTEXITCODE -ne 0) { throw 'Snapshot failed' }
$snapshot | Set-Content "$out\before-orders.csv" -Encoding UTF8
Copy-Item -LiteralPath .\results\PITR-20261117-194600\checksum.sql -Destination "$out\checksum.sql"
$checksumSql = Get-Content "$out\checksum.sql" -Raw
$before = docker exec lab13-backup-source-1 psql -X --csv -U postgres -d ha_lab -v ON_ERROR_STOP=1 -c $checksumSql
if ($LASTEXITCODE -ne 0) { throw 'Checksum failed' }
$before | Set-Content "$out\before-checksum.csv" -Encoding UTF8
$targetRaw = docker exec lab13-backup-source-1 psql -X -A -t -U postgres -d ha_lab -v ON_ERROR_STOP=1 -c "SELECT to_char(clock_timestamp() AT TIME ZONE 'UTC','YYYY-MM-DD HH24:MI:SS.US') || '+00';"
if ($LASTEXITCODE -ne 0) { throw 'Target query failed' }
$targetUtc = ($targetRaw | Out-String).Trim()
[PSCustomObject]@{
    run_id=$run; source_container='lab13-backup-source-1'
    backup_path=$backupPath; recovery_target_utc=$targetUtc
    test_order_ids=@("$run-001","$run-002","$run-003")
} | ConvertTo-Json -Depth 3 | Set-Content "$out\pitr-info.json" -Encoding UTF8
```

Đọc lại snapshot, checksum và JSON, chụp 14a trước khi xóa. File checksum.sql dùng được cho mọi lần vì không gắn run ID; các file insert/delete lịch sử thì không.

## 5. Xóa riêng ba đơn và archive WAL

```powershell
Start-Sleep -Seconds 2
$delete = "DELETE FROM public.orders WHERE order_id IN ('$run-001','$run-002','$run-003') RETURNING order_id,amount;"
$delete | Set-Content "$out\delete.sql" -Encoding UTF8
$deleted = docker exec lab13-backup-source-1 psql -X --csv -U postgres -d ha_lab -v ON_ERROR_STOP=1 -c $delete
if ($LASTEXITCODE -ne 0) { throw 'Delete failed' }
$deleted | Set-Content "$out\delete-result.txt" -Encoding UTF8
$deleted
docker exec lab13-backup-source-1 psql -U postgres -d ha_lab -c "SELECT count(*) AS remaining_test_orders FROM public.orders WHERE order_id IN ('$run-001','$run-002','$run-003');"
docker exec lab13-backup-source-1 psql -U postgres -d ha_lab -c 'SELECT pg_walfile_name(pg_switch_wal()) AS wal_to_archive;'
```

Chụp 14b: DELETE 3 và count nhóm còn 0. Kiểm tra file WAL yêu cầu đã có trong `/wal_archive` và không có lỗi archive cần xử lý (lệnh ở mục 2), chụp 13b. Giữ nguồn ở trạng thái sau xóa, không chèn lại ba đơn bằng SQL.

## 6. Chuẩn bị restore trên volume mới

```powershell
$sourceImage = docker inspect --format '{{.Image}}' lab13-backup-source-1
if ($LASTEXITCODE -ne 0) { throw 'Cannot read source image' }
$imageTag = 'lab13-pitr:' + $run.ToLowerInvariant()
docker image tag $sourceImage.Trim() $imageTag
if ($LASTEXITCODE -ne 0) { throw 'Image tag failed' }
@("PITR_IMAGE=$imageTag", "BACKUP_PATH=$backupPath", "RECOVERY_TARGET_TIME='$targetUtc'") | Set-Content backup/.env.restore -Encoding ASCII
docker compose --env-file backup/.env.restore -f backup/compose-restore.yaml config --quiet
if ($LASTEXITCODE -ne 0) { throw 'Invalid restore configuration' }
[DateTime]::UtcNow.ToString('o') | Set-Content "$out\restore-prepare-started-utc.txt" -Encoding ASCII
docker compose --env-file backup/.env.restore -f backup/compose-restore.yaml run --rm prepare
if ($LASTEXITCODE -ne 0) { throw 'Prepare failed; inspect without deleting volume' }
[DateTime]::UtcNow.ToString('o') | Set-Content "$out\restore-prepare-finished-utc.txt" -Encoding ASCII
```

Phải có `PREPARE_OK`. Prepare chỉ nhận volume rỗng; nguồn backup được mount read-only. Không chạy lại prepare trên volume đã chuẩn bị.

## 7. Khởi động, quan sát pause và lưu log

Ghi mốc ngay trước khi gọi `up -d restore`. Có thể dùng Stopwatch và vòng kiểm tra mỗi giây như lần thử đã làm; giữ tách biệt thời gian copy, khởi động/replay và chờ nghiệm thu thủ công.

```powershell
[DateTime]::UtcNow.ToString('o') | Set-Content "$out\restore-started-utc.txt" -Encoding ASCII
docker compose --env-file backup/.env.restore -f backup/compose-restore.yaml up -d restore
docker compose --env-file backup/.env.restore -f backup/compose-restore.yaml logs --tail 60 restore
docker exec lab13-restore-restore-1 psql -U postgres -d ha_lab -c 'SHOW recovery_target_time; SELECT pg_is_in_recovery(),pg_get_wal_replay_pause_state();'
```

Nếu chưa sẵn sàng, kiểm tra lại sau một khoảng ngắn; dừng xử lý nếu container thoát hoặc log báo chưa đạt target. Chỉ tiếp tục khi đúng target, `pg_is_in_recovery=t` và pause state `paused`. Một lần kết nối báo database đang khởi động chưa chứng minh restore lỗi. Không kết luận mọi thông báo thiếu WAL đều vô hại: cần xem có đạt target/consistent state hay không.

Lưu log text (bước này chưa có file tương ứng trong gói kết quả gốc):

```powershell
docker compose --env-file backup/.env.restore -f backup/compose-restore.yaml logs --no-color restore 2>&1 | Set-Content "$out\restore.log" -Encoding UTF8
docker exec lab13-restore-restore-1 psql -U postgres -d ha_lab -c 'SELECT order_id,amount FROM public.orders ORDER BY order_id;'
```

Chụp 15a log mục tiêu/pause và 15b dữ liệu 4 dòng. Không resume trước khi đối chiếu.

## 8. Đối chiếu rồi kết thúc recovery

```powershell
$after = docker exec lab13-restore-restore-1 psql -X --csv -U postgres -d ha_lab -v ON_ERROR_STOP=1 -c $checksumSql
if ($LASTEXITCODE -ne 0) { throw 'Restored checksum query failed' }
$after | Set-Content "$out\after-checksum.csv" -Encoding UTF8
$b = Import-Csv "$out\before-checksum.csv"
$a = Import-Csv "$out\after-checksum.csv"
$comparison = [PSCustomObject]@{
    run_id=$run
    before_rows=$b.row_count; restored_rows=$a.row_count
    before_checksum=$b.checksum_md5; after_checksum=$a.checksum_md5
    row_count_match=($b.row_count -eq $a.row_count)
    checksum_match=($b.checksum_md5 -ceq $a.checksum_md5)
}
$comparison | Format-List
$comparison | Export-Csv "$out\checksum-comparison.csv" -NoTypeInformation -Encoding UTF8
```

Nếu thiếu số liệu hoặc một kiểm tra False, giữ pause và tìm nguyên nhân. Khi cả hai True, chụp 16a, rồi mới chạy:

```powershell
docker exec lab13-restore-restore-1 psql -U postgres -d ha_lab -v ON_ERROR_STOP=1 -c 'SELECT pg_wal_replay_resume();'
docker exec lab13-restore-restore-1 psql -U postgres -d ha_lab -c 'SELECT pg_is_in_recovery(); SHOW transaction_read_only;'
```

Đợi kết quả `f` và `off`. Vì pause là hành động khi đã đạt target, resume kết thúc recovery tại target, không replay thêm giao dịch xóa phía sau.

## 9. Kiểm thử ghi và đọc lại

```powershell
$rwId = 'POST-PITR-' + [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmssfff')
$write = "INSERT INTO public.orders(order_id,amount) VALUES ('$rwId',999.99) RETURNING order_id,amount;"
$write | Set-Content "$out\post-restore-write.sql" -Encoding UTF8
docker exec lab13-restore-restore-1 psql -X -U postgres -d ha_lab -v ON_ERROR_STOP=1 -c $write
if ($LASTEXITCODE -ne 0) { throw 'Write failed' }
$ackUtc = [DateTime]::UtcNow.ToString('o')
$read = docker exec lab13-restore-restore-1 psql -X --csv -U postgres -d ha_lab -v ON_ERROR_STOP=1 -c "SELECT order_id,amount FROM public.orders WHERE order_id='$rwId';"
if ($LASTEXITCODE -ne 0) { throw 'Read failed' }
$read | Set-Content "$out\post-restore-read.csv" -Encoding UTF8
$readRows = @(Import-Csv "$out\post-restore-read.csv")
if ($readRows.Count -ne 1 -or $readRows[0].order_id -ne $rwId -or $readRows[0].amount -ne '999.99') { throw 'Read-back mismatch' }
$rw = [PSCustomObject]@{
    run_id=$run; container='lab13-restore-restore-1'; order_id=$rwId
    amount=$readRows[0].amount; write_status='ACK'; write_ack_utc=$ackUtc
    read_status='OK'; read_checked_utc=[DateTime]::UtcNow.ToString('o'); rows_read=1
}
$rw | Export-Csv "$out\post-restore-rw.csv" -NoTypeInformation -Encoding UTF8
$rw | Format-List
```

Hai lệnh docker exec/psql dùng hai kết nối riêng. Chụp 16b. Bảng giờ có thêm dòng kiểm thử; không ghi đè snapshot/checksum 4 dòng ở target.

## 10. Sau phép thử và tài liệu

Giữ backup/WAL và toàn bộ kết quả. Chỉ dừng container khi kết thúc buổi thực hành; không dùng `down -v`. Sau resume, không tạo lại recovery.signal hoặc tái chạy prepare lên database đã mở ghi. Cấu hình restore vẫn lưu tham số target phục vụ lần thử; việc vận hành lâu dài, archive trên database mới, tái lập dự phòng và đổi kết nối ứng dụng chưa thuộc kết quả đã kiểm chứng.

Tham khảo: [Continuous archiving/PITR](https://www.postgresql.org/docs/16/continuous-archiving.html), [pg_basebackup](https://www.postgresql.org/docs/16/app-pgbasebackup.html), [pg_verifybackup](https://www.postgresql.org/docs/16/app-pgverifybackup.html), [Recovery target](https://www.postgresql.org/docs/16/runtime-config-wal.html#RUNTIME-CONFIG-WAL-RECOVERY-TARGET). Tài liệu lớp và NIST SP 800-34r1 là cơ sở xây dựng kế hoạch dự phòng; không đồng nhất một demo với bảo đảm sẵn sàng trong production.

# Quy trình failover của lab13-isolated

## Phạm vi và trạng thái đã thử

Ngày 17/11/2026 đã chạy thành công một lần chủ động dừng primary bằng `docker stop`, promote replica và chuyển file đích ghi. Đây là chuyển đổi do người vận hành kích hoạt bằng script; chưa có bộ điều phối tự phát hiện lỗi hoặc endpoint ứng dụng tự chuyển.

**Môi trường đã chạy thử hiện ở trạng thái sau failover. Không chạy lại các bước dừng/promote trên môi trường đó.** Chỉ tái lập trên môi trường mới có đúng vai trò ban đầu. Không xóa volume cũ để làm lại.

## Điều kiện trước lần thử mới

1. Primary `lab13-isolated-primary-1` trả `pg_is_in_recovery() = f`; replica `lab13-isolated-replica-1` trả `t`.
2. Replication streaming/async; bảng `public.orders` đã tồn tại và đọc cùng mã đơn trên hai nút thành công.
3. Không chạy tải failover khác cùng lúc. Thống nhất mục tiêu/điều kiện đo trước lần thử mới.
4. Mở hai terminal tại thư mục gốc repo. Chuẩn bị lưu CSV, mốc UTC và ảnh; không dừng để chụp giữa thao tác chuyển đổi.

## Terminal A — chạy tải

Chỉ đặt đích này khi cụm còn ở vai trò ban đầu:

```powershell
New-Item -ItemType Directory -Force .\results | Out-Null
Set-Content .\results\write-target.txt -Value 'lab13-isolated-primary-1' -Encoding ASCII
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\failover-workload.ps1 -DurationSeconds 600
```

Đợi 15–20 giây và kiểm tra ACK trên primary cũ. Ghi lại run ID `FO-...` được in ra. File tải xuất UTC và kết quả cho từng mã đơn; UNCONFIRMED chưa xác nhận commit, không mặc định là ACK mất dữ liệu.

## Terminal B — chuyển đổi một lần

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\invoke-failover.ps1
```

Script kiểm tra vai trò và ACK gần nhất; gắn sự kiện với CSV tải mới nhất; lưu `events-<run-id>.csv`; dừng primary; kiểm tra container cũ thực sự dừng; gọi `pg_promote(true,60)`; đổi `write-target.txt`. Nếu lỗi, đọc trạng thái thực tế và log; không chạy lại cả script hoặc bật primary cũ để thử chữa lỗi.

A phải tiếp tục có ACK với target `lab13-isolated-replica-1`. B hoàn tất trước A là bình thường. Giữ A chạy đến DONE.

## Kiểm tra và ảnh 09–10

Sau khi có ACK trên nút mới:

```powershell
docker ps -a --filter 'name=lab13-isolated' --format 'table {{.Names}}\t{{.Status}}'
docker exec lab13-isolated-replica-1 psql -U postgres -d ha_lab -c 'SELECT pg_is_in_recovery() AS is_standby;'
```

Ảnh 09 phải có primary cũ Exited, nút mới Up, `is_standby = f`. Ảnh tải bổ sung ghi lại ACK trước/sau chuyển đổi và lỗi nếu thực tế có xuất hiện.

Để tính thời gian từ CSV, điền đúng run ID của phép thử (ví dụ dưới đây đọc bộ kết quả đã lưu):

```powershell
$runId = 'FO-20261117-151645-24e67c'
$events = @(Import-Csv ".\results\events-$runId.csv")
$tx = @(Import-Csv ".\results\failover-$runId.csv")
$start = $events | Where-Object event -eq 'stop_requested' | Select-Object -First 1
$first = $tx | Where-Object { $_.status -eq 'ACK' -and $_.target -eq 'lab13-isolated-replica-1' } | Sort-Object { [int]$_.sequence } | Select-Object -First 1
if ($null -eq $start -or $null -eq $first) { throw 'Missing event or new-primary ACK' }
$seconds = ([DateTimeOffset]::Parse($first.ack_utc) - [DateTimeOffset]::Parse($start.utc)).TotalSeconds
[PSCustomObject]@{
    run_id = $runId
    stop_requested_utc = $start.utc
    first_new_primary_ack = $first.ack_utc
    first_order_id = $first.order_id
    observed_recovery_sec = [Math]::Round($seconds, 3)
} | Format-List
```

Ảnh 10 ghi cả hai mốc và số giây. Kết quả gồm thời gian dừng, promote, chuyển đích và chờ lượt ghi. Không gọi riêng phần này là thời gian promote.

## Đối chiếu sau khi A đã DONE — ảnh 11

Trên máy giữ database của đúng lần thử, điền run ID tương ứng:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-failover.ps1 -RunId FO-20261117-151645-24e67c
```

Ảnh 11 lấy bảng tổng kết ACK/UNCONFIRMED. Giữ CSV từng giao dịch, CSV sự kiện, CSV đối chiếu và snapshot ID để kiểm tra lại. Lệnh đối chiếu cùng run ID sẽ ghi đè kết quả đối chiếu trước đó; chỉ chạy khi chủ định kiểm tra snapshot hiện tại của chính run đó.

## Sau phép thử

- Giữ primary cũ dừng để tránh hai nút cùng nhận ghi. Không chạy `compose up -d` toàn bộ.
- Primary mới giữ tên container replica và cổng host 5544. Chưa có nút dự phòng thay thế.
- Quy trình tái gia nhập primary cũ còn phải xây dựng và kiểm chứng; chưa tuyên bố failback hoàn tất.
- Khi làm Backup/PITR, thống nhất môi trường và cấu hình với TV2; không restore đè lên volume hiện tại.
- Kết quả lần đầu và giới hạn: [tiến độ](../docs/PROGRESS.md), [số liệu](../results/README.md).

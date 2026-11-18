# Kiểm thử và đo lường – TV3

## Đã bàn giao

| File | Chức năng | Điều kiện chạy |
|---|---|---|
| [schema.sql](schema.sql) | Bảng `orders`, khóa chính mã đơn, amount > 0 | Nạp vào primary |
| [workload.ps1](workload.ps1) | Ghi primary cũ, đọc replica, xuất CSV | Cụm trước failover |
| [measure-lag.ps1](measure-lag.ps1) | Lấy replay gap (byte) và replay lag (ms) từ primary cũ | Cụm trước failover |
| [failover-workload.ps1](failover-workload.ps1) | Ghi liên tục theo `results/write-target.txt`; ACK/UNCONFIRMED; UTC và mã đơn riêng | Tạo file đích ghi phù hợp trước khi chạy |
| [invoke-failover.ps1](invoke-failover.ps1) | Dừng primary, promote replica, đổi đích ghi; xuất mốc sự kiện | Chỉ chạy một lần trên cụm có vai trò ban đầu, tải đang hoạt động |
| [verify-failover.ps1](verify-failover.ps1) | Đối chiếu ID ACK và UNCONFIRMED với primary mới | Tải đã DONE; database của đúng lần thử còn tồn tại |
| [summarize-repeat-lag.ps1](summarize-repeat-lag.ps1) | Tính lại sáu lượt đo lag từ manifest và CSV gốc | Chỉ đọc CSV, ghi summary.csv |
| [measure-repeat-recovery.ps1](measure-repeat-recovery.ps1) | Preflight chỉ đọc; với `-ExecuteFailover` dừng primary của `lab13-repeat`, promote replica, đo ghi/đọc và đối chiếu 1132 ID | Chỉ dùng một lần trên cụm thử còn đúng vai trò ban đầu |

## Chạy tải và đo lag trước failover

Từ thư mục gốc repo, dùng hai terminal PowerShell. Cần Docker đang chạy và bảng `orders` đã tạo. Các lệnh ghi đơn giả lập vào database.

Terminal A:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\workload.ps1 -DurationSeconds 600
```

Terminal B, mở khi A đã có kết quả:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\measure-lag.ps1 -DurationSeconds 600
```

CSV nằm trong `results/`, có timestamp/run ID trong tên. Giữ cả khoảng có tải và khoảng sau tải; phân tích chúng riêng. `replay_lag_ms` trống là NULL, không thay bằng 0. `write_ms` gồm chi phí gọi Docker/psql, không phải thời gian xử lý SQL thuần.

Hai script mặc định dùng `lab13-isolated-primary-1` và
`lab13-isolated-replica-1` để tương thích lần thử ban đầu. Với cụm thử
mới, truyền `-PrimaryContainer` và `-ReplicaContainer` cho `workload.ps1`,
và `-PrimaryContainer` cho `measure-lag.ps1`. Chỉ chạy khi primary thực sự
không ở recovery, replica đang streaming; không dựa vào tên container để
suy ra vai trò sau failover.

`workload.ps1` nhận `-IntervalMilliseconds` (mặc định 1000); giảm khoảng
nghỉ để tăng nhịp tải mục tiêu. `measure-lag.ps1` nhận
`-SampleIntervalMilliseconds` (mặc định 2000). Nhịp ghi thực tế còn phụ
thuộc thời gian gọi Docker/psql và phải tính từ CSV, không đồng nhất với
giá trị khoảng nghỉ. Dùng project/volume mới cho các lần đo lặp, không
khởi động lại primary cũ của lần failover đã lưu.

## Đối chiếu đúng run

Ví dụ chỉ áp dụng trên máy giữ database đã chạy thử:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\verify-failover.ps1 -RunId FO-20261117-151645-24e67c
```

Script xuất `comparison-details-*`, `comparison-summary-*` và `db-orders-*`. Máy chỉ clone repo không có dữ liệu Docker của lần thử này; hãy đọc kết quả đã commit thay vì chạy đối chiếu trên database mới. Chạy lại trên dữ liệu đã thay đổi sẽ ghi đè file đối chiếu cùng run ID.

## Kết quả và phần còn lại

- [x] Tải cơ bản: 444 ACK, 444 lần đọc thấy đơn trên replica.
- [x] CSV lag và log UTC của từng giao dịch.
- [x] Failover: 2,316 giây đến ACK đầu tiên trên primary mới.
- [x] 510/510 ACK còn trong dữ liệu; 1 UNCONFIRMED không hiện diện.
- [x] Tổng hợp lag trong khoảng có tải, biểu đồ và điều kiện đo.
- [x] Đo lag nhiều lần, ba mức khoảng nghỉ, trên cụm riêng; xem [bảng sáu lượt](../results/repeat-lag-20261118/README.md).
- [x] Ghi mục tiêu thử nghiệm trước lần failover có kiểm soát trên
  `lab13-repeat`; xem [kế hoạch](../docs/RECOVERY_MEASUREMENT_PLAN.md).
- [x] Kiểm tra ACK khi tải chạy qua failover trên `lab13-rpo`; xem
  [kết quả và giới hạn](../results/RPO-FO-20261118-165349-5aac44.md).
- [ ] Xác định mục tiêu cho các lần thử bổ sung trước khi thực hiện.
- [x] Kiểm tra count/checksum và đọc/ghi sau PITR.
- [ ] Đo đầy đủ thời gian phục hồi dịch vụ qua nhiều lần thử.

Lần thử [REC-20261118-161901-297576](../results/recovery-REC-20261118-161901-297576/README.md)
đã đo 1,078 giây từ yêu cầu dừng đến ghi **và đọc lại** thành công trên
primary mới. Chưa gồm phát hiện lỗi hoặc đổi endpoint ứng dụng.

Xem [danh mục kết quả](../results/README.md). Các script hiện có là tải chức năng nhẹ dùng Docker CLI, chưa phải client kết nối qua endpoint HA hoặc bài benchmark hiệu năng tối đa.

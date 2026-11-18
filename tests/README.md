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

**Không chạy hai script trên để đo như trước sau khi đã promote:** chúng cố định đích là container mang tên primary cũ. Theo [runbook failover](../infra/FAILOVER.md) để thử chuyển đổi; không tự sửa vai trò chỉ dựa vào tên container.

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
- [ ] Tổng hợp lag trong khoảng có tải, biểu đồ và điều kiện đo.
- [ ] Đo nhiều lần; thống nhất mục tiêu RPO/RTO trước phép thử tiếp theo.
- [ ] Kiểm tra count/checksum và đọc/ghi sau PITR; đo thời gian restore.

Xem [danh mục kết quả](../results/README.md). Các script hiện có là tải chức năng nhẹ dùng Docker CLI, chưa phải client kết nối qua endpoint HA hoặc bài benchmark hiệu năng tối đa.

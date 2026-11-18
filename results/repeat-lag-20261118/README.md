# Đo lặp replication lag — 18/11/2026

Thực hiện trên cụm riêng `lab13-repeat` (primary cổng 5573, replica cổng
5574), dùng volume mới. Trước khi chạy, nhóm định ba mức khoảng nghỉ giữa
các vòng ghi: **1500 ms, 750 ms, 0 ms**; mỗi mức lặp hai lần, mỗi lần tải
120 giây. Script đo lag chạy 150 giây và lấy mẫu khoảng 2 giây/lần.

| Nghỉ (ms) | Lần | Run ID | ACK/ghi | Đọc thấy đơn | Ghi thực tế/s | Mẫu lag trong tải | NULL | Mean (ms) | P95 (ms) | Max (ms) | Gap max (byte) |
|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1500 | 1 | `LOAD-20261118-151102` | 68/68 | 68/68 | 0,567 | 55 | 0 | 1,412 | 1,793 | 3,252 | 0 |
| 1500 | 2 | `LOAD-20261118-151704` | 68/68 | 68/68 | 0,567 | 56 | 0 | 1,460 | 1,864 | 3,787 | 0 |
| 750 | 1 | `LOAD-20261118-152051` | 116/116 | 116/116 | 0,971 | 56 | 0 | 1,433 | 1,834 | 3,299 | 0 |
| 750 | 2 | `LOAD-20261118-155105` | 114/114 | 114/114 | 0,952 | 55 | 0 | 1,302 | 1,568 | 2,056 | 0 |
| 0 | 1 | `LOAD-20261118-155523` | 384/384 | 384/384 | 3,196 | 55 | 0 | 1,345 | 1,686 | 1,844 | 0 |
| 0 | 2 | `LOAD-20261118-160030` | 382/382 | 382/382 | 3,178 | 56 | 0 | 1,319 | 1,862 | 2,524 | 232 |

Tổng cộng **1132/1132 ACK** và **1132/1132 lần đọc ngay thấy một đơn**
trong sáu lượt. Tất cả mẫu trong khoảng tải ghi nhận `streaming/async`.
Nhịp ghi thực tế tăng từ khoảng 0,57 lên 3,18–3,20 lượt/giây; các giá trị
mean/P95 lag của sáu lượt vẫn nằm trong khoảng 1,302–1,460 ms và
1,568–1,864 ms. Đây chỉ là quan sát trong sáu lượt của môi trường này,
không chứng minh lag không tăng ở tải cao hơn.

## Dữ liệu và cách tính lại

- [Manifest ghép từng cặp CSV](manifest.csv).
- [Bảng số liệu máy đọc được](summary.csv).
- [Script tính lại](../../tests/summarize-repeat-lag.ps1): chạy từ gốc repo bằng
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\summarize-repeat-lag.ps1`.
- CSV gốc của từng run nằm ở `results/`; cột `workload_csv` và `lag_csv`
  trong manifest trỏ đến đúng cặp file. Không sửa CSV gốc.

Khoảng tải được tính từ `started_utc` của giao dịch đầu đến `read_utc`
của giao dịch cuối. Chỉ lấy mẫu lag có `sampled_utc` nằm trong khoảng này.
Mean là trung bình số học; P95 là phần tử tại vị trí `ceil(0,95 × n)` của
dãy lag tăng dần. NULL được đếm riêng, không thay bằng 0. Tốc độ ghi thực
tế là số lượt ghi chia cho độ dài khoảng tải; `IntervalMilliseconds`
chỉ là thời gian nghỉ mục tiêu giữa các vòng, không phải throughput.

CSV lag lượt đầu có lỗi định dạng giờ `THH24`. Khi tính lượt này, script
chỉ thay `THH24:` thành `T15:` trong bộ nhớ, dựa trên giờ của run và file
lag; năm lượt sau có timestamp UTC kèm `+00` và được đọc trực tiếp.

## Giới hạn

Tải được tạo tuần tự bằng `docker exec`/`psql` trên cùng Docker host,
không phải benchmark nhiều client đồng thời. Lấy mẫu khoảng 2 giây có
thể bỏ qua đỉnh lag ngắn giữa hai mẫu. `replay_gap_bytes = 0` tại mẫu đo
không chứng minh replica luôn tức thời. Bài đo này không đo RPO/RTO,
không thử lỗi host, và chưa xác lập SLA cho môi trường sản xuất.

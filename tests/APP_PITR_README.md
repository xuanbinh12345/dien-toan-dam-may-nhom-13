# Kiểm thử ứng dụng HTTP sau PITR

Ứng dụng lab `lab_orders_api.py` mở HTTP trên `127.0.0.1:8099`, chỉ
trỏ đến container `lab13-host-copy-restore-restore-1`. API dùng Python
thư viện chuẩn và gọi `docker exec`/`psql` để truy vấn PostgreSQL; đây
là ứng dụng minh họa, chưa phải ứng dụng production hoặc kiểm thử qua
driver/kết nối endpoint HA. Không dùng nó trên dữ liệu production.

## Điều kiện

- Python 3, Docker CLI và container restore từ bản sao ổ D đang chạy.
- PostgreSQL trên container restore đã kết thúc recovery, có bảng
  `public.orders`, `pg_is_in_recovery() = f`, cho phép ghi.
- Cổng host 8099 trống. API bind localhost, không có xác thực và chỉ
  chấp nhận mã đơn bắt đầu `APP-PITR-` cùng amount hợp lệ.
- Kiểm thử ghi thêm một đơn vào bản restore; checksum 4 dòng của run PITR
  được so sánh trước các lượt ghi kiểm thử.

## Chạy và kiểm tra

Terminal A, tại thư mục gốc repo:

```powershell
python .\tests\lab_orders_api.py
```

Giữ A chạy. Terminal B:

```powershell
python .\tests\test_lab_orders_api.py
```

Script B gọi `/health`, POST `/orders`, GET `/orders/{order_id}`; kiểm tra
container đích và recovery state, HTTP status, ID, amount. Mỗi lượt dùng
ID riêng và lưu JSON vào `results/APP-PITR-<run-id>.json`, gồm PASS/FAIL.
Đọc đủ JSON và `RESULT FILE`; trường `result = PASS` chỉ chứng minh ứng
dụng lab ghi rồi đọc được một đơn trong lần chạy đó. Nếu thất bại giữ JSON
và thông báo để chẩn đoán; không sửa kết quả thành PASS.

Sau khi kiểm tra, nhấn Ctrl+C tại terminal A để dừng HTTP server. Các
container/volume tiếp tục giữ nguyên. Không commit mật khẩu, backup hay WAL.

## Kết quả đã thực hiện

Run `APP-PITR-20261118-184031-d5a9f5`, lúc
`2026-11-18T18:40:31.163696+00:00` (ngày 19/11 theo giờ Bangkok):
kiểm tra recovery state, HTTP ghi và đọc lại đơn `123.45` đều thành công;
kết quả `PASS` được lưu trong
[JSON của run](../results/APP-PITR-20261118-184031-d5a9f5.json).
[Ảnh 35 — kết quả kiểm thử](../results/evidence/tv3/35_kiem_thu_ung_dung_http_sau_pitr.png).
Đây là một lần kiểm thử ứng dụng lab qua HTTP; truy cập database vẫn qua
Docker CLI và psql, không kiểm thử endpoint HA hoặc nhiều client đồng thời.

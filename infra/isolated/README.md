# Cụm PostgreSQL thử nghiệm riêng

**Trạng thái cuối ngày 17/11/2026:** replica đã được promote và primary cũ đang dừng. Lệnh khởi động bên dưới chỉ dành cho môi trường mới, chưa trải qua promote. Xem [tiến độ](../../docs/PROGRESS.md) và [quy trình failover](../FAILOVER.md) trước khi thao tác trên máy đã chạy thử.

Cụm này dùng project Compose `lab13-isolated`, các volume riêng và cổng localhost 5543 (primary), 5544 (replica). Nó không tự động sử dụng các volume `infra_*` của lần thử trước. Cấu hình hiện thực hiện streaming replication bất đồng bộ; backup và PITR chưa được triển khai trong cụm này.

## Khởi động

Từ thư mục gốc repo, tạo `infra/.env` với hai biến sau nếu chưa có. Chọn giá trị riêng cho lab; không commit file này.

```dotenv
POSTGRES_PASSWORD=mat_khau_quan_tri_lab
REPLICATION_PASSWORD=mat_khau_replication_lab
```

```powershell
docker compose --env-file infra/.env -f infra/compose-isolated.yaml config --quiet
docker compose --env-file infra/.env -f infra/compose-isolated.yaml up -d
docker compose --env-file infra/.env -f infra/compose-isolated.yaml ps
```

Biến mật khẩu dùng khi tạo cụm mới. Thay giá trị trong `.env` sau khi đã khởi tạo không tự đổi mật khẩu trong database. Replica lưu thông tin kết nối trong volume dữ liệu; đây là cấu hình lab và cần bảo vệ volume.

## Kiểm tra replication

```powershell
docker exec lab13-isolated-primary-1 psql -U postgres -d ha_lab -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"
docker exec lab13-isolated-replica-1 psql -U postgres -d ha_lab -c "SELECT pg_is_in_recovery();"
Get-Content -Raw tests/schema.sql | docker exec -i lab13-isolated-primary-1 psql -v ON_ERROR_STOP=1 -U postgres -d ha_lab
docker exec lab13-isolated-primary-1 psql -U postgres -d ha_lab -c "INSERT INTO orders(order_id, amount) VALUES ('DEMO-001', 100.00);"
docker exec lab13-isolated-replica-1 psql -U postgres -d ha_lab -c "SELECT * FROM orders WHERE order_id='DEMO-001';"
```

Kết quả mong đợi là `streaming`, `async`, `pg_is_in_recovery = t` và replica đọc được `DEMO-001`. Đổi mã đơn cho mỗi lần thử vì `order_id` là khóa chính. Nếu vừa ghi mà replica chưa thấy, thử truy vấn lại do sao chép bất đồng bộ.

## Dừng và lưu dữ liệu

```powershell
docker compose --env-file infra/.env -f infra/compose-isolated.yaml stop
```

Lệnh này giữ các volume. Sau khi promote replica trong thí nghiệm failover, không chạy lại cụm như thể hai máy vẫn ở vai trò ban đầu: cần quy trình cô lập và tái tạo replica riêng. Không xóa volume nếu chưa kiểm tra dữ liệu và backup.

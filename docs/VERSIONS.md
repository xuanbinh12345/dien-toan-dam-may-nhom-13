# Phiên bản môi trường đã quan sát

Kiểm tra trên máy thực hiện lab ngày 19/11/2026 (giờ máy), bằng các
lệnh dưới đây. Đây là phiên bản tại thời điểm kiểm tra; không mặc định
máy thành viên khác có cùng phiên bản hoặc các lần thử đều dùng đúng
phiên bản Docker/Compose này.

| Thành phần | Kết quả quan sát | Lệnh kiểm tra |
|---|---|---|
| Git | `2.53.0.windows.2` | `git --version` |
| Docker | `29.9.2`, build `a82e528` | `docker --version` |
| Docker Compose | `v5.6.1` | `docker compose version` |
| PostgreSQL trong `lab13-integrated-primary-1` | `16.15` (Debian `16.15-1.pgdg13+2`) | `docker exec lab13-integrated-primary-1 postgres --version` |

Compose nguồn dùng tag `postgres:16`; tag có thể thay đổi khi tải image
mới, nên phiên bản trên không cố định cho mọi lần dựng. Các runbook ghi
điều kiện cụ thể của lần thử; khi tái lập trên máy khác, lưu lại phiên
bản và image ID/digest thực tế của lần chạy đó. Không kéo image mới vào
thay thế hoặc thay volume đã lưu chỉ để kiểm tra phiên bản.

Xem [kiến trúc](ARCHITECTURE.md), [tiến độ](PROGRESS.md) và
[hướng dẫn vận hành](OPERATIONS_COST_SECURITY.md).

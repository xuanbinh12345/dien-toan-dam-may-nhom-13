# Tổng hợp mục tiêu và quan sát RPO/RTO

Bảng tổng hợp các phép thử đã lưu của nhóm 13. Mục tiêu chỉ được ghi là
đã đặt trước khi có trong kế hoạch trước lần thử; không đặt ngưỡng sau
khi xem kết quả. Đây là các phép thử lab trên cùng Docker host, không
phải SLA hoặc bảo đảm cho mọi loại sự cố.

| Phép đo và run | Mục tiêu đã ghi trước | Quan sát | Đánh giá và phạm vi |
|---|---|---|---|
| Bảo toàn ACK tại biên failover, [FO-20261118-165349-5aac44](../results/RPO-FO-20261118-165349-5aac44.md) | Không thiếu mã đơn đã ACK trong lần dừng có kiểm soát | 204/204 ACK hiện diện; 1 UNCONFIRMED không hiện diện | Đạt mục tiêu số ACK trong lần thử. Đối chiếu ID, không phải checksum toàn bảng; chưa đo RPO theo thời gian hoặc chứng minh RPO = 0 khi lỗi đột ngột. [Kế hoạch](RPO_BOUNDARY_PLAN.md). |
| Bảo toàn dữ liệu đã sao chép, [REC-20261118-161901-297576](../results/recovery-REC-20261118-161901-297576/README.md) | Không thiếu 1132 ID ACK của sáu lượt tải trước failover | 1132/1132 ID hiện diện, 0 thiếu | Đạt trong lần thử. Các ID đã được xác nhận trên replica trước khi dừng, nên không đo mất dữ liệu tại biên sự cố. [Kế hoạch](RECOVERY_MEASUREMENT_PLAN.md). |
| Phục hồi ghi và đọc database, run REC trên | ≤ 30 giây từ yêu cầu dừng đến ghi và đọc lại thành công | 1,078 giây | Đạt ngưỡng lab trong một lần thử; không gồm phát hiện lỗi tự động, chuyển endpoint hoặc kiểm tra client ngoài host. Không phải RTO toàn bộ ứng dụng. |
| Chuyển ghi trong run FO trên | Không ghi ngưỡng số giây trước phép thử | 1,333 giây từ yêu cầu dừng đến ACK đầu tiên trên primary mới | Chỉ là thời gian quan sát của một lần thử; không đánh giá đạt/chưa đạt. Chưa gồm kiểm tra đọc, phát hiện lỗi hoặc chuyển endpoint ứng dụng. |
| PITR môi trường riêng, [PITR-20261117-194600](../results/PITR-20261117-194600/README.md) | Không ghi ngưỡng tổng thời gian phục hồi trước phép thử | 1,935 giây từ bắt đầu khởi động restore đến quan sát `paused`; 4 dòng/checksum khớp trước ghi thử | Thời gian chưa gồm chuẩn bị backup và kiểm tra đọc/ghi; không phải RTO toàn bộ. |
| [PITR tích hợp](../results/INT-20261118-150553/README.md) và [bản sao ổ D](../results/HOST-COPY-PITR-20261119.md) | Không ghi ngưỡng tổng thời gian trước phép thử | Từng lần khôi phục 4 dòng/checksum khớp, sau đó ghi và đọc lại thành công | Chưa đo thời gian toàn quy trình; ổ D cùng host, chưa kiểm chứng mất host. |

Replication bất đồng bộ có thể để mất giao dịch đã ACK trong tình huống
khác. `UNCONFIRMED` không chứng minh giao dịch đã commit và không được
tự động tính là ACK bị mất. Đo RPO theo thời gian cần định nghĩa mốc
giao dịch cuối có thể khôi phục và thời điểm sự cố, rồi ghi riêng cách đo.

## Lag trong điều kiện tải

[Sáu lượt đo](../results/repeat-lag-20261118/README.md) dùng ba mức nghỉ,
mỗi mức hai lần, ghi tuần tự qua Docker CLI. Mean từng lượt 1,302–1,460 ms,
P95 1,568–1,864 ms; đây là mẫu replay lag trong khoảng tải, không phải
thước đo RPO hay RTO. Lấy mẫu khoảng 2 giây có thể bỏ qua đỉnh ngắn.

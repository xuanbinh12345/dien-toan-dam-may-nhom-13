\# Minh chứng thành viên 3 — Dữ liệu, tải và đo lường



Các ảnh ghi lại cấu trúc dữ liệu, chạy tải, đo replication và

đối chiếu giao dịch trong lần thử ngày 17/11/2026.



| Ảnh | Nội dung |

|---|---|

| \[04](04\_cau\_truc\_bang\_orders.png) | Cấu trúc bảng orders |

| \[07](07\_tai\_doc\_ghi\_primary\_replica.png) | Tải đọc/ghi đang chạy |

| \[07b](07b\_tong\_ket\_tai\_444\_giao\_dich.png) | Tổng kết 444 giao dịch ACK và đọc thấy trên replica |

| \[08](08\_do\_tre\_replication\_khi\_co\_tai.png) | Replication trong lúc có tải |

| \[08b](08b\_replication\_sau\_khi\_ket\_thuc\_tai.png) | Replication sau khi tải kết thúc |

| \[09a](09a\_kiem\_tra\_script\_truoc\_failover.png) | Chạy thử script trước failover |

| \[10](10\_ghi\_thanh\_cong\_sau\_failover\_va\_thoi\_gian\_khoi\_phuc.png) | Thời gian khôi phục ghi quan sát được: 2,316 giây |

| \[10b](10b\_tai\_chuyen\_tu\_primary\_cu\_sang\_primary\_moi.png) | Tải chuyển sang primary mới |

| \[11](11\_doi\_chieu\_giao\_dich\_sau\_failover.png) | 510/510 giao dịch ACK còn hiện diện |



\## Phạm vi kết luận



\- Lần tải bình thường có 444 giao dịch được xác nhận và đọc thấy trên replica.

\- Lần failover có 511 lượt ghi: 510 ACK và 1 UNCONFIRMED.

\- Sau failover, không ghi nhận thiếu giao dịch ACK trong lần thử này.

\- Giao dịch UNCONFIRMED không hiện diện, không tính là ACK bị mất.

\- Thời gian 2,316 giây tính từ yêu cầu dừng primary đến ACK đầu tiên

&#x20; trên primary mới; không chỉ là thời gian promote.

\- Đây là một lần thử chủ động dừng container trên cùng Docker host.



Xem \[CSV và diễn giải kết quả](../../README.md).


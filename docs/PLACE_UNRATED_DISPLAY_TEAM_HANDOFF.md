# Bàn giao hotfix Place chưa có đánh giá — V27 client

Ngày30/10/2026, chủ dự án chọn đồng bộ bằng gói hotfix riêng cho đồng đội đã nhận Place Rating/Review V27. Gói bổ sung này không phát hành lại toàn bộ source local/Web Admin và không yêu cầu pull một nhánh WIP.

## Nghiệp vụ cuối cùng

- `reviewCount=0`: “Chưa có đánh giá”, số lượt0; không hiện5.0 hoặc0.0 như điểm thật, không tô năm sao mặc định. Count quyết định trạng thái, kể cả dữ liệu legacy average5/count0.
- Count>0: trung bình thật và số lượt thật. 5/1 → 5.0; 5+3 →4.0/2; sửa5 thành4 →3.5/2; xóa hết → chưa có đánh giá.
- Positive count nhưng average thiếu/ngoài1–5: báo điểm chưa khả dụng, không gán5 hoặc che thành chưa có review.
- API/DB vẫn dùng0/0 khi chưa có review. Không thay model AI, canonical identity, schema, API, permission, Global Block hoặc CRUD Review. Không xuất/copy dữ liệu người dùng.

## Phạm vi nhận

Gói đặt trên source tree của `GoMate_Place_Review_V27_20261030.zip` đã bàn giao trước; gói V27 đó được áp dụng sau published commit84ac037. Không áp dụng hotfix này vào clone chưa có V27. MANIFEST ghi chính xác source tree và hash trước/sau từng file; không giả tree hash là commit đã push.

Năm file Flutter/test: PlaceRating formatter/review DTO, Place detail/all-reviews, Home Place badge, Search Place badge và tests. Map selected card tái sử dụng formatter sẵn có; Trip Stop hiện không có UI rating nên không thêm nghiệp vụ Trip. Kiến thức cập nhật tối thiểu trên AGENTS, CODEX_INDEX và ghi chú Foundation cũ; tài liệu default-five trước đó là lịch sử đã bị quyết định mới thay thế.

Không kèm Web Admin, migration V28/V29, backend source, Docker config, private main/.env/Firebase, APK, DB backup hoặc AI dataset. Máy đồng đội đang V27 vẫn V27 sau khi áp dụng; máy đã V29 cũng không hạ version. Nguồn backend local của chủ dự án ở V29 không phải yêu cầu nâng DB của người nhận hotfix UI.

## Kiểm chứng / giới hạn

Source hotfix đã chạy334 Flutter tests PASS, analyze0 errors/14 warning cũ/366 info; 9 backend Place/Review tests PASS xác nhận contract không thay đổi. Các tests này chạy trên workspace chủ dự án, không được coi là đã chạy trên máy đồng đội. Gói đã được kiểm tra hash/CRC, preflight không ghi file, apply trên bản sao V27, áp dụng lại không ghi thêm, từ chối file lệch/gói lỗi/sai repo root; index và private main/env/backup cùng AI WIP được giữ nguyên trong bản kiểm tra.

APK hotfix đã build, nhưng Android hotfix mới **chưa được chủ dự án xác nhận PASS**; kết quả native CRUD V27 trước đó không phải bằng chứng UI hotfix mới. Gói này phục vụ cập nhật và kiểm thử, không gắn nhãn nghiệm thu Android hoàn tất.

Gói không chứa commit mới và chưa push Git. Không chạy git reset/checkout, overwrite toàn bộ thư mục hoặc cherry-pick nhánh local cũ. Nếu file cần sửa đã được đồng đội tùy biến, helper dừng trước khi ghi; gửi diff đúng file đó để merge có review. Những thay đổi AI ở file khác được giữ nguyên.

Sau cập nhật, đồng đội build lại Flutter bằng private main/config đang có, kiểm tra Place chưa review và chuỗi CRUD hai tài khoản. Không restore DB, không chạy migration mới và không rebuild Docker chỉ vì hotfix này.

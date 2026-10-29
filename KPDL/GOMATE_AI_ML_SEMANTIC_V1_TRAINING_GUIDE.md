# GoMate AI/ML v12 — Semantic-v1 Training and Cold Start

## 1. Mục tiêu của bản cập nhật

Bản này ghép release `semantic-v1 FINAL` vào pipeline v11 theo đúng hợp đồng Backend/Data:

- Giữ `external_id` làm định danh Place ổn định.
- Giữ nguyên 23 cột v11, đặc biệt `label`, `query_id`, `ma_tour` và `split_type`.
- Bổ sung semantic feature và mask để mô hình phân biệt tag có bằng chứng với tag chưa biết.
- Dùng Survey Screen 1–2 làm semantic preference.
- Để Screen 3 cho Backend contextual re-ranking.
- Giữ Association Rule feature và các feature train cũ.

Đây là cách mở rộng candidate ranker và bổ sung Content-Based cold-start. Không đổi taxonomy, Interest→Tag mapping hay `external_id` của semantic-v1.

## 2. Bộ dữ liệu đầu vào

### Train cũ

`ml_training_dataset_v11.csv` có:

| Thống kê | Giá trị |
| --- | ---: |
| Dòng candidate | 63.950 |
| Query | 2.387 |
| Place ID khác nhau xuất hiện trong candidate | 164 |
| `label=1` | 2.387 |
| `label=0` | 61.563 |
| Train / Val / Test rows | 52.350 / 5.191 / 6.409 |

Mỗi dòng là một `query_id` và một Place candidate. `label=1` nghĩa Place nằm trong tour/query thực tế của dữ liệu cũ; `label=0` nghĩa Place là candidate âm trong cách dựng v11. Semantic tag không tạo hoặc sửa `label`.

Một query hiện có đúng một candidate dương. Vì vậy trong bộ v11 này, Recall@K tương ứng với Hit Rate@K.

### Semantic-v1 FINAL

Release chính thức gồm 188 Place, 36 tag, 53 mapping Interest→Tag và 831 Place-tag links:

| Trạng thái | Số Place | Cách dùng |
| --- | ---: | --- |
| READY | 114 | Có profile semantic đủ dùng cho nhánh Content-Based |
| PARTIAL | 65 | Dùng tag có bằng chứng; tag thiếu phải được mask như unknown |
| NEED_REVIEW | 9 | Không dùng semantic làm cơ sở chính; fallback về ranker cũ |

Có 146 Place `runtime_eligible=true` và 42 Place chưa đủ điều kiện xuất hiện trong gợi ý runtime. Cờ này là điều kiện lọc ở Backend, không phải feature học của model.

Toàn bộ 164 `candidate_external_id` trong v11 khớp `external_id` của catalog mới; tên, destination và category cũng khớp. Trong tập candidate v11 có 99 Place READY, 57 PARTIAL và 8 NEED_REVIEW. 24 Place trong semantic catalog chưa xuất hiện trong v11 candidate lịch sử nên không có label train cũ cho các Place đó.

## 3. Dataset v12 xuất ra

`ml_training_dataset_v12_semantic_v1.csv` giữ nguyên các cột v11 theo đúng thứ tự ban đầu, sau đó thêm metadata semantic và các feature:

- 36 cột `sem_tag__<tag_code>`: trọng số tag chính thức từ ma trận semantic.
- 36 cột `sem_mask__<tag_code>`: `1` khi dimension được xem là có thể sử dụng; `0` khi dimension chưa biết hoặc profile không dùng được.
- `semantic_status`, `semantic_runtime_eligible`, `semantic_tag_count`, `semantic_data_version` và các trường canonical để kiểm tra join.

Policy tạo mask:

| Trạng thái | Tag weight | Mask |
| --- | --- | --- |
| READY | Giữ nguyên ma trận semantic-v1 | Mọi tag dimension được bật |
| PARTIAL | Giữ tag có link trong bảng Place-tag; tag thiếu lưu `0` | Chỉ tag có link được bật; phần còn lại là unknown |
| NEED_REVIEW | Không đưa semantic value vào model semantic | Mọi mask tắt; scoring dùng model cũ |

Giá trị `0` ở PARTIAL chỉ là ô lưu số; cột mask đi kèm nói rằng đó là dữ liệu chưa biết. Không được diễn giải cặp `tag=0, mask=0` thành “người dùng không thích Place”.

`semantic_status`, runtime eligibility, ID, tên, label và split là metadata; trainer không đưa các cột này vào `X`. Model semantic dùng tag values và masks cùng các feature v11.

## 4. Hai loại điểm

### 4.1 MLScore kế thừa từ v11

Giữ bài toán ranker cũ:

```text
MLScore(query, candidate) = P(label=1 | feature v11, semantic place features)
```

Random Forest dự đoán xác suất candidate là điểm thuộc lịch trình/query. Các feature Association Rules cũ vẫn còn:

```text
has_direct_rule, max_support, max_confidence,
max_lift, max_rule_score, is_ar_candidate
```

Các feature category, lịch trình, giá, popularity lịch sử và số lượng địa điểm cùng nhóm category cũng được giữ. Không cộng thêm `RuleScore` lần nữa vào đầu ra ranker nếu các rule features vẫn nằm trong model, vì như vậy có thể tính luật hai lần.

### 4.1.1 Baseline và Hybrid Score theo đề cương khóa luận

Trainer tính thêm các điểm công thức để bám sát yêu cầu đề cương:

| Thành phần | Công thức dễ hiểu | Dữ liệu đang dùng |
| --- | --- | --- |
| `AssociationRuleScore` | `0.20*support + 0.35*confidence + 0.25*lift + 0.20*direct_rule`, sau đó so với `max_rule_score` cũ và lấy điểm cao hơn | `max_support`, `max_confidence`, `max_lift`, `has_direct_rule`, `max_rule_score` |
| `SVDScore` | Cosine similarity giữa vector ẩn của candidate và hồ sơ các điểm đã có trước đó trong cùng tour | Ma trận `Tour x POI` fit từ train bằng TruncatedSVD |
| `ContentBasedScore` | Cosine similarity giữa vector semantic của candidate và hồ sơ semantic của các điểm đã có trước đó trong tour; runtime cold-start dùng vector từ khảo sát Screen 1-2 | Các cột `sem_tag__*` và `sem_mask__*` |
| `MLRankerScore` | Xác suất `P(label=1)` từ Random Forest ranker | Feature v11 + semantic feature |
| `PopularityScore` | Điểm phổ biến đã chuẩn hóa trong dữ liệu cũ | `candidate_popularity` |
| `SpatialScore` | Không đưa vào Hybrid offline nếu thiếu dữ liệu | v11 chưa có GPS/distance runtime |
| `TemporalScore` | Không đưa vào Hybrid offline nếu thiếu dữ liệu | v11 chưa có giờ mở cửa, traffic, thời điểm truy vấn |
| `GroupScore` | Proxy từ mức lặp category trong tour | `same_category_count`, `num_selected_places` |

Công thức lai đang ghi vào report:

```text
HybridScore(q,i) =
  sum(w_m * score_m(q,i) for available m)
  / sum(w_m for available m)
```

Trọng số mặc định trong trainer:

| Thành phần | Tỷ trọng | Lý do |
| --- | ---: | --- |
| Content-based | 30% | Quan trọng cho cold-start và semantic preference |
| ML Ranker | 30% | Tận dụng mô hình học từ label v11 |
| Association Rules | 20% | Giữ quan hệ đồng xuất hiện từ model cũ, ví dụ Place A thường đi cùng Place B |
| Popularity | 10% | Giúp ưu tiên địa điểm quen thuộc, nhưng không để lấn át sở thích |
| Spatial | 5% | Chỉ bật khi Backend có khoảng cách/GPS thật |
| Temporal | 3% | Chỉ bật khi Backend có thời gian, giờ mở cửa hoặc thống kê theo khung thời gian |
| Group | 2% | Dataset cũ chưa có nhiều thông tin nhóm nên chỉ dùng proxy nhẹ |

Trong train offline, `SpatialScore` và `TemporalScore` được đánh dấu không khả dụng nên không đi vào mẫu số/mẫu tử của HybridScore. Khi Backend chạy thật, các điểm này nên được tính lại bằng dữ liệu runtime như khoảng cách GPS, thời gian di chuyển, giờ mở cửa và ngữ cảnh hiện tại. Nếu Backend đã tính “gần tôi”, “địa điểm hot”, review/rating thì không cộng lại lần nữa trong AI service.

Trainer tạo hai nhánh cùng cấu hình Random Forest:

1. `legacy_v11_ranker`: chỉ dùng feature v11.
2. `semantic_v1_ranker`: dùng feature v11 + 36 tag values + 36 masks, chỉ fit trên READY/PARTIAL. Candidate NEED_REVIEW dùng điểm nhánh cũ.

Chọn nhánh theo NDCG@5 trên Validation. Test chỉ dùng để báo cáo kết quả sau khi đã chọn. Split hiện có được giữ nguyên và kiểm tra không chia cùng tour/query qua nhiều split.

### 4.2 ContentScore cho cold-start

ContentScore dùng trực tiếp survey Màn 1–2 với mapping semantic-v1. Không dùng Survey Screen 3 trong profile dài hạn.

Gộp nhiều lựa chọn survey bằng trọng số lớn nhất trên cùng tag để không cộng lặp:

```text
user_weight(tag) = max(mapping_weight(interest, tag))
                  trên các interest đã chọn
```

Với tổng trọng số sở thích `D = sum(user_weight(tag))`, Place có profile READY:

```text
semantic_score = sum(user_weight(tag) * place_weight(tag)) / D
semantic_coverage = 1
```

Với PARTIAL, chỉ các tag có link chính thức được coi là đã quan sát:

```text
known_mass = sum(user_weight(tag)) trên tag có bằng chứng
matched_mass = sum(user_weight(tag) * place_weight(tag)) trên tag có bằng chứng
coverage = known_mass / D
score_lower = matched_mass / D
score_upper = (matched_mass + D - known_mass) / D
```

`score_lower` là lượng bằng chứng khớp đã xác nhận. `score_upper` thể hiện mức tối đa nếu các tag còn thiếu sau này được xác nhận là phù hợp. Khoảng rộng nghĩa là dữ liệu còn không chắc chắn, không phải Place bị người dùng chê.

Nếu PARTIAL chưa có tag nào liên quan đến lựa chọn survey, scorer trả khoảng `[0, 1]`, coverage `0` và `semantic_signal_available=false`; không dùng số 0 đó như một tín hiệu chống gợi ý.

Với NEED_REVIEW, ContentScore không khả dụng và Backend/AI dùng ranker không semantic làm fallback. Trường hợp interest chưa có mapping chính thức cũng không tự bịa tag; scorer báo mã chưa map.

## 5. Điểm chưa thể học trực tiếp từ v11

V11 không có câu trả lời Survey Màn 1–2 gắn với `query_id`. File taxonomy/mapping chỉ định nghĩa mã khảo sát và ý nghĩa tag, không phải câu trả lời của từng query.

Vì vậy:

- V12 RF học cách tag của candidate liên hệ với nhãn lịch trình cũ.
- ContentScore có thể tính khi user gửi survey ở runtime.
- Không thể dùng v11 để khẳng định RF đã học sở thích survey cá nhân.
- Chưa thể tune trọng số MLScore/ContentScore theo survey bằng Validation cho đến khi có bảng nối `query_id, selected_interest_codes` hoặc tập đánh giá có survey và đáp án liên quan.
- Không suy ra survey từ candidate `label=1`; làm vậy sẽ rò rỉ đáp án.

Do đó bản trainer hiện dùng trọng số hybrid có giải thích để phục vụ báo cáo thực nghiệm, đồng thời ghi rõ phần nào là proxy vì dataset v11 chưa có survey thật. Khi có bảng nối `query_id, selected_interest_codes`, cần tune lại các trọng số trên Validation theo NDCG@5 rồi đánh giá một lần trên Test.

## 6. Screen 3 và tránh tính trùng

Semantic-v1 giao phần lớn Screen 3 cho Backend:

| Survey | Chủ sở hữu theo release | Trong v12 AI |
| --- | --- | --- |
| GAN_TOI | Backend: GPS/khoảng cách | Không có `distance_km` |
| DI_TRONG_NGAY | Backend: thời gian tuyến, giờ mở cửa | Không tính route/opening hours |
| CO_REVIEW | Backend: số review/rating | Không có review_count/avg_rating |
| DANG_HOT | Backend contextual ranking | V11 đã có `candidate_popularity`, `candidate_is_core`, `category_frequency`; phải kiểm tra nguồn trước khi Backend cộng thêm popularity tương tự |
| LOCAL | Shared | Chưa cộng boost riêng |

Vì thế API AI cần nói rõ `MLScore` đã dùng popularity lịch sử và Association Rule features. Backend có thể cộng distance/review/trend riêng nếu khác nguồn và đã thống nhất; nếu không, cần loại tín hiệu trùng khỏi một phía.

## 7. Cold-start runtime flow

1. Backend lọc Place `runtime_eligible=true` và Place còn ACTIVE.
2. AI nhận candidate `external_id`, survey interest Màn 1–2 và metadata semantic-v1.
3. Content scorer trả `semantic_score`, `semantic_score_upper`, `semantic_coverage`, `semantic_status`.
4. Ranker trả `ml_score`; nếu Place NEED_REVIEW thì dùng ranker cũ không semantic.
5. Backend áp dụng Screen 3 và trả kết quả cho app.

Trong model bundle vừa train, `selectedStrategy` hiện là `legacy_v11_ranker`; tức MLScore được chọn chưa dùng semantic RF. Content scorer vẫn chạy riêng với lựa chọn survey. Không gọi nhánh semantic RF là model cuối cho tới khi Validation chứng minh tốt hơn.

Output gợi ý cho mỗi Place:

```json
{
  "external_id": "da_lat:ho_tuyen_lam",
  "ml_score": 0.81,
  "semantic_score": 0.62,
  "semantic_score_upper": 0.62,
  "semantic_coverage": 1.0,
  "semantic_status": "READY",
  "model_version": "gomate-ranker-v12-semantic-v1",
  "semantic_data_version": "semantic-v1",
  "score_includes": ["association_rules", "historical_candidate_popularity"],
  "score_excludes": ["distance", "review", "route_time", "live_hot_context"]
}
```

Ví dụ minh họa schema, không phải điểm đã tính từ một request thực.

## 8. Coverage và limitation đã biết

Release QA đã xác nhận hai sanity issue về `AM_THUC`: nhóm địa điểm Hà Nội và Vũng Tàu có semantic coverage thưa. Giữ nguyên release đã freeze; không sửa taxonomy, mapping hoặc tag để “làm đẹp” điểm. Báo cáo kết quả Content-Based nên tách theo interest/destination để limitation này không bị che bởi số trung bình.

Sanity ranking CSV là công cụ QA, không phải label train. Không đưa `semantic_sanity_scores_v1.csv` vào train như đáp án.

## 9. Chỉ số đánh giá

Trainer báo:

```text
Precision@3, Recall@3, NDCG@3
Precision@5, Recall@5, NDCG@5
Precision@10, Recall@10, NDCG@10
MRR
```

Với một positive/query, Recall@K = Hit Rate@K. Chọn model bằng Validation NDCG@5. Báo Test sau lựa chọn; không dùng Test để chỉnh hệ số.

### Kết quả của lượt train trong bundle

Hai nhánh được chạy cùng split, cùng cấu hình Random Forest. Nhánh semantic dùng tag/mask với READY/PARTIAL; NEED_REVIEW quay về điểm ranker cũ.

| Validation | Precision@5 | Recall@5 | NDCG@5 | MRR |
| --- | ---: | ---: | ---: | ---: |
| Ranker v11 | 0.1460 | 0.7302 | **0.5930** | 0.5688 |
| Semantic-v1 + fallback | 0.1439 | 0.7196 | 0.5783 | 0.5532 |

Theo tiêu chí đã định trước là Validation NDCG@5, lượt này chọn `legacy_v11_ranker`. Vì vậy semantic candidate feature chưa được bật làm ranker cuối trong model bundle.

| Test sau khi chọn | Precision@5 | Recall@5 | NDCG@5 | MRR |
| --- | ---: | ---: | ---: | ---: |
| Ranker được chọn: v11 | 0.1655 | 0.8277 | 0.7020 | 0.6740 |
| Semantic-v1 + fallback, chỉ để đối chiếu | 0.1681 | 0.8403 | 0.7032 | 0.6707 |

Nhánh semantic nhỉnh nhẹ trên Test nhưng kém hơn trên Validation. Không đổi lựa chọn sau khi xem Test; làm vậy sẽ dùng Test để tune. Đây là kết quả honest của một lượt train/evaluate, không phải bằng chứng semantic đã cải thiện ranker.

Test trên có 238 query; Validation có 189. Khoảng này còn nhỏ, nên các khác biệt rất nhỏ cần được xem là chưa ổn định.

## 10. Tạo dữ liệu và train

Yêu cầu Python: `pandas`, `numpy`, `scikit-learn`, `joblib`.

Trên Windows PowerShell có thể chạy cả build và train bằng:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\run_training.ps1
```

Hoặc chạy từng bước:

```powershell
py -m pip install -r requirements.txt
py build_ml_dataset_v12_semantic_v1.py `
  --v11 ml_training_dataset_v11.csv `
  --semantic-dir semantic_v1 `
  --output ml_training_dataset_v12_semantic_v1.csv
py train_ml_model_v12_semantic_v1.py `
  --dataset ml_training_dataset_v12_semantic_v1.csv `
  --outdir training_output
```

Cold-start scoring theo survey:

```powershell
py semantic_content_score_v1.py `
  --interests THIEN_NHIEN BIEN_NUI `
  --destination da_lat `
  --output training_output/da_lat_nature_scores.csv
```

Kết quả tạo ra:

- `ml_training_dataset_v12_semantic_v1.csv`: v11 + semantic features/masks.
- `ml_training_dataset_v12_semantic_v1_manifest.json`: row/label/split counts, release version, hashes.
- `training_output/gomate_ranker_v12_semantic_v1.joblib`: model bundle gồm ranker cũ và semantic ranker.
- `training_output/training_report_v12_semantic_v1.json`: cấu hình, Validation/Test metrics và score ownership.
- `training_output/test_candidate_scores_v12_semantic_v1.csv`: score từng test candidate để audit.
- `training_output/da_lat_nature_scores.csv`: output ContentScore khi chạy semantic scorer.

## 11. Điều chưa có trong gói

RAR bàn giao semantic-v1 không chứa source code train v11. Vì vậy scripts trong gói này là trainer tương thích với schema v11, không phải bản sửa trực tiếp file Python cũ. Model v11 được mô tả là Random Forest trong tài liệu dự án; trainer ghi rõ cấu hình mới để kết quả có thể tái lập.

Gói này đã có SVD baseline offline và GroupScore dạng proxy nhẹ. Gói này chưa triển khai FastAPI endpoint, route-time scoring, GPS distance thật, giờ mở cửa thật hoặc group vote thật. Các phần đó cần interaction/group/runtime context tương ứng; không thể suy ra từ semantic-v1 hay nhãn v11 hiện có.

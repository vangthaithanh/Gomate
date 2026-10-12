# Tài liệu bàn giao Backend – GoMate Ranker v13

## 1. Mục đích của tài liệu

Tài liệu này mô tả cách Backend sử dụng mô hình khuyến nghị **GoMate Ranker v13**.

Phiên bản v13 được huấn luyện để xếp hạng các địa điểm ứng viên trong bài toán
cold-start. Model không tự tạo ra địa điểm mới và cũng không tự sinh ra
`external_id`. Backend vẫn phải cung cấp danh sách ứng viên, sau đó model chấm
điểm từng ứng viên và sắp xếp điểm từ cao xuống thấp.

Phiên bản đang chạy ổn định của API hiện tại là **v12**. File v13 là model
nghiên cứu mới; không nên chỉ đổi tên đường dẫn model v12 thành v13 nếu API
chưa xây dựng bước tạo đầy đủ các đặc trưng v13.

---

## 2. Các file quan trọng của v13

```text
train_ml_research_v13.py
place_catalog_v11.csv
training_output_research_final/
├── gomate_ranker_research_v13.joblib
├── training_report_research_v13.json
├── research_model_comparison_v13.csv
└── test_candidate_scores_research_v13.csv
```

Ý nghĩa:

| File | Vai trò |
|---|---|
| `train_ml_research_v13.py` | Mã nguồn tạo dataset đặc trưng, huấn luyện và đánh giá model |
| `place_catalog_v11.csv` | Danh mục địa điểm và định danh ổn định của địa điểm |
| `gomate_ranker_research_v13.joblib` | Model đã huấn luyện và metadata để chạy dự đoán |
| `training_report_research_v13.json` | Cấu hình train, danh sách đặc trưng và kết quả đánh giá |
| `research_model_comparison_v13.csv` | Bảng so sánh các phương pháp trên Validation và Test |
| `test_candidate_scores_research_v13.csv` | Điểm chi tiết của từng ứng viên trong tập Test |

Backend nên đọc `training_report_research_v13.json` để kiểm tra phiên bản và
đọc `gomate_ranker_research_v13.joblib` để chấm điểm.

---

## 3. Thông tin phiên bản cố định

```text
model_version: gomate-ranker-research-v13
training_data_version: ml-training-v12-semantic-v1
semantic_data_version: semantic-v1
estimator: RandomForestClassifier
trees: 200
min_samples_leaf: 4
max_features: sqrt
class_weight: balanced_subsample
random_state: 42
```

`ml-training-v12-semantic-v1` là phiên bản dữ liệu dùng để huấn luyện. Điều
này không có nghĩa v13 là model v12. V13 là phiên bản mã nguồn và bundle model
mới, được huấn luyện trên bộ dữ liệu semantic-v1 đã đóng băng.

Số `200` là số cây quyết định trong rừng ngẫu nhiên, không phải 200 vòng lặp
huấn luyện. Random Forest không sử dụng khái niệm epoch như mạng nơ-ron.

---

## 4. Backend cần làm gì khi có yêu cầu khảo sát?

Ví dụ người dùng chọn:

```json
{
  "destination_key": "da_lat",
  "selected_interest_codes": ["THIEN_NHIEN", "CHECKIN_HOT"],
  "context_codes": ["GAN_TOI", "DANG_HOT"],
  "top_k": 10
}
```

Quy trình xử lý đúng:

1. Backend nhận các mã sở thích và bối cảnh từ màn hình khảo sát.
2. Backend dùng `external_id` trong danh mục địa điểm để lấy danh sách ứng viên.
3. Backend quy đổi sở thích thành tín hiệu semantic theo mapping chính thức.
4. Backend tạo đặc trưng cho từng cặp truy vấn – địa điểm ứng viên.
5. Model v13 chấm điểm từng ứng viên.
6. Backend sắp xếp ứng viên theo điểm giảm dần.
7. Backend lấy `top_k` địa điểm đầu tiên và trả về cho ứng dụng.
8. Các yếu tố như gần người dùng, thời gian di chuyển, giờ mở cửa và tín hiệu
   nóng trực tiếp được Backend xử lý ở bước xếp hạng lại theo bối cảnh.

Model không nhận trực tiếp câu chữ “núi rừng, địa điểm hot, gần tôi” để tự
hiểu như một mô hình ngôn ngữ. Backend phải chuyển lựa chọn đó thành mã khảo
sát và các đặc trưng số trước khi gọi model.

---

## 5. Danh sách đặc trưng v13

### 5.1. Đặc trưng thông tin tour và địa điểm

```text
destination_key
candidate_category
so_ngay
so_dem
gia_tu_scaled
day_index
num_selected_places
candidate_popularity
candidate_is_core
category_frequency
same_category_count
has_direct_rule
max_support
max_confidence
max_lift
max_rule_score
is_ar_candidate
```

Nhóm này mô tả địa điểm đang xét, bối cảnh tour và mức độ liên quan của địa
điểm theo luật kết hợp.

### 5.2. Đặc trưng ngữ nghĩa

Các cột dạng:

```text
sem_tag__nature
sem_tag__mountain
sem_tag__forest
sem_tag__lake
sem_tag__beach
sem_tag__food
sem_tag__heritage
sem_tag__photo_spot
...
```

Giá trị của `sem_tag__...` biểu thị địa điểm có tag semantic tương ứng hay
không.

### 5.3. Mặt nạ độ đầy đủ dữ liệu

Mỗi tag semantic có một cột mặt nạ tương ứng:

```text
sem_mask__nature
sem_mask__mountain
sem_mask__forest
sem_mask__lake
sem_mask__beach
sem_mask__food
sem_mask__heritage
...
```

Mặt nạ giúp model phân biệt hai trường hợp:

- Địa điểm đã được kiểm tra và thật sự không có tag.
- Dữ liệu chưa đủ nên chưa biết địa điểm có tag hay không.

Đặc biệt, tag bị thiếu ở địa điểm `PARTIAL` không được xem mặc định là sở
thích tiêu cực.

### 5.4. Các cột không đưa trực tiếp vào model

Các cột sau dùng làm định danh, nhãn hoặc metadata, không đưa trực tiếp vào
vector dự đoán:

```text
query_id
ma_tour
candidate_external_id
candidate_canonical_name
split_type
label
semantic_status
semantic_runtime_eligible
semantic_tag_count
semantic_data_version
```

`candidate_external_id` dùng để đối chiếu kết quả với danh mục địa điểm, không
phải là một đặc trưng số để model tự học.

---

## 6. Cách đọc file model v13

Bundle v13 được lưu bằng Joblib và có cấu trúc chính:

```python
{
    "model_version": "gomate-ranker-research-v13",
    "base_model": ...,        # Random Forest dùng đặc trưng nền
    "semantic_model": ...,    # Random Forest có thêm semantic và mask
    "base_features": [...],
    "semantic_features": [...],
    "selected_strategy": ..., 
    "selected_research_formula": "uncertaintyHybrid",
    "semantic_data_version": "semantic-v1"
}
```

Ví dụ đọc model:

```python
import joblib

bundle = joblib.load(
    "training_output_research_final/gomate_ranker_research_v13.joblib"
)

print(bundle["model_version"])
print(bundle["selected_strategy"])
print(bundle["base_features"])
print(bundle["semantic_features"])
```

Không gọi trực tiếp:

```python
bundle.predict(...)
```

Vì bundle là một dictionary chứa nhiều thành phần. Cần lấy đúng model con:

```python
model = bundle["base_model"]
score = model.predict_proba(frame[bundle["base_features"]])[:, 1]
```

Nếu dùng mô hình semantic:

```python
model = bundle["semantic_model"]
score = model.predict_proba(frame[bundle["semantic_features"]])[:, 1]
```

`score` là xác suất model dự đoán mẫu đó thuộc lớp dương `label = 1`. Điểm
này nằm trong khoảng từ 0 đến 1 và dùng để xếp hạng, không phải phần trăm chắc
chắn người dùng sẽ đi địa điểm đó.

---

## 7. Quy tắc chọn model theo trạng thái semantic

Backend đọc giá trị `selected_strategy` trong bundle, không nên tự đoán tên
chiến lược.

Quy tắc tổng quát:

| Trạng thái địa điểm | Cách xử lý |
|---|---|
| `READY` | Có thể dùng model semantic nếu `selected_strategy` cho phép |
| `PARTIAL` | Có thể dùng semantic nhưng phải giữ các cột mặt nạ để thể hiện độ không chắc chắn |
| `NEED_REVIEW` | Dùng model nền; không lấy semantic làm cơ sở chính |

Trong lần train v13 hiện tại, báo cáo ghi chiến lược Random Forest được chọn
là `legacy_v11_ranker`. Vì vậy Backend phải đọc đúng `selected_strategy` trong
file model/report trước khi quyết định dùng `base_model` hay `semantic_model`.

---

## 8. Công thức nghiên cứu được đề xuất

V13 có công thức lai điều chỉnh theo độ đầy đủ dữ liệu ngữ nghĩa:

```text
UncertaintyHybridScore(q,i) =
(
    0.20 × AssociationRuleScore(q,i)
  + 0.30 × ContentBasedScore(q,i) × u_i
  + 0.30 × MLScore(q,i)
  + 0.10 × PopularityScore(i)
)
/
(
    0.20 + 0.30 × u_i + 0.30 + 0.10
)
```

Trong đó:

- `q`: truy vấn hoặc bối cảnh người dùng.
- `i`: địa điểm ứng viên.
- `AssociationRuleScore`: điểm địa điểm đi kèm theo luật kết hợp.
- `ContentBasedScore`: độ tương đồng semantic giữa sở thích và địa điểm.
- `MLScore`: xác suất lớp dương do Random Forest trả về.
- `PopularityScore`: điểm phổ biến đã chuẩn hóa.
- `u_i`: độ đầy đủ của dữ liệu semantic tại địa điểm `i`.

Quy tắc tính `u_i`:

```text
READY       → u_i = 1
PARTIAL     → u_i = trung bình các giá trị mặt nạ semantic
NEED_REVIEW → u_i = 0
```

Ý nghĩa của công thức: khi thông tin semantic của địa điểm chưa đầy đủ, ảnh
hưởng của Content-Based được giảm xuống theo mức độ tin cậy thay vì phạt địa
điểm đó như một địa điểm không phù hợp. Các thành phần khác vẫn được giữ lại.

---

## 9. Phân chia trách nhiệm giữa AI và Backend

### Model v13 chịu trách nhiệm

- Tính điểm phù hợp từ đặc trưng của ứng viên.
- Học quan hệ giữa thông tin tour, địa điểm, luật kết hợp và semantic.
- Trả xác suất lớp dương để Backend xếp hạng.
- Cung cấp điểm phục vụ so sánh và đánh giá offline.

### Backend chịu trách nhiệm

- Giữ nguyên `external_id` làm định danh địa điểm.
- Chuẩn bị danh sách ứng viên hợp lệ.
- Chuyển khảo sát thành mã sở thích theo mapping chính thức.
- Tạo đúng tên và kiểu dữ liệu của các đặc trưng.
- Tính khoảng cách, thời gian di chuyển, giờ mở cửa và dữ liệu giao thông nếu có.
- Xử lý các mã bối cảnh của màn hình 3 như `GAN_TOI` và `DANG_HOT`.
- Xếp hạng lại theo bối cảnh thực tế sau khi nhận điểm AI.
- Không cộng lại cùng một tín hiệu hai lần.

Trong v13, khoảng cách, đánh giá, số lượt review và tín hiệu màn hình 3 không
được đưa vào điểm train. Vì vậy Backend được phép dùng chúng ở bước xếp hạng
lại. Ngược lại, `candidate_popularity`, `candidate_is_core` và
`category_frequency` đã xuất hiện trong đặc trưng model; cần kiểm tra trước
khi cộng thêm popularity lần nữa.

---

## 10. Kết quả trả về nên có dạng gì?

Model chỉ trả điểm cho các ứng viên. Backend nên ghép điểm đó với thông tin
địa điểm để tạo response:

```json
{
  "model_version": "gomate-ranker-research-v13",
  "selected_strategy": "legacy_v11_ranker",
  "destination_key": "da_lat",
  "items": [
    {
      "rank": 1,
      "external_id": "da_lat:nui_langbiang",
      "name": "Núi Langbiang",
      "category": "nature",
      "ai_score": 0.8734,
      "semantic_status": "READY",
      "semantic_coverage": 1.0,
      "distance_km": 4.2
    }
  ]
}
```

`external_id`, tên địa điểm, khoảng cách và thông tin hiển thị lấy từ Backend
hoặc danh mục địa điểm. `ai_score` là điểm xếp hạng của model, không phải ID
địa điểm.

---

## 11. Các chỉ số đánh giá v13

Các chỉ số trong report được tính offline trên các truy vấn đã chia theo
`query_id`:

- `Precision@5`: trong 5 địa điểm đầu tiên, có bao nhiêu địa điểm đúng.
- `Recall@5`: địa điểm đúng có xuất hiện trong 5 vị trí đầu tiên hay không.
- `NDCG@5`: kết quả đúng có được xếp ở vị trí cao hay không.
- `MRR`: vị trí trung bình của kết quả đúng đầu tiên.

Kết quả Test của cấu hình nghiên cứu hiện tại được lưu chính thức trong:

```text
training_output_research_final/training_report_research_v13.json
```

Backend không nên gọi các chỉ số này là độ chính xác tuyệt đối của người dùng
ngoài thực tế. Đây là kết quả đánh giá offline trên dữ liệu lịch sử.

---

## 12. Cách chuyển Backend từ v12 sang v13 an toàn

Không thay trực tiếp model v12 trong lần đầu. Thực hiện theo thứ tự:

1. Giữ nguyên endpoint v12 đang chạy.
2. Đặt file `gomate_ranker_research_v13.joblib` vào thư mục model riêng.
3. Tạo một loader riêng cho v13.
4. Kiểm tra tên và thứ tự cột đầu vào theo `training_report_research_v13.json`.
5. Chạy cùng một request trên v12 và v13.
6. So sánh `external_id`, điểm và thứ hạng trả về.
7. Kiểm tra riêng các trường hợp `READY`, `PARTIAL` và `NEED_REVIEW`.
8. Chỉ bật v13 bằng cấu hình hoặc endpoint riêng sau khi kết quả hợp lệ.

Ví dụ endpoint thử nghiệm:

```text
POST /recommend-v13
```

Endpoint hiện tại `/recommend` của Backend vẫn có thể tiếp tục dùng v12 trong
giai đoạn kiểm tra. Việc đổi sang v13 cần có adapter tạo feature frame đúng
schema, không chỉ đổi chuỗi đường dẫn model.

---

## 13. Kết luận ngắn cho Backend

V13 nhận đặc trưng của từng cặp truy vấn – địa điểm, trả về một điểm từ 0 đến
1 cho mỗi địa điểm. Backend dùng điểm đó để sắp xếp danh sách, giữ nguyên
`external_id` và trả về `top_k` kết quả.

V13 bổ sung cách xử lý dữ liệu semantic chưa đầy đủ bằng mặt nạ và biến độ tin
cậy `u_i`. Tuy nhiên, khoảng cách, thời gian, đánh giá và bối cảnh màn hình 3
vẫn thuộc trách nhiệm của Backend. V12 đang chạy ổn định nên v13 cần được tích
hợp qua adapter hoặc endpoint riêng trước khi thay thế production.

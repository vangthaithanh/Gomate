# GoMate AI API Docker Guide

## 1. Chay truc tiep khong Docker

```powershell
py -3.11 -m pip install -r requirements.txt
py -3.11 -m uvicorn api_service:app --host 0.0.0.0 --port 8000 --reload
```

Kiem tra:

```powershell
curl http://localhost:8000/health
```

## 2. Dong goi Docker

Build image:

```powershell
docker build -t gomate-ai-recommender:research-v15 .
```

Run container:

```powershell
docker run --name gomate-ai -p 8000:8000 gomate-ai-recommender:research-v15
```

Kiem tra:

```powershell
curl http://localhost:8000/health
```

## 3. Test recommend bang Postman

Method:

```text
POST
```

URL:

```text
http://localhost:8000/recommend
```

Headers:

```text
Content-Type: application/json
```

Body:

```json
{
  "destination_key": "da_lat",
  "selected_interest_codes": ["THIEN_NHIEN", "CHECKIN_HOT", "BIEN_NUI"],
  "context_codes": ["GAN_TOI", "DANG_HOT"],
  "top_k": 10,
  "history_external_ids": []
}
```

`history_external_ids` la tuy chon. Backend chi gui cac `external_id` hop le
tu lich su Trip cua user dang dang nhap; khong gui email, token hay tu khoa
tim kiem. Khi danh sach rong, API giu cold-start semantic. Khi co history,
API chi bat Association Rules/SVD neu co du lieu va artifact tuong ung.

Ket qua tra ve gom danh sach dia diem da sap xep:

```json
{
  "model_version": "gomate-ranker-research-v15-screen12-strict",
  "selected_strategy": "hybrid_recommendation_score_screen12",
  "destination_key": "da_lat",
  "selected_interest_codes": ["THIEN_NHIEN", "CHECKIN_HOT", "BIEN_NUI"],
  "context_codes_received": ["GAN_TOI", "DANG_HOT"],
  "context_note": "AI combines only available components; Screen 3 context codes are returned for Backend reranking.",
  "total_candidates": 41,
  "component_availability": {
    "association_rule": false,
    "svd": false,
    "content_based": true
  },
  "component_unavailable_reasons": {
    "association_rule": "no_history_place_in_rule_source",
    "svd": "no_history_place_in_svd_artifact",
    "content_based": "semantic_v1_survey_scoring"
  },
  "items": [
    {
      "rank": 1,
      "external_id": "da_lat:doi_che_cau_dat",
      "name": "Doi Che Cau Dat",
      "destination_key": "da_lat",
      "category": "nature",
      "semantic_status": "READY",
      "semantic_score": 0.3911111111,
      "semantic_score_upper": 0.3911111111,
      "semantic_coverage": 1.0,
      "semantic_signal_available": true,
      "hybrid_score": 0.3911111111,
      "association_rule_score": null,
      "association_rule_available": false,
      "svd_score": null,
      "svd_available": false
    }
  ]
}
```

## 4. Backend goi HTTP

Backend chi can goi:

```text
POST http://localhost:8000/recommend
```

Khi deploy that, thay `localhost` bang IP/domain cua may chay AI service.

Screen 1-2 dua vao `selected_interest_codes`.

Screen 3 nhu `GAN_TOI`, `DANG_HOT`, `CO_REVIEW`, `DI_TRONG_NGAY` nen de Backend tinh tiep bang GPS, popularity, review va thoi gian di chuyen.

Voi request khong co history, AI dung content/semantic component de giu
cold-start. Voi history hop le, API dung pairwise rules tu cac tour train da
dong bang va item embeddings SVD Tour x Place da luu trong artifact. Day la
adapter thu nghiem, khong phai model User x Place va khong tu hoc online.

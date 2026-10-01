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
docker build -t gomate-ai-recommender:semantic-v1 .
```

Run container:

```powershell
docker run --name gomate-ai -p 8000:8000 gomate-ai-recommender:semantic-v1
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
  "top_k": 10
}
```

Ket qua tra ve gom danh sach dia diem da sap xep:

```json
{
  "model_version": "gomate-ranker-v12-semantic-v1",
  "selected_strategy": "legacy_v11_ranker",
  "destination_key": "da_lat",
  "selected_interest_codes": ["THIEN_NHIEN", "CHECKIN_HOT", "BIEN_NUI"],
  "context_codes_received": ["GAN_TOI", "DANG_HOT"],
  "context_note": "Screen 3 context codes are returned for Backend reranking. This API score uses Screen 1-2 semantic interests only.",
  "total_candidates": 41,
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
      "semantic_signal_available": true
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

# KPDL v11 cold-start patch cho GoMate

## Mục đích
Patch này nhận mã lựa chọn từ 3 nhóm khảo sát Flutter, ánh xạ sang category địa điểm và tạo gợi ý địa điểm cold-start. AI giữ `externalId`; Spring Boot đổi sang `places.id` PostgreSQL.

## Chép vào KPDL
Giải nén các file trong patch vào thư mục gốc `KPDL` hiện tại, nơi đã có `model_artifacts_v11/`, `ai_place_features_v11.csv` và `ai_place_catalog_v11.csv`. Không xóa `model_artifacts_v11`.

## Chạy trên PowerShell
```powershell
cd C:\duong-dan\KPDL
python -m venv .venv_ai
.\.venv_ai\Scripts\Activate.ps1
python -m pip install -r requirements-ai.txt
uvicorn ai_service:app --host 0.0.0.0 --port 8000
```
Nếu PowerShell chặn activate: `Set-ExecutionPolicy -Scope Process Bypass`.

## Kiểm tra
Mở PowerShell thứ hai:
```powershell
cd C:\duong-dan\KPDL
.\.venv_ai\Scripts\Activate.ps1
python test_cold_start.py
```
Gọi API:
```powershell
$body = @{ optionCodes = @('THIEN_NHIEN','BIEN_NUI','GAN_TOI','DANG_HOT'); latitude = 10.8231; longitude = 106.6297; topK = 5 } | ConvertTo-Json
Invoke-RestMethod -Uri http://localhost:8000/recommendations/cold-start -Method Post -ContentType 'application/json' -Body $body
```

## Chế độ điểm
Nếu có `model_artifacts_v11/ml_models/global_model.pkl` và `preprocessor.pkl`, API dùng thêm global model đã train. Nếu chưa có, API vẫn chạy bằng category, core place, popularity và khoảng cách, đồng thời trả cảnh báo.

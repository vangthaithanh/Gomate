param(
  [string]$CatalogPath = "backend/src/main/resources/data/place_catalog_v11.csv",
  [string]$OutputDir = "backend/src/main/resources/data/ai_handoff/semantic_v1",
  [string]$PackageDir = "AI_HANDOFF_SEMANTIC_V1_FINAL"
)

$ErrorActionPreference = "Stop"

python scripts/generate_semantic_v1_final.py `
  --catalog $CatalogPath `
  --output-dir $OutputDir `
  --package-dir $PackageDir

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

py -m pip install -r requirements.txt
if ($LASTEXITCODE -ne 0) { throw "Could not install Python requirements." }

py build_ml_dataset_v12_semantic_v1.py `
  --v11 ml_training_dataset_v11.csv `
  --semantic-dir semantic_v1 `
  --output ml_training_dataset_v12_semantic_v1.csv
if ($LASTEXITCODE -ne 0) { throw "Dataset build failed." }

py train_ml_model_v12_semantic_v1.py `
  --dataset ml_training_dataset_v12_semantic_v1.csv `
  --outdir training_output
if ($LASTEXITCODE -ne 0) { throw "Model training failed." }

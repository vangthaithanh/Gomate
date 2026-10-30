# GoMate semantic-v1 training bundle

Start with `GOMATE_AI_ML_SEMANTIC_V1_TRAINING_GUIDE.md`.

Files:

- `ml_training_dataset_v11.csv`: unchanged v11 input used for this build.
- `semantic_v1/`: official frozen Backend/Data release, copied without edits.
- `build_ml_dataset_v12_semantic_v1.py`: validated v11-to-v12 join by `external_id`.
- `train_ml_model_v12_semantic_v1.py`: compares v11 Random Forest features with semantic tag/mask features.
- `semantic_content_score_v1.py`: survey-driven, uncertainty-aware cold-start scoring.
- `ml_training_dataset_v12_semantic_v1.csv`: generated training dataset.
- `training_output/`: trained model bundle, test scores and metric report.

The v11 data has no survey answers joined to `query_id`. The supervised ranker therefore learns candidate relevance from historic trip labels and candidate features; it does not claim to have learned each survey user's taste. The separate content scorer consumes actual Screen 1–2 choices at runtime.

The included training run selected `legacy_v11_ranker` by Validation NDCG@5. The semantic candidate-feature branch is retained for comparison, but is not the selected model because its Validation NDCG@5 was lower.

Run `build_ml_dataset_v12_semantic_v1.py` before training if the input CSV or semantic package is replaced. Never edit the copied `semantic_v1/` contract files locally.

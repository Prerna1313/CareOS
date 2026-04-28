# CareOS Fall Model Service

Cloud Run prediction service for the trained CareOS fall detection model.

## What it does

- downloads `best_model.pt`, `label_map.json`, and `metrics.json`
- loads the trained `r3d_18` fall classifier
- accepts backend requests with a `gcsUri`
- returns `riskLevel`, `confidence`, `summary`, and `evidenceNotes`

## Required environment variable

- `FALL_MODEL_ARTIFACTS_URI=gs://.../vertex-fall-model-artifacts/<training-job>`

## Deploy from Cloud Shell

```bash
cd ~/CareOS
chmod +x fall_model_service/deploy_cloud_run.sh
ARTIFACTS_URI=gs://careos-sanctuary-7b2a9.firebasestorage.app/vertex-fall-model-artifacts/careos-fall-train-20260428-113000 \
./fall_model_service/deploy_cloud_run.sh
```

## Allow the backend to call it

If the backend runs as `careos-backend-859@careos-sanctuary-7b2a9.iam.gserviceaccount.com`,
grant that service account invoke access:

```bash
gcloud run services add-iam-policy-binding careos-fall-model-service \
  --region us-central1 \
  --member serviceAccount:careos-backend-859@careos-sanctuary-7b2a9.iam.gserviceaccount.com \
  --role roles/run.invoker
```

## Point the backend at the model

```bash
gcloud run services update careos-backend \
  --region us-central1 \
  --set-env-vars VERTEX_FALL_PREDICT_URL=https://careos-fall-model-service-<suffix>-uc.a.run.app/predict
```

Replace the Cloud Run URL with the deployed service URL returned by `gcloud run deploy`.

## Health check

```bash
curl https://careos-fall-model-service-<suffix>-uc.a.run.app/health
```

## Prediction contract

The service expects:

```json
{
  "instances": [
    {
      "patientId": "patient_demo",
      "clipId": "clip_123",
      "gcsUri": "gs://bucket/path/clip.mp4",
      "triggerReason": "auto_possible_fall",
      "movementSignals": {
        "riskLevel": "high"
      }
    }
  ]
}
```

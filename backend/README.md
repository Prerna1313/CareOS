# CareOS Backend

Cloud Run backend for the advanced CareOS Layer B pipeline.

## What it handles

- `POST /api/speech/transcribe`
  - Upload a short patient audio file
  - Run `Cloud Speech-to-Text`
  - Return transcript plus structured speech-risk hints

- `POST /api/video/analyze`
  - Upload a short observation clip
  - Store it in your Firebase-backed Cloud Storage bucket
  - Run `Cloud Video Intelligence API`
  - Return movement analysis plus fall-risk output
  - If `VERTEX_FALL_PREDICT_URL` is set, call a custom Vertex fall model
  - Otherwise fall back to video heuristics

## Required environment variables

- `GOOGLE_CLOUD_PROJECT=careos-sanctuary-7b2a9`
- `CAREOS_STORAGE_BUCKET=careos-sanctuary-7b2a9.firebasestorage.app`
- `CAREOS_SPEECH_LANGUAGE=en-US`
- `VERTEX_FALL_PREDICT_URL=...` (optional for now)

## Local run

```powershell
cd backend
npm install
$env:GOOGLE_CLOUD_PROJECT='careos-sanctuary-7b2a9'
$env:CAREOS_STORAGE_BUCKET='careos-sanctuary-7b2a9.firebasestorage.app'
npm start
```

## Cloud Run deploy shape

```powershell
gcloud run deploy careos-backend `
  --source backend `
  --region us-central1 `
  --service-account careos-backend-859@careos-sanctuary-7b2a9.iam.gserviceaccount.com `
  --set-env-vars GOOGLE_CLOUD_PROJECT=careos-sanctuary-7b2a9,CAREOS_STORAGE_BUCKET=careos-sanctuary-7b2a9.firebasestorage.app
```

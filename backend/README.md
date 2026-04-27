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

## Vertex fall model contract

When `VERTEX_FALL_PREDICT_URL` is set, the backend sends a POST request with:

```json
{
  "instances": [
    {
      "patientId": "patient_demo",
      "clipId": "clip_123",
      "gcsUri": "gs://bucket/processing/video/patient_demo/clip_123.mp4",
      "triggerReason": "auto_possible_fall",
      "labels": ["person", "floor", "indoor"],
      "movementSignals": {
        "riskLevel": "high",
        "locationSwitches": 3,
        "shortIntervalSwitches": 2,
        "repeatedLoopCount": 1,
        "distinctVisitedLocations": 2
      }
    }
  ]
}
```

The endpoint can return either a standard Vertex-style `predictions` array or a flat JSON object. The backend understands these fields:

- `riskLevel` or `risk_label`
- `confidence` or `score`
- `summary` or `explanation`
- `evidenceNotes` or `notes`
- `modelSource` or `model`

Example response:

```json
{
  "predictions": [
    {
      "riskLevel": "high",
      "confidence": 0.91,
      "summary": "The clip suggests a fall-style posture that should be reviewed.",
      "evidenceNotes": [
        "Detected low-height posture over several frames.",
        "Movement slowed sharply after the posture change."
      ],
      "modelSource": "vertex_custom_fall_model"
    }
  ]
}
```

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
  --set-env-vars GOOGLE_CLOUD_PROJECT=careos-sanctuary-7b2a9,CAREOS_STORAGE_BUCKET=careos-sanctuary-7b2a9.firebasestorage.app,VERTEX_FALL_PREDICT_URL=https://your-vertex-endpoint
```

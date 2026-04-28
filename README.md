# CareOS

Flutter app for the CareOS cognitive-care project.

## Firebase API keys

Firebase API keys are now loaded through `--dart-define` instead of being committed in `lib/firebase_options.dart`.

Example:

```powershell
flutter run `
  --dart-define=FIREBASE_WEB_API_KEY=your_web_api_key `
  --dart-define=FIREBASE_ANDROID_API_KEY=your_android_api_key `
  --dart-define=FIREBASE_IOS_API_KEY=your_ios_api_key `
  --dart-define=GOOGLE_CLOUD_VISION_API_KEY=your_cloud_vision_api_key `
  --dart-define=CAREOS_BACKEND_BASE_URL=https://your-cloud-run-service-url
```

Use `firebase_keys.example.txt` as a local reference file and keep real keys out of git.

## Vision stack

CareOS currently uses:

- `ML Kit Face Detection` for fast on-device face/person presence
- `Cloud Vision API Object Localization` for object labels in observation snapshots
- `Gemini on Vertex AI` for richer scene descriptions, location hints, and concern summaries

## Advanced backend

The repo now includes a `backend/` Cloud Run service for the live Layer B pipeline:

- `Cloud Speech-to-Text` for server-side voice transcription
- `Cloud Video Intelligence API` for observation clip analysis
- optional `Vertex AI` fall-model call when you provide a prediction URL

See [backend/README.md](backend/README.md) for deploy steps.

## Vertex fall-model activation

The app/backend side is now ready for a custom Vertex fall model.

To make it live:

1. Deploy the Python fall-model service from `fall_model_service/`.
2. Set `VERTEX_FALL_PREDICT_URL` on the Cloud Run backend.
3. Redeploy `careos-backend`.

After that, observation clips will use:

- `Video Intelligence API` for movement/person signals
- your custom trained fall-model service for stronger fall-risk classification

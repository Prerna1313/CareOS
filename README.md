# CareOS

Flutter app for the CareOS cognitive-care project.

## Firebase API keys

Firebase API keys are now loaded through `--dart-define` instead of being committed in `lib/firebase_options.dart`.

Example:

```powershell
flutter run `
  --dart-define=FIREBASE_WEB_API_KEY=your_web_api_key `
  --dart-define=FIREBASE_ANDROID_API_KEY=your_android_api_key `
  --dart-define=FIREBASE_IOS_API_KEY=your_ios_api_key
```

Use `firebase_keys.example.txt` as a local reference file and keep real keys out of git.

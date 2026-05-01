# CareOS

CareOS is a Flutter-based cognitive care platform for patients, caregivers, and doctors. It brings together memory support, care team coordination, live monitoring, progress reporting, and AI-assisted observation tools in one connected care experience.

The project is designed around dementia and cognitive-care workflows, where patients need calm daily support and care teams need timely, shared context.

## MVP

Live MVP: [https://careos-sanctuary-7b2a9.web.app](https://careos-sanctuary-7b2a9.web.app)

The MVP includes separate patient, caregiver, and doctor experiences, with Firebase-backed authentication, patient registry records, care team linking, monitoring data, memory cues, reports, and doctor notes.

## Key Features

- Patient companion dashboard for orientation, reassurance, and daily support
- Memory cue management with caregiver-created patient memories
- Caregiver dashboard with monitoring summaries, alerts, reports, and care team tools
- Doctor dashboard with patient list, patient details, notes, and notifications
- Patient access and doctor invite flows for linking care teams
- Live monitoring screens for camera-based patient observation workflows
- Progress reports and caregiver-generated care summaries
- Firebase Authentication for role-based access
- Cloud Firestore rules and collections for secure care data sharing
- AI-assisted observation stack using on-device and cloud intelligence

## User Roles

### Patient

Patients can access a calm support experience with orientation help, memory prompts, companion interactions, camera-based support flows, and daily dashboard information.

### Caregiver

Caregivers can onboard patients, manage memory cues, review monitoring updates, create reports, manage care teams, and connect doctors to a patient record.

### Doctor

Doctors can view assigned patients, inspect patient details, review caregiver reports, add clinical notes, and track notifications related to patient care.

## Tech Stack

- Flutter and Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Hosting
- Provider for app state management
- Google ML Kit Face Detection
- Cloud Vision API
- Gemini / Vertex AI
- Cloud Run backend for advanced audio and video analysis

## Architecture Overview

CareOS is organized as a Flutter client with Firebase and Google Cloud services behind it.

```text
Flutter App
  ├─ Patient experience
  ├─ Caregiver experience
  ├─ Doctor experience
  └─ Shared models, providers, repositories, and services

Firebase
  ├─ Authentication
  ├─ Cloud Firestore
  ├─ Firebase Storage
  └─ Firebase Hosting

Google Cloud / AI
  ├─ Cloud Run backend
  ├─ Cloud Speech-to-Text
  ├─ Cloud Video Intelligence API
  ├─ Cloud Vision API
  └─ Optional Vertex AI fall-risk model
```

## Main Firestore Areas

- `app_users` stores role-based user profiles
- `patient_registry` stores patient records and care team links
- `caregiver_reports` stores caregiver progress reports under patient records
- `doctor_notes` stores doctor notes under patient records
- `patient_access_codes` supports patient/caregiver linking
- `doctor_invites` supports doctor invitation flows

## Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK
- Firebase CLI
- A Firebase project
- Google Cloud credentials for advanced AI features

### Install dependencies

```powershell
flutter pub get
```

### Run locally

Firebase API keys are loaded through `--dart-define` instead of being committed in `lib/firebase_options.dart`.

```powershell
flutter run `
  --dart-define=FIREBASE_WEB_API_KEY=your_web_api_key `
  --dart-define=FIREBASE_ANDROID_API_KEY=your_android_api_key `
  --dart-define=FIREBASE_IOS_API_KEY=your_ios_api_key `
  --dart-define=GOOGLE_CLOUD_VISION_API_KEY=your_cloud_vision_api_key `
  --dart-define=CAREOS_BACKEND_BASE_URL=https://your-cloud-run-service-url
```

Use `firebase_keys.example.txt` as a local reference file and keep real keys out of git.

## Firebase Deployment

Deploy Firestore rules:

```powershell
firebase deploy --only firestore:rules
```

Deploy Firebase Hosting:

```powershell
flutter build web
firebase deploy --only hosting
```

## Vision And AI Stack

CareOS currently uses:

- ML Kit Face Detection for fast on-device face and presence signals
- Cloud Vision API Object Localization for object labels in observation snapshots
- Gemini on Vertex AI for richer scene descriptions, location hints, and concern summaries
- Cloud Speech-to-Text for server-side voice transcription
- Cloud Video Intelligence API for observation clip analysis
- Optional custom Vertex AI fall-risk model for stronger fall classification

## Backend

The repo includes a `backend/` Cloud Run service for the advanced monitoring pipeline.

It handles:

- Audio transcription
- Structured speech-risk hints
- Observation clip upload
- Video Intelligence analysis
- Optional fall-model prediction through `VERTEX_FALL_PREDICT_URL`

See [backend/README.md](backend/README.md) for backend setup and deployment instructions.

## Fall Model Service

The app and backend are prepared for a custom Vertex fall-risk model.

To activate it:

1. Deploy the Python fall-model service from `fall_model_service/`.
2. Set `VERTEX_FALL_PREDICT_URL` on the Cloud Run backend.
3. Redeploy `careos-backend`.

After activation, observation clips can use both Video Intelligence movement signals and the custom fall-risk model output.

## Project Status

CareOS is currently in MVP stage. The core multi-role experience is implemented, including patient, caregiver, and doctor workflows, Firebase-backed data access, monitoring screens, memory support, care reports, and doctor notes.

## Upcoming Work

- Improve patient onboarding with simpler guided setup
- Add richer doctor analytics and longitudinal patient trends
- Build a more detailed alert priority system for caregivers
- Add push notifications for urgent patient events
- Expand AI monitoring with stronger fall detection and anomaly detection
- Add medication reminders and appointment tracking
- Improve accessibility for older adults and cognitively impaired patients
- Add caregiver-doctor messaging inside patient records
- Add exportable PDF reports for doctors and caregivers
- Strengthen security rules, audit logging, and role-based permissions
- Add automated tests for core patient, caregiver, and doctor flows
- Polish responsive web layouts for tablet and desktop use

## Repository Structure

```text
lib/
  models/          Shared app data models
  providers/       App state providers
  repositories/    Data access and app repositories
  screens/         Patient, caregiver, and doctor UI screens
  services/        Firebase, auth, monitoring, memory, and registry services
  widgets/         Reusable UI components

backend/           Cloud Run backend for advanced monitoring
fall_model_service/ Optional fall-risk model service
assets/            Images and app assets
web/               Flutter web shell
```

## License

This project is currently private/prototype software for the CareOS cognitive-care MVP.

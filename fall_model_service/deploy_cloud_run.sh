#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-careos-sanctuary-7b2a9}"
REGION="${REGION:-us-central1}"
SERVICE_NAME="${SERVICE_NAME:-careos-fall-model-service}"
ARTIFACTS_URI="${ARTIFACTS_URI:-gs://careos-sanctuary-7b2a9.firebasestorage.app/vertex-fall-model-artifacts/careos-fall-train-20260428-113000}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT:-}"

ARGS=(
  run deploy "${SERVICE_NAME}"
  --source fall_model_service
  --region "${REGION}"
  --project "${PROJECT_ID}"
  --memory 4Gi
  --cpu 2
  --timeout 900
  --set-env-vars "FALL_MODEL_ARTIFACTS_URI=${ARTIFACTS_URI}"
)

if [[ -n "${SERVICE_ACCOUNT}" ]]; then
  ARGS+=(--service-account "${SERVICE_ACCOUNT}")
fi

gcloud "${ARGS[@]}"

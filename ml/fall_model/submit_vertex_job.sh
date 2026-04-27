#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-us-central1}"
JOB_NAME="${JOB_NAME:-careos-fall-train-$(date +%Y%m%d-%H%M%S)}"
GCS_PREFIX="${GCS_PREFIX:-gs://careos-sanctuary-7b2a9.firebasestorage.app/vertex-fall-dataset/}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/careos_fall_outputs}"
MACHINE_TYPE="${MACHINE_TYPE:-n1-standard-8}"
ACCELERATOR_TYPE="${ACCELERATOR_TYPE:-NVIDIA_TESLA_T4}"
ACCELERATOR_COUNT="${ACCELERATOR_COUNT:-1}"
EXECUTOR_IMAGE_URI="${EXECUTOR_IMAGE_URI:-us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-4.py310:latest}"

gcloud ai custom-jobs create \
  --region="${REGION}" \
  --display-name="${JOB_NAME}" \
  --worker-pool-spec="machine-type=${MACHINE_TYPE},replica-count=1,accelerator-type=${ACCELERATOR_TYPE},accelerator-count=${ACCELERATOR_COUNT},executor-image-uri=${EXECUTOR_IMAGE_URI},local-package-path=ml,script=fall_model/vertex_job.py" \
  --args="--gcs-prefix=${GCS_PREFIX},--output-dir=${OUTPUT_DIR},--epochs=8,--batch-size=4"

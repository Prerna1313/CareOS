#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-us-central1}"
JOB_NAME="${JOB_NAME:-careos-fall-train-$(date +%Y%m%d-%H%M%S)}"
GCS_PREFIX="${GCS_PREFIX:-gs://careos-sanctuary-7b2a9.firebasestorage.app/vertex-fall-dataset/}"
OUTPUT_DIR="${OUTPUT_DIR:-gs://careos-sanctuary-7b2a9.firebasestorage.app/vertex-fall-model-artifacts/${JOB_NAME}}"
MACHINE_TYPE="${MACHINE_TYPE:-n1-standard-8}"
ACCELERATOR_TYPE="${ACCELERATOR_TYPE:-NVIDIA_TESLA_T4}"
ACCELERATOR_COUNT="${ACCELERATOR_COUNT:-1}"
EXECUTOR_IMAGE_URI="${EXECUTOR_IMAGE_URI:-us-docker.pkg.dev/vertex-ai/training/pytorch-gpu.2-4.py310:latest}"
PACKAGE_BUCKET="${PACKAGE_BUCKET:-gs://careos-sanctuary-7b2a9.firebasestorage.app/vertex-fall-model-packages}"
DIST_DIR="${DIST_DIR:-dist}"
ML_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "${ML_ROOT}/${DIST_DIR}"
rm -f "${ML_ROOT}/${DIST_DIR}"/careos_fall_model-*.tar.gz

(
  cd "${ML_ROOT}"
  python3 setup.py sdist --dist-dir "${DIST_DIR}"
)

PACKAGE_PATH="$(ls -t "${ML_ROOT}/${DIST_DIR}"/*.tar.gz | head -1)"
PACKAGE_URI="${PACKAGE_BUCKET}/$(basename "${PACKAGE_PATH}")"

gcloud storage cp "${PACKAGE_PATH}" "${PACKAGE_URI}"

gcloud ai custom-jobs create \
  --region="${REGION}" \
  --display-name="${JOB_NAME}" \
  --python-package-uris="${PACKAGE_URI}" \
  --worker-pool-spec="machine-type=${MACHINE_TYPE},replica-count=1,accelerator-type=${ACCELERATOR_TYPE},accelerator-count=${ACCELERATOR_COUNT},executor-image-uri=${EXECUTOR_IMAGE_URI},python-module=fall_model.vertex_job" \
  --args="--gcs-prefix=${GCS_PREFIX},--output-dir=${OUTPUT_DIR},--epochs=8,--batch-size=4"

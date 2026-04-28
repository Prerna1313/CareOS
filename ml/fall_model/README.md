# CareOS Fall Model

Custom Vertex AI training workspace for a video-based fall detection model.

This workspace is separate from the Flutter app so training data and ML tooling
do not bloat the patient application code.

## Goal

Train a binary video classifier with labels:

- `fall`
- `no_fall`

Then deploy it to a Vertex endpoint and point the backend env var
`VERTEX_FALL_PREDICT_URL` at the serving layer.

## Current dataset shape

The current public dataset in Cloud Storage uses a structure like:

```text
gs://careos-sanctuary-7b2a9.firebasestorage.app/vertex-fall-dataset/
  .../Subject 1/Fall/*.mp4
  .../Subject 1/ADL/*.mp4
```

This workspace maps:

- `Fall` -> `fall`
- `ADL` -> `no_fall`

## Recommended workflow

1. Build a manifest from Cloud Storage URIs.
2. Stage the selected videos locally in a Vertex training job.
3. Train a custom video classifier with PyTorch.
4. Export weights and label map.
5. Deploy the model behind a prediction route.
6. Set `VERTEX_FALL_PREDICT_URL` on `careos-backend`.

## Files

- `build_manifest.py`
  Builds a CSV manifest from Cloud Storage video URIs and performs a
  subject-aware train/val split.
- `stage_dataset.py`
  Downloads the manifest videos from GCS into local train/val folders and writes
  a staged manifest with `local_path`.
- `train.py`
  Fine-tunes a `torchvision` video model (`r3d_18`) on the staged manifest.
- `vertex_job.py`
  Vertex custom job entrypoint that builds the manifest, stages data from GCS,
  and runs training on the training VM.
- `submit_vertex_job.sh`
  Shell helper for packaging the ML workspace, uploading the source tarball to
  Cloud Storage, and launching a Vertex custom training job with a prebuilt
  PyTorch GPU container.
- `requirements.txt`
  Python dependencies for training/staging.

## 1. Build the manifest

From Cloud Shell or any machine with `gcloud`:

```bash
python3 ml/fall_model/build_manifest.py \
  --gcs-prefix gs://careos-sanctuary-7b2a9.firebasestorage.app/vertex-fall-dataset/ \
  --output ml/fall_model/manifests/fall_manifest.csv
```

This creates rows like:

```text
gcs_uri,label,split,subject,video_name
gs://.../Subject 1/Fall/01.mp4,fall,train,1,01.mp4
```

The default split is subject-aware to reduce leakage between train and
validation clips.

## 2. Stage the dataset locally

```bash
python3 ml/fall_model/stage_dataset.py \
  --manifest ml/fall_model/manifests/fall_manifest.csv \
  --output-manifest ml/fall_model/manifests/fall_manifest_staged.csv \
  --data-root /tmp/careos_fall_videos
```

This downloads videos into:

```text
/tmp/careos_fall_videos/
  train/
    fall/
    no_fall/
  val/
    fall/
    no_fall/
```

## 3. Train locally or in Vertex custom training

Local shape:

```bash
python3 ml/fall_model/train.py \
  --manifest ml/fall_model/manifests/fall_manifest_staged.csv \
  --output-dir ml/fall_model/outputs/run_001 \
  --epochs 6 \
  --batch-size 2
```

Vertex custom training shape:

```bash
./ml/fall_model/submit_vertex_job.sh
```

This uses the Vertex custom training flow with:

- `gcloud ai custom-jobs create`
- a packaged Python source tarball uploaded to Cloud Storage
- the prebuilt PyTorch GPU container

You can override defaults:

```bash
REGION=us-central1 \
GCS_PREFIX=gs://careos-sanctuary-7b2a9.firebasestorage.app/vertex-fall-dataset/ \
OUTPUT_DIR=/tmp/careos_fall_outputs \
JOB_NAME=careos-fall-train-manual \
./ml/fall_model/submit_vertex_job.sh
```

## Outputs

The trainer writes:

- `best_model.pt`
- `label_map.json`
- `metrics.json`

## Deployment note

This workspace currently trains and exports the model artifact.
You still need a serving layer that loads the exported artifacts and exposes a
prediction route. This repo now includes a lightweight Cloud Run service in
`fall_model_service/` for that purpose.

Recommended deploy flow:

```bash
cd ~/CareOS
chmod +x fall_model_service/deploy_cloud_run.sh
ARTIFACTS_URI=gs://careos-sanctuary-7b2a9.firebasestorage.app/vertex-fall-model-artifacts/careos-fall-train-20260428-113000 \
./fall_model_service/deploy_cloud_run.sh
```

Then point the backend env var at:

```text
https://<cloud-run-url>/predict
```

The service returns fields such as:

- `riskLevel`
- `confidence`
- `summary`
- `evidenceNotes`

The backend is already prepared to normalize several response formats, so the
serving layer does not need to be overly strict.

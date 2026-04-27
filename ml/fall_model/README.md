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
5. Deploy the model behind a Vertex-compatible prediction route.
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
python3 ml/fall_model/train.py \
  --manifest /path/to/fall_manifest_staged.csv \
  --output-dir /gcs/output/path \
  --epochs 10 \
  --batch-size 4
```

## Outputs

The trainer writes:

- `best_model.pt`
- `label_map.json`
- `metrics.json`

## Deployment note

This workspace currently trains and exports the model artifact.
You still need either:

1. a Vertex custom prediction routine / custom container, or
2. a thin serving wrapper that loads `best_model.pt`

to expose a prediction route that returns fields such as:

- `riskLevel`
- `confidence`
- `summary`
- `evidenceNotes`

The backend is already prepared to normalize several response formats, so the
serving layer does not need to be overly strict.

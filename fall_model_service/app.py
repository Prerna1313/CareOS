from __future__ import annotations

import os
import tempfile
from pathlib import Path
from urllib.parse import urlparse

from flask import Flask, jsonify, request
from google.cloud import storage

from inference import FallModelBundle, load_model_bundle, predict_video_file


app = Flask(__name__)
storage_client = storage.Client()
model_bundle: FallModelBundle | None = None
artifacts_dir: Path | None = None


def get_required_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"{name} must be configured.")
    return value


def ensure_artifacts_downloaded() -> Path:
    global artifacts_dir
    if artifacts_dir is not None:
        return artifacts_dir

    artifact_uri = get_required_env("FALL_MODEL_ARTIFACTS_URI")
    target_dir = Path(os.environ.get("FALL_MODEL_CACHE_DIR", "/tmp/careos_fall_model"))
    target_dir.mkdir(parents=True, exist_ok=True)

    if artifact_uri.startswith("gs://"):
        bucket_name, prefix = parse_gcs_uri(artifact_uri)
        prefix = prefix.rstrip("/")
        for artifact_name in ("best_model.pt", "label_map.json", "metrics.json"):
            blob = storage_client.bucket(bucket_name).blob(f"{prefix}/{artifact_name}")
            blob.download_to_filename(str(target_dir / artifact_name))
    else:
        source_dir = Path(artifact_uri)
        for artifact_name in ("best_model.pt", "label_map.json", "metrics.json"):
            source_path = source_dir / artifact_name
            if source_path.exists():
                (target_dir / artifact_name).write_bytes(source_path.read_bytes())

    artifacts_dir = target_dir
    return artifacts_dir


def get_model_bundle() -> FallModelBundle:
    global model_bundle
    if model_bundle is not None:
        return model_bundle

    local_artifacts_dir = ensure_artifacts_downloaded()
    model_bundle = load_model_bundle(
        model_path=local_artifacts_dir / "best_model.pt",
        label_map_path=local_artifacts_dir / "label_map.json",
        metrics_path=local_artifacts_dir / "metrics.json",
    )
    return model_bundle


def parse_gcs_uri(uri: str) -> tuple[str, str]:
    parsed = urlparse(uri)
    if parsed.scheme != "gs" or not parsed.netloc:
        raise ValueError(f"Unsupported GCS URI: {uri}")
    return parsed.netloc, parsed.path.lstrip("/")


def download_video_from_gcs(gcs_uri: str) -> Path:
    bucket_name, blob_name = parse_gcs_uri(gcs_uri)
    suffix = Path(blob_name).suffix or ".mp4"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as handle:
        local_path = Path(handle.name)
    storage_client.bucket(bucket_name).blob(blob_name).download_to_filename(str(local_path))
    return local_path


def build_prediction(result, instance: dict) -> dict:
    fall_probability = float(result.probabilities.get("fall", 0.0))
    no_fall_probability = float(result.probabilities.get("no_fall", 0.0))

    if result.predicted_label == "fall":
        risk_level = "high" if result.confidence >= 0.8 else "medium"
        summary = "The trained CareOS fall model detected a fall-like sequence in this clip."
    else:
        risk_level = "low" if result.confidence >= 0.7 else "medium"
        summary = "The trained CareOS fall model did not detect a strong fall pattern in this clip."

    evidence_notes = [
        f"Fall probability: {fall_probability:.3f}",
        f"No-fall probability: {no_fall_probability:.3f}",
    ]
    if instance.get("triggerReason"):
        evidence_notes.append(f"Trigger reason: {instance['triggerReason']}")
    if instance.get("movementSignals", {}).get("riskLevel"):
        evidence_notes.append(f"Movement risk level from backend: {instance['movementSignals']['riskLevel']}")

    return {
        "riskLevel": risk_level,
        "confidence": round(result.confidence, 4),
        "summary": summary,
        "evidenceNotes": evidence_notes,
        "modelSource": "careos_vertex_fall_model_t4",
        "predictedLabel": result.predicted_label,
        "classProbabilities": {
            key: round(value, 4) for key, value in result.probabilities.items()
        },
    }


@app.get("/health")
def health() -> tuple[dict, int]:
    try:
        bundle = get_model_bundle()
        return {
            "ok": True,
            "service": "careos-fall-model-service",
            "configured": {
                "artifactsLoaded": True,
                "labels": bundle.label_map,
            },
        }, 200
    except Exception as error:  # pragma: no cover - defensive health path
        return {
            "ok": False,
            "service": "careos-fall-model-service",
            "error": str(error),
        }, 500


@app.post("/predict")
def predict() -> tuple[dict, int]:
    payload = request.get_json(silent=True) or {}
    instances = payload.get("instances")
    if not isinstance(instances, list) or not instances:
        return {"error": "Request must contain a non-empty instances array."}, 400

    bundle = get_model_bundle()
    predictions: list[dict] = []

    for instance in instances:
        gcs_uri = (instance or {}).get("gcsUri")
        if not gcs_uri:
            return {"error": "Each instance must include gcsUri."}, 400

        local_path = download_video_from_gcs(gcs_uri)
        try:
            result = predict_video_file(bundle, local_path)
        finally:
            local_path.unlink(missing_ok=True)

        predictions.append(build_prediction(result, instance))

    return {"predictions": predictions}, 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    app.run(host="0.0.0.0", port=port)

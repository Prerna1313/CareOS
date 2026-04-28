from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from google.cloud import storage


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Vertex custom training entrypoint for the CareOS fall model.",
    )
    parser.add_argument("--gcs-prefix", required=True, help="Cloud Storage prefix with fall videos.")
    parser.add_argument(
        "--work-dir",
        default="/tmp/careos_fall_training",
        help="Local working directory on the Vertex training VM.",
    )
    parser.add_argument(
        "--output-dir",
        required=True,
        help="Directory for model artifacts. Use a GCS-mounted path if your container exposes one, or copy artifacts later.",
    )
    parser.add_argument("--epochs", type=int, default=8)
    parser.add_argument("--batch-size", type=int, default=4)
    parser.add_argument("--clip-frames", type=int, default=16)
    parser.add_argument("--image-size", type=int, default=112)
    parser.add_argument("--limit", type=int, default=0, help="Optional row limit for quick experiments.")
    return parser.parse_args()


def run_command(command: list[str]) -> None:
    print("Running:", " ".join(command))
    subprocess.run(command, check=True)


def upload_directory_to_gcs(local_dir: Path, gcs_uri: str) -> None:
    if not gcs_uri.startswith("gs://"):
        return

    trimmed = gcs_uri[5:]
    bucket_name, _, prefix = trimmed.partition("/")
    prefix = prefix.rstrip("/")

    client = storage.Client()
    bucket = client.bucket(bucket_name)

    for path in local_dir.rglob("*"):
        if not path.is_file():
            continue
        relative = path.relative_to(local_dir).as_posix()
        blob_name = f"{prefix}/{relative}" if prefix else relative
        print(f"Uploading {path} -> gs://{bucket_name}/{blob_name}")
        bucket.blob(blob_name).upload_from_filename(str(path))


def main() -> None:
    args = parse_args()
    package_root = Path(__file__).resolve().parent
    work_dir = Path(args.work_dir)
    manifest_dir = work_dir / "manifests"
    manifest_dir.mkdir(parents=True, exist_ok=True)

    manifest_path = manifest_dir / "fall_manifest.csv"
    staged_manifest_path = manifest_dir / "fall_manifest_staged.csv"
    data_root = work_dir / "staged_videos"
    artifact_dir = work_dir / "artifacts"
    artifact_dir.mkdir(parents=True, exist_ok=True)

    build_manifest_script = package_root / "build_manifest.py"
    stage_dataset_script = package_root / "stage_dataset.py"
    train_script = package_root / "train.py"

    run_command(
        [
            sys.executable,
            str(build_manifest_script),
            "--gcs-prefix",
            args.gcs_prefix,
            "--output",
            str(manifest_path),
        ]
    )

    stage_command = [
        sys.executable,
        str(stage_dataset_script),
        "--manifest",
        str(manifest_path),
        "--output-manifest",
        str(staged_manifest_path),
        "--data-root",
        str(data_root),
    ]
    if args.limit:
        stage_command.extend(["--limit", str(args.limit)])
    run_command(stage_command)

    run_command(
        [
            sys.executable,
            str(train_script),
            "--manifest",
            str(staged_manifest_path),
            "--output-dir",
            str(artifact_dir),
            "--epochs",
            str(args.epochs),
            "--batch-size",
            str(args.batch_size),
            "--clip-frames",
            str(args.clip_frames),
            "--image-size",
            str(args.image_size),
        ]
    )

    if args.output_dir.startswith("gs://"):
        upload_directory_to_gcs(artifact_dir, args.output_dir)
    else:
        output_dir = Path(args.output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        for artifact in artifact_dir.iterdir():
            target = output_dir / artifact.name
            artifact.replace(target)


if __name__ == "__main__":
    main()

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


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


def main() -> None:
    args = parse_args()
    repo_root = Path(__file__).resolve().parents[2]
    work_dir = Path(args.work_dir)
    manifest_dir = work_dir / "manifests"
    manifest_dir.mkdir(parents=True, exist_ok=True)

    manifest_path = manifest_dir / "fall_manifest.csv"
    staged_manifest_path = manifest_dir / "fall_manifest_staged.csv"
    data_root = work_dir / "staged_videos"

    build_manifest_script = repo_root / "ml" / "fall_model" / "build_manifest.py"
    stage_dataset_script = repo_root / "ml" / "fall_model" / "stage_dataset.py"
    train_script = repo_root / "ml" / "fall_model" / "train.py"

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
            args.output_dir,
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


if __name__ == "__main__":
    main()

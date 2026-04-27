from __future__ import annotations

import argparse
import csv
from pathlib import Path

from google.cloud import storage


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download fall videos from GCS into a local train/val directory.",
    )
    parser.add_argument("--manifest", required=True, help="CSV manifest created by build_manifest.py")
    parser.add_argument("--data-root", required=True, help="Local root for downloaded videos.")
    parser.add_argument("--output-manifest", required=True, help="CSV path to write with local_path included.")
    parser.add_argument(
        "--limit",
        type=int,
        default=0,
        help="Optional maximum number of rows to stage for quick experiments.",
    )
    return parser.parse_args()


def split_gcs_uri(uri: str) -> tuple[str, str]:
    if not uri.startswith("gs://"):
        raise ValueError(f"Expected gs:// URI, got: {uri}")
    remainder = uri[5:]
    bucket_name, blob_name = remainder.split("/", 1)
    return bucket_name, blob_name


def main() -> None:
    args = parse_args()
    data_root = Path(args.data_root)
    data_root.mkdir(parents=True, exist_ok=True)
    output_manifest = Path(args.output_manifest)
    output_manifest.parent.mkdir(parents=True, exist_ok=True)

    client = storage.Client()
    staged_rows: list[dict[str, str]] = []

    with open(args.manifest, newline="", encoding="utf-8") as source:
        reader = csv.DictReader(source)
        for index, row in enumerate(reader):
            if args.limit and index >= args.limit:
                break
            bucket_name, blob_name = split_gcs_uri(row["gcs_uri"])
            bucket = client.bucket(bucket_name)
            blob = bucket.blob(blob_name)

            split_dir = data_root / row["split"] / row["label"]
            split_dir.mkdir(parents=True, exist_ok=True)
            local_name = f"subject_{row['subject']}_{row['video_name']}"
            local_path = split_dir / local_name

            if not local_path.exists():
                print(f"Downloading {row['gcs_uri']} -> {local_path}")
                blob.download_to_filename(str(local_path))

            staged_row = dict(row)
            staged_row["local_path"] = str(local_path)
            staged_rows.append(staged_row)

    with output_manifest.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["gcs_uri", "label", "split", "subject", "video_name", "local_path"],
        )
        writer.writeheader()
        writer.writerows(staged_rows)

    print(f"Staged {len(staged_rows)} videos into {data_root}")
    print(f"Wrote staged manifest to {output_manifest}")


if __name__ == "__main__":
    main()

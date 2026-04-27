from __future__ import annotations

import argparse
import csv
import math
import re
import subprocess
from collections import defaultdict
from pathlib import Path


VIDEO_EXTENSIONS = (".mp4", ".avi", ".mov", ".mkv")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build a subject-aware fall/no_fall manifest from Cloud Storage video URIs.",
    )
    parser.add_argument(
        "--gcs-prefix",
        required=True,
        help="Cloud Storage prefix containing the extracted video dataset.",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="CSV path to write the manifest.",
    )
    parser.add_argument(
        "--validation-subject-ratio",
        type=float,
        default=0.2,
        help="Fraction of subjects to hold out for validation.",
    )
    return parser.parse_args()


def list_gcs_objects(prefix: str) -> list[str]:
    command = ["gcloud", "storage", "ls", "-r", f"{prefix.rstrip('/')}/**"]
    result = subprocess.run(command, capture_output=True, text=True, check=True)
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def extract_subject(uri: str) -> int | None:
    match = re.search(r"/Subject\s+(\d+)/", uri, re.IGNORECASE)
    if not match:
      return None
    return int(match.group(1))


def infer_label(uri: str) -> str | None:
    lower = uri.lower()
    if "/fall/" in lower:
        return "fall"
    if "/adl/" in lower:
        return "no_fall"
    return None


def main() -> None:
    args = parse_args()
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    all_objects = list_gcs_objects(args.gcs_prefix)
    rows: list[dict[str, str]] = []
    subjects_by_label: defaultdict[str, set[int]] = defaultdict(set)

    for uri in all_objects:
        if not uri.lower().endswith(VIDEO_EXTENSIONS):
            continue
        label = infer_label(uri)
        subject = extract_subject(uri)
        if not label or subject is None:
            continue
        subjects_by_label[label].add(subject)
        rows.append(
            {
                "gcs_uri": uri,
                "label": label,
                "subject": str(subject),
                "video_name": Path(uri).name,
            }
        )

    if not rows:
        raise SystemExit("No video rows were found under the given prefix.")

    validation_subjects: set[int] = set()
    for label, subjects in subjects_by_label.items():
        ordered = sorted(subjects)
        holdout_count = max(1, math.ceil(len(ordered) * args.validation_subject_ratio))
        validation_subjects.update(ordered[-holdout_count:])
        print(
            f"{label}: {len(ordered)} subject(s), holding out {ordered[-holdout_count:]} for validation",
        )

    for row in rows:
        row["split"] = "val" if int(row["subject"]) in validation_subjects else "train"

    rows.sort(key=lambda item: (item["split"], item["label"], int(item["subject"]), item["video_name"]))

    with output_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["gcs_uri", "label", "split", "subject", "video_name"],
        )
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {len(rows)} rows to {output_path}")


if __name__ == "__main__":
    main()

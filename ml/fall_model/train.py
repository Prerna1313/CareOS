from __future__ import annotations

import argparse
import csv
import json
from dataclasses import dataclass
from pathlib import Path

import cv2
import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset
import torch.nn.functional as F
from torchvision.models.video import R3D_18_Weights, r3d_18


@dataclass
class ManifestRow:
    local_path: str
    label: str
    split: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train a binary fall/no_fall video classifier.")
    parser.add_argument("--manifest", required=True, help="CSV manifest with local_path column.")
    parser.add_argument("--output-dir", required=True, help="Directory for model artifacts.")
    parser.add_argument("--epochs", type=int, default=6)
    parser.add_argument("--batch-size", type=int, default=2)
    parser.add_argument("--learning-rate", type=float, default=1e-4)
    parser.add_argument("--clip-frames", type=int, default=16)
    parser.add_argument("--image-size", type=int, default=112)
    parser.add_argument("--num-workers", type=int, default=0)
    return parser.parse_args()


def load_manifest(path: str) -> tuple[list[ManifestRow], list[ManifestRow]]:
    train_rows: list[ManifestRow] = []
    val_rows: list[ManifestRow] = []
    with open(path, newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            item = ManifestRow(
                local_path=row["local_path"],
                label=row["label"],
                split=row["split"],
            )
            if item.split == "val":
                val_rows.append(item)
            else:
                train_rows.append(item)
    if not train_rows or not val_rows:
        raise ValueError("Manifest must contain both train and val rows.")
    return train_rows, val_rows


class FallVideoDataset(Dataset):
    def __init__(
        self,
        rows: list[ManifestRow],
        label_to_index: dict[str, int],
        clip_frames: int,
        image_size: int,
    ) -> None:
        self.rows = rows
        self.label_to_index = label_to_index
        self.clip_frames = clip_frames
        self.image_size = image_size

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, torch.Tensor]:
        row = self.rows[index]
        video = self._load_video_tensor(row.local_path)
        if video.numel() == 0:
            raise ValueError(f"Video at {row.local_path} could not be decoded.")

        # T, H, W, C -> T, C, H, W
        video = video.float() / 255.0
        video = video.permute(0, 3, 1, 2)

        frame_indices = torch.linspace(
            0,
            max(video.shape[0] - 1, 0),
            steps=self.clip_frames,
        ).long()
        sampled = video[frame_indices]
        sampled = F.interpolate(
            sampled,
            size=(self.image_size, self.image_size),
            mode="bilinear",
            align_corners=False,
        )

        # T, C, H, W -> C, T, H, W
        sampled = sampled.permute(1, 0, 2, 3).contiguous()
        sampled = (sampled - 0.45) / 0.225

        label = torch.tensor(self.label_to_index[row.label], dtype=torch.long)
        return sampled, label

    def _load_video_tensor(self, path: str) -> torch.Tensor:
        capture = cv2.VideoCapture(path)
        if not capture.isOpened():
            raise ValueError(f"Video at {path} could not be opened.")

        frames: list[torch.Tensor] = []
        try:
            while True:
                success, frame = capture.read()
                if not success:
                    break
                frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                frames.append(torch.from_numpy(frame))
        finally:
            capture.release()

        if not frames:
            return torch.empty(0)

        return torch.stack(frames, dim=0)


def evaluate(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
    device: torch.device,
) -> tuple[float, float]:
    model.eval()
    total_loss = 0.0
    total = 0
    correct = 0

    with torch.no_grad():
        for videos, labels in loader:
            videos = videos.to(device)
            labels = labels.to(device)
            logits = model(videos)
            loss = criterion(logits, labels)
            total_loss += loss.item() * labels.size(0)
            predictions = logits.argmax(dim=1)
            total += labels.size(0)
            correct += (predictions == labels).sum().item()

    return total_loss / total, correct / total


def main() -> None:
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    train_rows, val_rows = load_manifest(args.manifest)
    label_to_index = {"fall": 1, "no_fall": 0}
    index_to_label = {value: key for key, value in label_to_index.items()}

    train_dataset = FallVideoDataset(
        train_rows,
        label_to_index=label_to_index,
        clip_frames=args.clip_frames,
        image_size=args.image_size,
    )
    val_dataset = FallVideoDataset(
        val_rows,
        label_to_index=label_to_index,
        clip_frames=args.clip_frames,
        image_size=args.image_size,
    )

    train_loader = DataLoader(
        train_dataset,
        batch_size=args.batch_size,
        shuffle=True,
        num_workers=args.num_workers,
    )
    val_loader = DataLoader(
        val_dataset,
        batch_size=args.batch_size,
        shuffle=False,
        num_workers=args.num_workers,
    )

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    weights = R3D_18_Weights.DEFAULT
    model = r3d_18(weights=weights)
    model.fc = nn.Linear(model.fc.in_features, 2)
    model.to(device)

    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.learning_rate)

    best_val_accuracy = 0.0
    history: list[dict[str, float]] = []

    for epoch in range(1, args.epochs + 1):
        model.train()
        running_loss = 0.0
        running_total = 0
        running_correct = 0

        for videos, labels in train_loader:
            videos = videos.to(device)
            labels = labels.to(device)
            optimizer.zero_grad()
            logits = model(videos)
            loss = criterion(logits, labels)
            loss.backward()
            optimizer.step()

            running_loss += loss.item() * labels.size(0)
            running_total += labels.size(0)
            running_correct += (logits.argmax(dim=1) == labels).sum().item()

        train_loss = running_loss / running_total
        train_accuracy = running_correct / running_total
        val_loss, val_accuracy = evaluate(model, val_loader, criterion, device)

        epoch_metrics = {
            "epoch": epoch,
            "train_loss": train_loss,
            "train_accuracy": train_accuracy,
            "val_loss": val_loss,
            "val_accuracy": val_accuracy,
        }
        history.append(epoch_metrics)
        print(epoch_metrics)

        if val_accuracy >= best_val_accuracy:
            best_val_accuracy = val_accuracy
            torch.save(model.state_dict(), output_dir / "best_model.pt")

    with (output_dir / "label_map.json").open("w", encoding="utf-8") as handle:
        json.dump(index_to_label, handle, indent=2)

    with (output_dir / "metrics.json").open("w", encoding="utf-8") as handle:
        json.dump(
            {
                "best_val_accuracy": best_val_accuracy,
                "history": history,
                "epochs": args.epochs,
                "clip_frames": args.clip_frames,
                "image_size": args.image_size,
            },
            handle,
            indent=2,
        )

    print(f"Saved best model to {output_dir / 'best_model.pt'}")
    print(f"Best validation accuracy: {best_val_accuracy:.4f}")


if __name__ == "__main__":
    main()

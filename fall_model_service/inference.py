from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

import cv2
import torch
import torch.nn.functional as F
from torch import nn
from torchvision.models.video import r3d_18


@dataclass
class FallPredictionResult:
    predicted_index: int
    predicted_label: str
    confidence: float
    probabilities: dict[str, float]


@dataclass
class FallModelBundle:
    model: nn.Module
    label_map: dict[int, str]
    clip_frames: int
    image_size: int
    device: torch.device


def load_model_bundle(
    model_path: str | Path,
    label_map_path: str | Path,
    metrics_path: str | Path | None = None,
) -> FallModelBundle:
    label_map = load_label_map(label_map_path)
    clip_frames = 16
    image_size = 112

    if metrics_path and Path(metrics_path).exists():
        with Path(metrics_path).open("r", encoding="utf-8") as handle:
            metrics = json.load(handle)
        clip_frames = int(metrics.get("clip_frames", clip_frames))
        image_size = int(metrics.get("image_size", image_size))

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    model = r3d_18(weights=None)
    model.fc = nn.Linear(model.fc.in_features, len(label_map))
    state_dict = torch.load(model_path, map_location=device)
    model.load_state_dict(state_dict)
    model.to(device)
    model.eval()

    return FallModelBundle(
        model=model,
        label_map=label_map,
        clip_frames=clip_frames,
        image_size=image_size,
        device=device,
    )


def load_label_map(path: str | Path) -> dict[int, str]:
    with Path(path).open("r", encoding="utf-8") as handle:
        raw_map = json.load(handle)
    return {int(index): label for index, label in raw_map.items()}


def predict_video_file(bundle: FallModelBundle, video_path: str | Path) -> FallPredictionResult:
    clip = preprocess_video_file(
        video_path=video_path,
        clip_frames=bundle.clip_frames,
        image_size=bundle.image_size,
    )
    clip = clip.unsqueeze(0).to(bundle.device)

    with torch.no_grad():
        logits = bundle.model(clip)
        probabilities_tensor = torch.softmax(logits, dim=1)[0].cpu()

    predicted_index = int(probabilities_tensor.argmax().item())
    probabilities = {
        bundle.label_map[index]: float(probabilities_tensor[index].item())
        for index in range(probabilities_tensor.shape[0])
    }

    return FallPredictionResult(
        predicted_index=predicted_index,
        predicted_label=bundle.label_map[predicted_index],
        confidence=probabilities[bundle.label_map[predicted_index]],
        probabilities=probabilities,
    )


def preprocess_video_file(video_path: str | Path, clip_frames: int, image_size: int) -> torch.Tensor:
    capture = cv2.VideoCapture(str(video_path))
    if not capture.isOpened():
        raise ValueError(f"Video at {video_path} could not be opened.")

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
        raise ValueError(f"Video at {video_path} did not contain decodable frames.")

    video = torch.stack(frames, dim=0).float() / 255.0
    video = video.permute(0, 3, 1, 2)

    frame_indices = torch.linspace(
        0,
        max(video.shape[0] - 1, 0),
        steps=clip_frames,
    ).long()
    sampled = video[frame_indices]
    sampled = F.interpolate(
        sampled,
        size=(image_size, image_size),
        mode="bilinear",
        align_corners=False,
    )
    sampled = sampled.permute(1, 0, 2, 3).contiguous()
    sampled = (sampled - 0.45) / 0.225
    return sampled

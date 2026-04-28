FROM python:3.10-slim

WORKDIR /app

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PORT=8080

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY fall_model_service/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY fall_model_service/app.py /app/app.py
COPY fall_model_service/inference.py /app/inference.py

EXPOSE 8080

CMD ["python", "app.py"]

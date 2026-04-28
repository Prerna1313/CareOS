const express = require('express');
const multer = require('multer');
const { Storage } = require('@google-cloud/storage');
const { SpeechClient } = require('@google-cloud/speech');
const videoIntelligence = require('@google-cloud/video-intelligence');
const { GoogleAuth } = require('google-auth-library');

const app = express();
const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 50 * 1024 * 1024 } });

const storage = new Storage();
const speechClient = new SpeechClient();
const videoClient = new videoIntelligence.VideoIntelligenceServiceClient();
const auth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/cloud-platform'],
});

const config = {
  projectId: process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT || '',
  bucketName: process.env.CAREOS_STORAGE_BUCKET || '',
  vertexFallPredictUrl: process.env.VERTEX_FALL_PREDICT_URL || '',
  defaultLanguageCode: process.env.CAREOS_SPEECH_LANGUAGE || 'en-US',
  port: Number(process.env.PORT || 8080),
};

app.use(express.json({ limit: '10mb' }));

app.get('/health', (_req, res) => {
  res.json({
    ok: true,
    service: 'careos-backend',
    configured: {
      projectId: Boolean(config.projectId),
      bucketName: Boolean(config.bucketName),
      vertexFallPredictUrl: Boolean(config.vertexFallPredictUrl),
    },
  });
});

app.post('/api/speech/transcribe', upload.single('audio'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Audio file is required.' });
    }
    if (!config.bucketName) {
      return res.status(500).json({ error: 'CAREOS_STORAGE_BUCKET is not configured.' });
    }

    const patientId = (req.body.patientId || 'patient_local_demo').toString();
    const source = (req.body.source || 'voiceDiary').toString();
    const languageCode = (req.body.languageCode || config.defaultLanguageCode).toString();
    const requestId = `speech_${Date.now()}`;
    const objectPath = `processing/audio/${patientId}/${requestId}_${sanitizeFileName(req.file.originalname || 'voice.m4a')}`;
    const gcsUri = await uploadBufferToStorage({
      buffer: req.file.buffer,
      contentType: req.file.mimetype || 'audio/m4a',
      objectPath,
    });

    const recognitionConfig = {
      languageCode,
      enableAutomaticPunctuation: true,
      enableWordTimeOffsets: true,
      model: 'latest_long',
      autoDecodingConfig: {},
    };

    const [recognizeResponse] = await speechClient.recognize({
      config: recognitionConfig,
      content: req.file.buffer.toString('base64'),
    });

    const alternatives = (recognizeResponse.results || [])
      .map((result) => result.alternatives?.[0])
      .filter(Boolean);
    const transcript = alternatives.map((alt) => alt.transcript || '').join(' ').trim();
    const timingAnalysis = analyzeWordTiming(alternatives);
    const confidenceAverage = alternatives.length
      ? Number(
          (
            alternatives.reduce((sum, alt) => sum + Number(alt.confidence || 0), 0) / alternatives.length
          ).toFixed(3),
        )
      : 0;

    const transcriptAnalysis = analyzeTranscript(transcript, timingAnalysis);

    return res.json({
      request: {
        requestId,
        patientId,
        createdAt: new Date().toISOString(),
        source,
        gcsUri,
        status: 'completed',
      },
      transcript,
      confidenceAverage,
      assessment: {
        assessmentId: `assessment_${Date.now()}`,
        analyzedAt: new Date().toISOString(),
        source: 'cloud_speech_to_text',
        riskLevel: transcriptAnalysis.riskLevel,
        repeatedQueries: transcriptAnalysis.repeatedQueries,
        hesitations: transcriptAnalysis.hesitations,
        distressMarkers: transcriptAnalysis.distressMarkers,
        repetitions: transcriptAnalysis.repetitions,
        estimatedPauses: transcriptAnalysis.estimatedPauses,
        summary: transcriptAnalysis.summary,
        evidenceNotes: [
          ...transcriptAnalysis.evidenceNotes,
          ...(timingAnalysis.summary ? [timingAnalysis.summary] : []),
        ],
      },
    });
  } catch (error) {
    console.error('Speech transcription failed', error);
    return res.status(500).json({
      error: 'Speech transcription failed.',
      details: String(error.message || error),
    });
  }
});

app.post('/api/video/analyze', upload.single('clip'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Video clip is required.' });
    }
    if (!config.bucketName) {
      return res.status(500).json({ error: 'CAREOS_STORAGE_BUCKET is not configured.' });
    }

    const patientId = (req.body.patientId || 'patient_local_demo').toString();
    const clipId = (req.body.clipId || `clip_${Date.now()}`).toString();
    const sourceEventId = (req.body.sourceEventId || '').toString();
    const triggerReason = (req.body.triggerReason || 'patient_observe_pipeline').toString();
    const objectPath = `processing/video/${patientId}/${clipId}_${sanitizeFileName(req.file.originalname || 'observation.mp4')}`;
    const gcsUri = await uploadBufferToStorage({
      buffer: req.file.buffer,
      contentType: req.file.mimetype || 'video/mp4',
      objectPath,
    });

    const [operation] = await videoClient.annotateVideo({
      inputUri: gcsUri,
      features: ['PERSON_DETECTION', 'LABEL_DETECTION', 'SHOT_CHANGE_DETECTION'],
      videoContext: {
        personDetectionConfig: {
          includeBoundingBoxes: true,
          includeAttributes: false,
          includePoseLandmarks: false,
        },
      },
    });

    const [result] = await operation.promise();
    const annotation = result.annotationResults?.[0] || {};
    const labels = extractVideoLabels(annotation);
    const movement = analyzeMovementSignals(annotation);
    const fallAnalysis = await analyzePossibleFall({
      gcsUri,
      patientId,
      clipId,
      triggerReason,
      labels,
      movement,
    });

    return res.json({
      request: {
        clipId,
        patientId,
        sourceEventId,
        triggerReason,
        createdAt: new Date().toISOString(),
        gcsUri,
        status: 'completed',
      },
      movementAnalysis: {
        analysisId: `movement_${Date.now()}`,
        analyzedAt: new Date().toISOString(),
        movementRiskLevel: movement.riskLevel,
        locationSwitches: movement.locationSwitches,
        shortIntervalSwitches: movement.shortIntervalSwitches,
        repeatedLoopCount: movement.repeatedLoopCount,
        distinctVisitedLocations: movement.distinctVisitedLocations,
        summary: movement.summary,
        evidenceNotes: movement.evidenceNotes,
      },
      fallAnalysis,
      labels,
    });
  } catch (error) {
    console.error('Video analysis failed', error);
    return res.status(500).json({
      error: 'Video analysis failed.',
      details: String(error.message || error),
    });
  }
});

app.listen(config.port, () => {
  console.log(`CareOS backend listening on port ${config.port}`);
});

async function uploadBufferToStorage({ buffer, contentType, objectPath }) {
  const bucket = storage.bucket(config.bucketName);
  const file = bucket.file(objectPath);
  await file.save(buffer, {
    resumable: false,
    metadata: { contentType },
  });
  return `gs://${config.bucketName}/${objectPath}`;
}

function sanitizeFileName(input) {
  return input.replace(/[^a-zA-Z0-9._-]/g, '_');
}

function analyzeTranscript(transcript, timingAnalysis = null) {
  const words = tokenize(transcript);
  const hesitations = countMarkers(words, ['um', 'uh', 'hmm', 'maybe', 'wait', 'sorry', 'forgot']);
  const distressMarkers = countMarkers(words, ['help', 'lost', 'scared', 'confused', 'anxious', 'emergency']);
  const repetitions = countImmediateRepetitions(words);
  const estimatedPauses = timingAnalysis?.estimatedPauses ?? estimatePauses(transcript, words.length);
  const repeatedQueries = /where\s+is|who\s+is|what\s+should\s+i\s+do|am\s+i\s+at\s+home/i.test(transcript) ? 1 : 0;

  let riskLevel = 'low';
  if (distressMarkers >= 2 || repeatedQueries >= 1) {
    riskLevel = 'high';
  } else if (
    hesitations >= 2 ||
    repetitions >= 2 ||
    estimatedPauses >= 3 ||
    (timingAnalysis?.longPauseCount || 0) >= 2
  ) {
    riskLevel = 'medium';
  }

  const evidenceNotes = [];
  if (repeatedQueries) evidenceNotes.push('Repeated query pattern detected.');
  if (hesitations) evidenceNotes.push(`Detected ${hesitations} hesitation marker(s).`);
  if (distressMarkers) evidenceNotes.push(`Detected ${distressMarkers} distress marker(s).`);
  if (repetitions) evidenceNotes.push(`Detected ${repetitions} immediate repetition(s).`);
  if (estimatedPauses) evidenceNotes.push(`Estimated ${estimatedPauses} pause marker(s).`);
  if (timingAnalysis?.longPauseCount) {
    evidenceNotes.push(`Detected ${timingAnalysis.longPauseCount} longer pause gap(s) from word timing.`);
  }

  return {
    riskLevel,
    repeatedQueries,
    hesitations,
    distressMarkers,
    repetitions,
    estimatedPauses,
    summary: evidenceNotes.length
      ? `Speech analysis suggests ${riskLevel} support need.`
      : 'Speech analysis looks steady.',
    evidenceNotes,
  };
}

function analyzeWordTiming(alternatives) {
  const timedWords = alternatives.flatMap((alt) => alt.words || []);
  if (!timedWords.length) {
    return {
      estimatedPauses: 0,
      longPauseCount: 0,
      maxPauseSeconds: 0,
      summary: '',
    };
  }

  let estimatedPauses = 0;
  let longPauseCount = 0;
  let maxPauseSeconds = 0;
  for (let index = 1; index < timedWords.length; index += 1) {
    const previousEnd = durationToSeconds(timedWords[index - 1].endTime);
    const currentStart = durationToSeconds(timedWords[index].startTime);
    const gapSeconds = Math.max(0, currentStart - previousEnd);
    if (gapSeconds >= 0.6) {
      estimatedPauses += 1;
    }
    if (gapSeconds >= 1.4) {
      longPauseCount += 1;
    }
    if (gapSeconds > maxPauseSeconds) {
      maxPauseSeconds = gapSeconds;
    }
  }

  const roundedMaxPause = Number(maxPauseSeconds.toFixed(2));
  return {
    estimatedPauses,
    longPauseCount,
    maxPauseSeconds: roundedMaxPause,
    summary:
      estimatedPauses > 0
        ? `Word timing found ${estimatedPauses} pause gap(s); longest gap ${roundedMaxPause}s.`
        : 'Word timing looked steady.',
  };
}

function durationToSeconds(duration) {
  if (!duration) return 0;
  const seconds = Number(duration.seconds || 0);
  const nanos = Number(duration.nanos || 0) / 1e9;
  return seconds + nanos;
}

function tokenize(transcript) {
  return transcript
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(Boolean);
}

function countMarkers(words, markers) {
  return words.filter((word) => markers.includes(word)).length;
}

function countImmediateRepetitions(words) {
  let count = 0;
  for (let index = 1; index < words.length; index += 1) {
    if (words[index] === words[index - 1]) {
      count += 1;
    }
  }
  return count;
}

function estimatePauses(transcript, wordCount) {
  const punctuation = (transcript.match(/(\.\.\.|,|\.|\?)/g) || []).length;
  const sparseSpeech = wordCount > 0 && transcript.length / wordCount > 8 ? 1 : 0;
  return punctuation + sparseSpeech;
}

function extractVideoLabels(annotation) {
  const segmentLabels = annotation.segmentLabelAnnotations || [];
  return [...new Set(segmentLabels.map((item) => item.entity?.description).filter(Boolean))];
}

function analyzeMovementSignals(annotation) {
  const personAnnotations = annotation.personDetectionAnnotations || [];
  const shotAnnotations = annotation.shotAnnotations || [];
  const tracks = personAnnotations.flatMap((person) => person.tracks || []);
  const timestampOffsets = tracks
    .map((track) => Number(track.segment?.startTimeOffset?.seconds || 0))
    .sort((a, b) => a - b);

  let shortIntervalSwitches = 0;
  for (let index = 1; index < timestampOffsets.length; index += 1) {
    if (timestampOffsets[index] - timestampOffsets[index - 1] <= 12) {
      shortIntervalSwitches += 1;
    }
  }

  const locationSwitches = Math.max(shotAnnotations.length - 1, 0);
  const repeatedLoopCount = locationSwitches >= 4 && shortIntervalSwitches >= 2 ? 1 : 0;
  const distinctVisitedLocations = Math.max(Math.min(shotAnnotations.length, 6), 1);

  let riskLevel = 'low';
  if (shortIntervalSwitches >= 3 || repeatedLoopCount > 0) {
    riskLevel = 'high';
  } else if (locationSwitches >= 2 || personAnnotations.length > 1) {
    riskLevel = 'medium';
  }

  const evidenceNotes = [
    `Detected ${personAnnotations.length} person track group(s).`,
    `Detected ${shotAnnotations.length} scene segment(s).`,
  ];
  if (shortIntervalSwitches) {
    evidenceNotes.push(`Detected ${shortIntervalSwitches} short-interval movement switch(es).`);
  }
  if (repeatedLoopCount) {
    evidenceNotes.push('Repeated movement loop heuristic triggered.');
  }

  return {
    riskLevel,
    locationSwitches,
    shortIntervalSwitches,
    repeatedLoopCount,
    distinctVisitedLocations,
    summary:
      riskLevel === 'high'
        ? 'Movement patterns suggest attention may be needed.'
        : riskLevel === 'medium'
          ? 'Movement patterns show some recent activity changes.'
          : 'Movement patterns look steady.',
    evidenceNotes,
  };
}

async function analyzePossibleFall({ gcsUri, patientId, clipId, triggerReason, labels, movement }) {
  const heuristic = buildHeuristicFallAnalysis({ clipId, labels, movement, triggerReason });
  if (!config.vertexFallPredictUrl) {
    return heuristic;
  }

  try {
    const client = await auth.getClient();
    const tokenResponse = await client.getAccessToken();
    const response = await fetch(config.vertexFallPredictUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${tokenResponse.token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        instances: [
          {
            patientId,
            clipId,
            gcsUri,
            triggerReason,
            labels,
            movementSignals: movement,
          },
        ],
      }),
    });

    if (!response.ok) {
      throw new Error(`Vertex call failed with ${response.status}`);
    }

    const payload = await response.json();
    const prediction = normalizeVertexPrediction(payload);
    return {
      analysisId: `fall_${Date.now()}`,
      clipId,
      analyzedAt: new Date().toISOString(),
      riskLevel: prediction.riskLevel || heuristic.riskLevel,
      confidence: Number(prediction.confidence || heuristic.confidence || 0),
      modelSource: prediction.modelSource || 'vertex_custom_fall_model',
      summary: prediction.summary || heuristic.summary,
      evidenceNotes: Array.isArray(prediction.evidenceNotes) && prediction.evidenceNotes.length
        ? prediction.evidenceNotes
        : heuristic.evidenceNotes,
    };
  } catch (error) {
    console.error('Vertex fall model unavailable, using heuristic fallback', error);
    return heuristic;
  }
}

function normalizeVertexPrediction(payload) {
  const rawPrediction =
    payload?.predictions?.[0] ||
    payload?.prediction ||
    payload?.result ||
    payload ||
    {};

  return {
    riskLevel:
      rawPrediction.riskLevel ||
      rawPrediction.risk_label ||
      rawPrediction.label ||
      rawPrediction.className ||
      '',
    confidence:
      rawPrediction.confidence ??
      rawPrediction.score ??
      rawPrediction.probability ??
      0,
    summary:
      rawPrediction.summary ||
      rawPrediction.explanation ||
      rawPrediction.description ||
      '',
    evidenceNotes:
      rawPrediction.evidenceNotes ||
      rawPrediction.evidence ||
      rawPrediction.notes ||
      [],
    modelSource:
      rawPrediction.modelSource ||
      rawPrediction.model ||
      rawPrediction.endpoint ||
      'vertex_custom_fall_model',
  };
}

function buildHeuristicFallAnalysis({ clipId, labels, movement, triggerReason }) {
  const lowerLabels = labels.map((label) => label.toLowerCase());
  const riskyLabels = ['floor', 'lying', 'person', 'furniture', 'indoor', 'corridor'].filter((label) =>
    lowerLabels.includes(label),
  );

  let riskLevel = 'low';
  let confidence = 0.52;

  if (movement.riskLevel === 'high' || /fall|collapse|floor|slump/i.test(triggerReason) || riskyLabels.includes('lying')) {
    riskLevel = 'high';
    confidence = 0.79;
  } else if (movement.riskLevel === 'medium' || riskyLabels.length >= 2) {
    riskLevel = 'medium';
    confidence = 0.65;
  }

  return {
    analysisId: `fall_${Date.now()}`,
    clipId,
    analyzedAt: new Date().toISOString(),
    riskLevel,
    confidence,
    modelSource: 'video_intelligence_plus_heuristics',
    summary:
      riskLevel === 'high'
        ? 'Video cues suggest a possible fall-style event that should be reviewed.'
        : riskLevel === 'medium'
          ? 'Video cues suggest a safety review may help.'
          : 'No strong fall pattern was detected in this clip.',
    evidenceNotes: [
      `Trigger reason: ${triggerReason}.`,
      `Movement risk level: ${movement.riskLevel}.`,
      `Detected labels: ${labels.join(', ') || 'none'}.`,
    ],
  };
}

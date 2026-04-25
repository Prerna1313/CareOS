import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum MemoryType { person, place, event }

enum UploadStatus { localOnly, uploading, uploaded, failed }

class MemoryItem {
  final String id;
  final String patientId;
  final MemoryType type;
  final String name;
  final String? note;
  final String? localImagePath;
  final String? remoteImageUrl;
  final UploadStatus uploadStatus;
  final DateTime createdAt;
  final DateTime? lastViewedAt;
  final String? voiceNotePath;
  final List<String> tags;

  MemoryItem({
    required this.id,
    required this.patientId,
    required this.type,
    required this.name,
    this.note,
    this.localImagePath,
    this.remoteImageUrl,
    this.uploadStatus = UploadStatus.localOnly,
    required this.createdAt,
    this.lastViewedAt,
    this.voiceNotePath,
    this.tags = const [],
    this.location,
    this.summary,
    this.confidence,
  });

  final String? location;
  final String? summary;
  final double? confidence;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'type': type.index,
      'name': name,
      'note': note,
      'localImagePath': localImagePath,
      'remoteImageUrl': remoteImageUrl,
      'uploadStatus': uploadStatus.index,
      'createdAt': createdAt.toIso8601String(),
      'lastViewedAt': lastViewedAt?.toIso8601String(),
      'voiceNotePath': voiceNotePath,
      'tags': tags,
      'location': location,
      'summary': summary,
      'confidence': confidence,
    };
  }

  factory MemoryItem.fromMap(Map<dynamic, dynamic> map) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.parse(date);
      return DateTime.now();
    }

    return MemoryItem(
      id: map['id'] ?? const Uuid().v4(),
      patientId: map['patientId'] ?? '',
      type: MemoryType.values[map['type'] ?? 0],
      name: map['name'] ?? '',
      note: map['note'],
      localImagePath: map['localImagePath'] ?? map['imagePath'], // Backward compatibility
      remoteImageUrl: map['remoteImageUrl'],
      uploadStatus: UploadStatus.values[map['uploadStatus'] ?? 0],
      createdAt: parseDate(map['createdAt']),
      lastViewedAt: map['lastViewedAt'] != null ? parseDate(map['lastViewedAt']) : null,
      voiceNotePath: map['voiceNotePath'],
      tags: List<String>.from(map['tags'] ?? []),
      location: map['location'],
      summary: map['summary'],
      confidence: (map['confidence'] as num?)?.toDouble(),
    );
  }

  MemoryItem copyWith({
    String? name,
    String? note,
    MemoryType? type,
    String? localImagePath,
    String? remoteImageUrl,
    UploadStatus? uploadStatus,
    DateTime? lastViewedAt,
    String? voiceNotePath,
    List<String>? tags,
    String? location,
    String? summary,
    double? confidence,
  }) {
    return MemoryItem(
      id: id,
      patientId: patientId,
      type: type ?? this.type,
      name: name ?? this.name,
      note: note ?? this.note,
      localImagePath: localImagePath ?? this.localImagePath,
      remoteImageUrl: remoteImageUrl ?? this.remoteImageUrl,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      createdAt: createdAt,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      voiceNotePath: voiceNotePath ?? this.voiceNotePath,
      tags: tags ?? this.tags,
      location: location ?? this.location,
      summary: summary ?? this.summary,
      confidence: confidence ?? this.confidence,
    );
  }
}

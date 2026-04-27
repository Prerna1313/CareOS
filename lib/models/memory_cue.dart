enum MemoryCueType { family, place, event, medicine, routine, custom }

enum MemoryCuePriority { normal, high }

class MemoryCue {
  final String id;
  final String patientId;
  final MemoryCueType type;
  final MemoryCuePriority priority;
  final String title;
  final String? mediaUrl;
  final String? caption;
  final List<String> tags;
  final String? voiceNotePath;
  final int? voiceNoteDurationSeconds;
  final String? voiceNoteTranscription;

  const MemoryCue({
    required this.id,
    required this.patientId,
    required this.type,
    this.priority = MemoryCuePriority.normal,
    required this.title,
    this.mediaUrl,
    this.caption,
    this.tags = const [],
    this.voiceNotePath,
    this.voiceNoteDurationSeconds,
    this.voiceNoteTranscription,
  });

  factory MemoryCue.fromJson(Map<String, dynamic> json) {
    return MemoryCue(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      type: MemoryCueType.values.byName(json['type'] as String),
      priority: MemoryCuePriority.values.byName(json['priority'] as String),
      title: json['title'] as String,
      mediaUrl: json['mediaUrl'] as String?,
      caption: json['caption'] as String?,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      voiceNotePath: json['voiceNotePath'] as String?,
      voiceNoteDurationSeconds: json['voiceNoteDurationSeconds'] as int?,
      voiceNoteTranscription: json['voiceNoteTranscription'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'type': type.name,
        'priority': priority.name,
        'title': title,
        'mediaUrl': mediaUrl,
        'caption': caption,
        'tags': tags,
        'voiceNotePath': voiceNotePath,
        'voiceNoteDurationSeconds': voiceNoteDurationSeconds,
        'voiceNoteTranscription': voiceNoteTranscription,
      };

  MemoryCue copyWith({
    MemoryCueType? type,
    MemoryCuePriority? priority,
    String? title,
    String? mediaUrl,
    String? caption,
    List<String>? tags,
    String? voiceNotePath,
    int? voiceNoteDurationSeconds,
    String? voiceNoteTranscription,
  }) {
    return MemoryCue(
      id: id,
      patientId: patientId,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      caption: caption ?? this.caption,
      tags: tags ?? this.tags,
      voiceNotePath: voiceNotePath ?? this.voiceNotePath,
      voiceNoteDurationSeconds:
          voiceNoteDurationSeconds ?? this.voiceNoteDurationSeconds,
      voiceNoteTranscription:
          voiceNoteTranscription ?? this.voiceNoteTranscription,
    );
  }
}

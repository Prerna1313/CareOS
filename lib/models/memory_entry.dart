class MemoryEntry {
  final String id;
  final DateTime date;
  final String title;
  final String note;
  final String? photoPath;
  final MemoryTag tag;

  MemoryEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.note,
    this.photoPath,
    required this.tag,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'note': note,
      'photoPath': photoPath,
      'tag': tag.index,
    };
  }

  factory MemoryEntry.fromMap(Map<dynamic, dynamic> map) {
    return MemoryEntry(
      id: map['id'],
      date: DateTime.parse(map['date']),
      title: map['title'],
      note: map['note'],
      photoPath: map['photoPath'],
      tag: MemoryTag.values[map['tag'] ?? 0],
    );
  }
}

enum MemoryTag { person, place, event }

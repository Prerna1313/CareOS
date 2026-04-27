import 'package:hive_flutter/hive_flutter.dart';

import '../models/care_team_member.dart';

class CareTeamService {
  static const String _boxName = 'care_team_members';

  Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  Future<Box> _openBox() async => Hive.isBoxOpen(_boxName)
      ? Hive.box(_boxName)
      : Hive.openBox(_boxName);

  Future<void> save(CareTeamMember member) async {
    final box = await _openBox();
    await box.put(member.id, member.toJson());
  }

  Future<void> delete(String id) async {
    final box = await _openBox();
    await box.delete(id);
  }

  Future<List<CareTeamMember>> getAll(String patientId) async {
    final box = await _openBox();
    final members = box.values
        .map(
          (raw) => CareTeamMember.fromJson(Map<String, dynamic>.from(raw as Map)),
        )
        .where((member) => member.patientId == patientId)
        .toList();
    members.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return members;
  }
}

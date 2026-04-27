import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../models/care_team_member.dart';
import '../../../models/caregiver_session.dart';
import '../../../services/care_team_service.dart';
import '../../../services/firestore/firestore_caregiver_service.dart';
import '../../../theme/app_colors.dart';

class CareTeamScreen extends StatefulWidget {
  const CareTeamScreen({super.key});

  @override
  State<CareTeamScreen> createState() => _CareTeamScreenState();
}

class _CareTeamScreenState extends State<CareTeamScreen> {
  final _service = CareTeamService();
  final _firestoreService = FirestoreCaregiverService();
  final _uuid = const Uuid();
  CaregiverSession? _session;
  bool _isLoading = true;
  List<CareTeamMember> _members = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = CaregiverSessionScope.of(context);
    if (_session?.patientId == session.patientId) return;
    _session = session;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final session = _session ?? CaregiverSession.fallback();
    setState(() => _isLoading = true);
    var members = await _service.getAll(session.patientId);
    if (members.isEmpty) {
      final remote = (await _firestoreService.getAllCareTeamMembers())
          .where((member) => member.patientId == session.patientId)
          .toList();
      if (remote.isNotEmpty) {
        for (final member in remote) {
          await _service.save(member);
        }
        members = remote;
      } else {
        final seeded = _seedMembers(session);
        for (final member in seeded) {
          await _service.save(member);
          await _firestoreService.syncCareTeamMember(member);
        }
        members = seeded;
      }
    }
    if (mounted) {
      setState(() {
        _members = members;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceColor,
      appBar: AppBar(
        title: const Text('Care Team'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _members.length,
              itemBuilder: (context, index) {
                final member = _members[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryColor.withValues(alpha: 0.1),
                      child: Text(
                        member.name[0],
                        style: const TextStyle(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      member.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      [
                        member.role.displayName,
                        if (member.phone?.isNotEmpty == true) member.phone,
                        if (member.email?.isNotEmpty == true) member.email,
                      ].whereType<String>().join(' • '),
                    ),
                    trailing: member.id != (_session ?? CaregiverSession.fallback()).caregiverId
                        ? IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.errorColor,
                            ),
                            onPressed: () => _removeMember(member),
                          )
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemberDialog,
        backgroundColor: AppColors.primaryColor,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Invite Member', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  List<CareTeamMember> _seedMembers(CaregiverSession session) {
    return [
      CareTeamMember(
        id: session.caregiverId,
        patientId: session.patientId,
        name: '${session.caregiverName} (You)',
        role: CareTeamRole.primaryCaregiver,
        phone: session.emergencyPhone,
        createdAt: DateTime.now(),
      ),
      if (session.emergencyPhone?.trim().isNotEmpty == true)
        CareTeamMember(
          id: 'emergency_${session.patientId}',
          patientId: session.patientId,
          name: 'Emergency Contact',
          role: CareTeamRole.emergencyContact,
          phone: session.emergencyPhone,
          createdAt: DateTime.now(),
        ),
      CareTeamMember(
        id: 'doctor_${session.patientId}',
        patientId: session.patientId,
        name: 'Assigned Doctor',
        role: CareTeamRole.doctor,
        createdAt: DateTime.now(),
      ),
    ];
  }

  Future<void> _showAddMemberDialog() async {
    final session = _session ?? CaregiverSession.fallback();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final notesController = TextEditingController();
    var role = CareTeamRole.secondaryCaregiver;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Care Team Member',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CareTeamRole>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: CareTeamRole.values
                        .where((item) => item != CareTeamRole.primaryCaregiver)
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => role = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notes / access context',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;
                        final member = CareTeamMember(
                          id: _uuid.v4(),
                          patientId: session.patientId,
                          name: name,
                          role: role,
                          phone: phoneController.text.trim().isEmpty
                              ? null
                              : phoneController.text.trim(),
                          email: emailController.text.trim().isEmpty
                              ? null
                              : emailController.text.trim(),
                          notes: notesController.text.trim().isEmpty
                              ? null
                              : notesController.text.trim(),
                          createdAt: DateTime.now(),
                        );
                        await _service.save(member);
                        await _firestoreService.syncCareTeamMember(member);
                        if (mounted) {
                          Navigator.of(this.context).pop(true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save Member'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (saved == true) {
      await _loadMembers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Care team member added.')),
      );
    }
  }

  Future<void> _removeMember(CareTeamMember member) async {
    await _service.delete(member.id);
    await _firestoreService.deleteCareTeamMember(member.id);
    await _loadMembers();
  }
}

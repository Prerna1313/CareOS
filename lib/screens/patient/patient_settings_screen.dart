import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/patient_session_provider.dart';
import '../../theme/app_colors.dart';

class PatientSettingsScreen extends StatefulWidget {
  const PatientSettingsScreen({super.key});

  @override
  State<PatientSettingsScreen> createState() => _PatientSettingsScreenState();
}

class _PatientSettingsScreenState extends State<PatientSettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _homeController;
  late final TextEditingController _cityController;
  late final TextEditingController _caregiverController;
  late final TextEditingController _relationshipController;
  late final TextEditingController _importantItemsController;
  late bool _autoOrientationEnabled;
  late bool _voicePromptsEnabled;

  @override
  void initState() {
    super.initState();
    final profile = context.read<PatientSessionProvider>().profile;
    _nameController = TextEditingController(text: profile?.displayName ?? '');
    _homeController = TextEditingController(text: profile?.homeLabel ?? '');
    _cityController = TextEditingController(text: profile?.city ?? '');
    _caregiverController = TextEditingController(
      text: profile?.caregiverName ?? '',
    );
    _relationshipController = TextEditingController(
      text: profile?.caregiverRelationship ?? '',
    );
    _importantItemsController = TextEditingController(
      text: profile?.importantItems.join(', ') ?? '',
    );
    _autoOrientationEnabled = profile?.autoOrientationEnabled ?? true;
    _voicePromptsEnabled = profile?.voicePromptsEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _homeController.dispose();
    _cityController.dispose();
    _caregiverController.dispose();
    _relationshipController.dispose();
    _importantItemsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final importantItems = _importantItemsController.text
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

    await context.read<PatientSessionProvider>().updateProfileSettings(
      displayName: _nameController.text,
      homeLabel: _homeController.text,
      city: _cityController.text,
      caregiverName: _caregiverController.text,
      caregiverRelationship: _relationshipController.text,
      importantItems: importantItems,
      autoOrientationEnabled: _autoOrientationEnabled,
      voicePromptsEnabled: _voicePromptsEnabled,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Patient settings saved locally.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBright,
        title: Text(
          'Patient Settings',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Personalize orientation and support',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These settings stay local on this device and help CareOS speak more clearly and find important items.',
            style: textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _Field(label: 'Patient name', controller: _nameController),
          _Field(label: 'Home label', controller: _homeController),
          _Field(label: 'City / place', controller: _cityController),
          _Field(label: 'Caregiver name', controller: _caregiverController),
          _Field(
            label: 'Caregiver relationship',
            controller: _relationshipController,
          ),
          _Field(
            label: 'Important items',
            hint: 'glasses, diary, medicine',
            controller: _importantItemsController,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _autoOrientationEnabled,
            onChanged: (value) =>
                setState(() => _autoOrientationEnabled = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto orientation support'),
            subtitle: const Text(
              'Show orientation help when confusion or visual concerns are noticed.',
            ),
          ),
          SwitchListTile(
            value: _voicePromptsEnabled,
            onChanged: (value) => setState(() => _voicePromptsEnabled = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('Voice prompts'),
            subtitle: const Text(
              'Allow calm spoken orientation and reassurance prompts.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save Settings')),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final int maxLines;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: AppColors.surfaceContainerLowest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service_manager.dart';

class TherapistPortalScreen extends StatefulWidget {
  const TherapistPortalScreen({super.key});

  @override
  State<TherapistPortalScreen> createState() => _TherapistPortalScreenState();
}

class _TherapistPortalScreenState extends State<TherapistPortalScreen> {
  int? _selectedClientId;
  List<Map<String, dynamic>> _clients = [];
  bool _loadingClients = true;
  String? _clientsError;

  Map<String, dynamic>? _progressData;
  bool _loadingProgress = false;
  String? _progressError;

  final _api = ApiServiceManager();

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  Future<void> _fetchClients() async {
    setState(() {
      _loadingClients = true;
      _clientsError = null;
    });
    try {
      final data = await _api.get('/therapist/clients');
      final list = (data['data'] as List?)?.cast<Map<String, dynamic>>() ??
          (data is List ? (data as List).cast<Map<String, dynamic>>() : []);
      // Handle both wrapped and unwrapped list responses
      final raw = data.containsKey('data')
          ? (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? []
          : (data.containsKey('clients')
              ? (data['clients'] as List?)?.cast<Map<String, dynamic>>() ?? []
              : list);
      setState(() {
        _clients = raw;
        _loadingClients = false;
      });
    } catch (e) {
      setState(() {
        _clientsError = e.toString();
        _loadingClients = false;
      });
    }
  }

  Future<void> _fetchProgress(int clientId) async {
    setState(() {
      _loadingProgress = true;
      _progressError = null;
      _progressData = null;
    });
    try {
      final data = await _api.get('/therapist/clients/$clientId/progress');
      setState(() {
        _progressData = data;
        _loadingProgress = false;
      });
    } catch (e) {
      setState(() {
        _progressError = e.toString();
        _loadingProgress = false;
      });
    }
  }

  Future<void> _addClientDialog() async {
    final childIdCtrl = TextEditingController();
    final displayNameCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B69),
        title: const Text('Link Child Account',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: childIdCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Child User ID',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFAA88FF))),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: displayNameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Display Name (optional)',
                labelStyle: TextStyle(color: Colors.white70),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38)),
                focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFAA88FF))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFAA88FF)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Link'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final childId = childIdCtrl.text.trim();
    if (childId.isEmpty) return;

    try {
      await _api.post('/therapist/clients', {
        'child_user_id': childId,
        'child_display_name': displayNameCtrl.text.trim(),
      });
      _fetchClients();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _editGoalsDialog(Map<String, dynamic> client) async {
    final goals = List<String>.from(client['therapeutic_goals'] ?? []);
    final goalsCtrl =
        TextEditingController(text: goals.join('\n'));
    final notesCtrl =
        TextEditingController(text: client['notes'] ?? '');
    final nameCtrl = TextEditingController(
        text: client['child_display_name'] ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2D1B69),
        title: const Text('Edit Goals & Notes',
            style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38)),
                  focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFAA88FF))),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Therapeutic Goals (one per line)',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              TextField(
                controller: goalsCtrl,
                maxLines: 5,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'e.g. Practice emotional regulation',
                  hintStyle: TextStyle(color: Colors.white38),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFAA88FF))),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Session Notes',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              TextField(
                controller: notesCtrl,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white38)),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFAA88FF))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFAA88FF)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      final updatedGoals = goalsCtrl.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await _api.put('/therapist/clients/${client['id']}/goals', {
        'goals': updatedGoals,
        'notes': notesCtrl.text.trim(),
        'child_display_name': nameCtrl.text.trim(),
      });
      await _fetchClients();
      if (_selectedClientId == client['id']) {
        await _fetchProgress(_selectedClientId!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _exportReport(int clientId) async {
    try {
      final report = await _api.get('/therapist/clients/$clientId/report');
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1A0533),
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, sc) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.description,
                        color: Color(0xFFAA88FF)),
                    const SizedBox(width: 8),
                    Text('Progress Report',
                        style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24),
                Expanded(
                  child: SingleChildScrollView(
                    controller: sc,
                    child: Text(
                      const JsonEncoder.withIndent('  ').convert(report),
                      style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'monospace',
                          fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A0533), Color(0xFF2D1B69)],
          ),
        ),
        child: SafeArea(
          child: _selectedClientId == null
              ? _buildClientList()
              : _buildClientDetail(),
        ),
      ),
      floatingActionButton: _selectedClientId == null
          ? FloatingActionButton(
              backgroundColor: const Color(0xFFAA88FF),
              onPressed: _addClientDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildClientList() {
    return Column(
      children: [
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Therapist Portal',
              style: GoogleFonts.nunito(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        Expanded(
          child: _loadingClients
              ? const Center(child: CircularProgressIndicator())
              : _clientsError != null
                  ? _errorView(_clientsError!, _fetchClients)
                  : _clients.isEmpty
                      ? _emptyClientsView()
                      : RefreshIndicator(
                          onRefresh: _fetchClients,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _clients.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) => _TherapistClientCard(
                              client: _clients[i],
                              onTap: () {
                                setState(() =>
                                    _selectedClientId = _clients[i]['id']);
                                _fetchProgress(_clients[i]['id']);
                              },
                            ),
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildClientDetail() {
    final client = _clients.firstWhere(
      (c) => c['id'] == _selectedClientId,
      orElse: () => <String, dynamic>{},
    );
    final name = (client['child_display_name'] as String?)?.isNotEmpty == true
        ? client['child_display_name'] as String
        : client['child_user_id'] as String? ?? 'Unknown';
    final goals =
        List<String>.from(client['therapeutic_goals'] ?? []);
    final notes = client['notes'] as String? ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => setState(() => _selectedClientId = null),
          ),
          title: Text(name,
              style: GoogleFonts.nunito(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_note,
                  color: Color(0xFFAA88FF)),
              tooltip: 'Edit Goals',
              onPressed: () => _editGoalsDialog(client),
            ),
            IconButton(
              icon: const Icon(Icons.download,
                  color: Color(0xFFAA88FF)),
              tooltip: 'Export Report',
              onPressed: () =>
                  _exportReport(_selectedClientId!),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Goals
                _sectionHeader('Therapeutic Goals'),
                const SizedBox(height: 8),
                if (goals.isEmpty)
                  const Text('No goals set.',
                      style: TextStyle(color: Colors.white54))
                else
                  ...goals.map((g) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                color: Color(0xFFAA88FF), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(g,
                                    style: const TextStyle(
                                        color: Colors.white))),
                          ],
                        ),
                      )),

                const SizedBox(height: 20),

                // Notes
                if (notes.isNotEmpty) ...[
                  _sectionHeader('Notes'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(notes,
                        style: const TextStyle(
                            color: Colors.white70)),
                  ),
                  const SizedBox(height: 20),
                ],

                // Progress
                _sectionHeader('Story Activity'),
                const SizedBox(height: 8),
                _loadingProgress
                    ? const Center(
                        child: CircularProgressIndicator())
                    : _progressError != null
                        ? _errorView(_progressError!,
                            () => _fetchProgress(_selectedClientId!))
                        : _progressData == null
                            ? const SizedBox.shrink()
                            : _buildProgressSection(_progressData!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection(Map<String, dynamic> data) {
    final count = data['story_count'] as int? ?? 0;
    final types = data['story_types'] as Map<String, dynamic>? ?? {};
    final recent = (data['recent_stories'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _statChip('$count', 'Total Stories'),
            const SizedBox(width: 8),
            ...types.entries
                .take(3)
                .map((e) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _statChip(
                          '${e.value}', e.key.replaceAll('_', ' ')),
                    )),
          ],
        ),
        const SizedBox(height: 16),
        if (recent.isNotEmpty) ...[
          const Text('Recent Stories',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...recent.take(10).map((s) => _StoryTile(story: s)),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title,
        style: GoogleFonts.nunito(
            color: const Color(0xFFAA88FF),
            fontSize: 16,
            fontWeight: FontWeight.bold));
  }

  Widget _statChip(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFAA88FF).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFAA88FF).withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _emptyClientsView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline,
              color: Colors.white38, size: 64),
          const SizedBox(height: 16),
          const Text('No clients linked yet.',
              style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Tap + to add a client.',
              style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _errorView(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 12),
          Text(error,
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFAA88FF)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ─── TherapistClientCard ──────────────────────────────────────────────────────

class _TherapistClientCard extends StatelessWidget {
  final Map<String, dynamic> client;
  final VoidCallback onTap;

  const _TherapistClientCard(
      {required this.client, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name =
        (client['child_display_name'] as String?)?.isNotEmpty == true
            ? client['child_display_name'] as String
            : client['child_user_id'] as String? ?? 'Unknown';
    final goals =
        List<String>.from(client['therapeutic_goals'] ?? []);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFAA88FF).withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFFAA88FF).withOpacity(0.35)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    const Color(0xFFAA88FF).withOpacity(0.3),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    if (goals.isNotEmpty)
                      Text('${goals.length} goal${goals.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white38, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── StoryTile ────────────────────────────────────────────────────────────────

class _StoryTile extends StatelessWidget {
  final Map<String, dynamic> story;

  const _StoryTile({required this.story});

  @override
  Widget build(BuildContext context) {
    final title = story['title'] as String? ?? 'Untitled';
    final createdAt = story['created_at'] as String?;
    final date = createdAt != null
        ? DateTime.tryParse(createdAt)
        : null;
    final dateStr = date != null
        ? '${date.day}/${date.month}/${date.year}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined,
              color: Color(0xFFAA88FF), size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis)),
          if (dateStr.isNotEmpty)
            Text(dateStr,
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11)),
        ],
      ),
    );
  }
}

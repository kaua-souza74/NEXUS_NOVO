import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/nexus_repository.dart';
import 'data_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _repository = NexusRepository(Supabase.instance.client);
  int _selectedIndex = 0;

  static const _destinations = [
    (label: 'Dashboard', icon: Icons.dashboard_outlined),
    (label: 'Spaces', icon: Icons.meeting_room_outlined),
    (label: 'Devices', icon: Icons.sensors_outlined),
    (label: 'Live', icon: Icons.monitor_heart_outlined),
    (label: 'History', icon: Icons.history),
    (label: 'Alerts', icon: Icons.notifications_outlined),
    (label: 'Profile', icon: Icons.person_outline),
  ];

  String get _title => _destinations[_selectedIndex].label;

  Future<void> _signOut() => Supabase.instance.client.auth.signOut();

  Widget _page() {
    return switch (_selectedIndex) {
      0 => _dashboardPage(),
      1 => _spacesPage(),
      2 => _devicesPage(),
      3 => _livePage(),
      4 => _historyPage(),
      5 => _alertsPage(),
      _ => _profilePage(),
    };
  }

  Widget _dashboardPage() => DataPage(
        title: 'dashboard',
        future: _repository.loadDashboard,
        builder: (context, raw) {
          final data = raw as Map<String, dynamic>? ?? {};
          final hotel = data['hotel'] as Map<String, dynamic>?;
          final spaces = data['spaces'] as List<Map<String, dynamic>>? ?? [];
          final devices = data['devices'] as List<Map<String, dynamic>>? ?? [];
          final readings = data['readings'] as List<Map<String, dynamic>>? ?? [];
          final onlineCount = devices.where(_isOnline).length;
          final latest = readings.isEmpty ? null : readings.first;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(hotel?['name']?.toString() ?? 'Nenhum hotel acessível', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _metricCard(context, 'Spaces', '${spaces.length}'),
                _metricCard(context, 'Devices', '${devices.length}'),
                _metricCard(context, 'Online', '$onlineCount'),
              ]),
              const SizedBox(height: 24),
              Text('Latest reading', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(latest == null ? 'Ainda não há leituras.' : _readingLabel(latest)),
                ),
              ),
              if (hotel == null) const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('A conta autenticou, mas não há hotel visível para este usuário via RLS.'),
              ),
            ],
          );
        },
      );

  Widget _spacesPage() => DataPage(
        title: 'spaces',
        future: _repository.loadSpaces,
        builder: (context, raw) {
          final rows = raw as List<Map<String, dynamic>>? ?? [];
          if (rows.isEmpty) return const Center(child: Text('Nenhum espaço acessível.'));
          return ListView(children: rows.map((row) => ListTile(
            leading: const Icon(Icons.meeting_room_outlined),
            title: Text(row['name']?.toString() ?? 'Space'),
            subtitle: Text('Tipo: ${row['type'] ?? '—'} · Andar: ${row['floor'] ?? '—'}'),
          )).toList());
        },
      );

  Widget _devicesPage() => DataPage(
        title: 'devices',
        future: _repository.loadDevices,
        builder: (context, raw) {
          final rows = raw as List<Map<String, dynamic>>? ?? [];
          if (rows.isEmpty) return const Center(child: Text('Nenhum dispositivo acessível.'));
          return ListView(children: rows.map((row) => ListTile(
            leading: Icon(Icons.sensors_outlined, color: _isOnline(row) ? Colors.green : null),
            title: Text('${row['device_id']} · ${row['name']}'),
            subtitle: Text('Espaço: ${_relatedName(row['spaces'])} · ${_status(row)}'),
          )).toList());
        },
      );

  Widget _livePage() => DataPage(
        title: 'latest readings',
        future: () => _repository.loadReadings(limit: 25),
        builder: (context, raw) {
          final rows = raw as List<Map<String, dynamic>>? ?? [];
          final latestByType = <String, Map<String, dynamic>>{};
          for (final row in rows) {
            latestByType.putIfAbsent(row['sensor_type'].toString(), () => row);
          }
          if (latestByType.isEmpty) return const Center(child: Text('Ainda não há leituras.'));
          return ListView(children: latestByType.entries.map((entry) => ListTile(
            leading: const Icon(Icons.sensors),
            title: Text(_readingLabel(entry.value)),
            subtitle: Text('Atualizado: ${entry.value['recorded_at']}'),
          )).toList());
        },
      );

  Widget _historyPage() => DataPage(
        title: 'history',
        future: () => _repository.loadReadings(limit: 100),
        builder: (context, raw) {
          final rows = raw as List<Map<String, dynamic>>? ?? [];
          if (rows.isEmpty) return const Center(child: Text('Ainda não há leituras no histórico.'));
          return ListView(children: rows.map((row) => ListTile(
            title: Text(_readingLabel(row)),
            subtitle: Text('Dispositivo: ${row['device_id']} · ${row['recorded_at']}'),
          )).toList());
        },
      );

  Widget _alertsPage() => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Nenhum módulo de alertas foi configurado ainda.'),
        ),
      );

  Widget _profilePage() => DataPage(
        title: 'profile',
        future: () async => {
          'profile': await _repository.loadProfile(),
          'membership': await _repository.loadMembership(),
        },
        builder: (context, raw) {
          final data = raw as Map<String, dynamic>? ?? {};
          final profile = data['profile'] as Map<String, dynamic>?;
          final membership = data['membership'] as Map<String, dynamic>?;
          final user = Supabase.instance.client.auth.currentUser;
          return ListView(padding: const EdgeInsets.all(16), children: [
            ListTile(title: const Text('Email'), subtitle: Text(user?.email ?? '—')),
            ListTile(title: const Text('Nome'), subtitle: Text(profile?['full_name']?.toString() ?? '—')),
            ListTile(title: const Text('Role'), subtitle: Text(membership?['role']?.toString() ?? '—')),
          ]);
        },
      );

  Widget _metricCard(BuildContext context, String label, String value) => SizedBox(
        width: 170,
        child: Card(child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
          ]),
        )),
      );

  bool _isOnline(Map<String, dynamic> device) {
    final value = device['last_seen_at'];
    if (value is! String) return false;
    final lastSeen = DateTime.tryParse(value)?.toLocal();
    return lastSeen != null && DateTime.now().difference(lastSeen) <= const Duration(minutes: 2);
  }

  String _status(Map<String, dynamic> device) {
    final lastSeen = device['last_seen_at'];
    return lastSeen == null ? 'Offline · sem comunicação' : '${_isOnline(device) ? 'Online' : 'Offline'} · última comunicação: $lastSeen';
  }

  String _relatedName(dynamic value) {
    if (value is Map) return value['name']?.toString() ?? '—';
    if (value is List && value.isNotEmpty && value.first is Map) return value.first['name']?.toString() ?? '—';
    return '—';
  }

  String _readingLabel(Map<String, dynamic> row) {
    final type = row['sensor_type']?.toString() ?? 'Sensor';
    final value = row['value_boolean'] ?? row['value_numeric'] ?? '—';
    final unit = row['unit'] == null ? '' : ' ${row['unit']}';
    return '$type: $value$unit';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NEXUS · $_title'),
        actions: [IconButton(tooltip: 'Sair', onPressed: _signOut, icon: const Icon(Icons.logout))],
      ),
      body: Row(children: [
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          labelType: NavigationRailLabelType.all,
          destinations: _destinations.map((item) => NavigationRailDestination(
            icon: Icon(item.icon), label: Text(item.label),
          )).toList(),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _page()),
      ]),
    );
  }
}

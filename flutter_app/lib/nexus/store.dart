import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/nexus_repository.dart';

enum ViewState { normal, loading, empty, offline, error }

enum AlertLevel { critical, warning, info }

enum DemoScenario { normal, offline, heat, presence, light }

class SpaceData {
  SpaceData({
    required this.id,
    required this.name,
    required this.type,
    required this.temperature,
    required this.humidity,
    required this.light,
    required this.presence,
    this.online = true,
    this.deviceCount = 1,
    this.simulated = true,
    this.physical = false,
  });
  final String id, name, type;
  double temperature, humidity;
  int light;
  bool presence, online;
  int deviceCount;
  bool simulated, physical;
  bool databaseBacked = false;
  String? databaseId;
  DateTime lastReading = DateTime.now();
  final List<double> history = [];
  final List<SpaceEvent> events = [];
}

class SpaceEvent {
  SpaceEvent(this.message, this.kind, this.time);
  final String message, kind;
  final DateTime time;
}

class DeviceData {
  DeviceData(
    this.id,
    this.spaceId, {
    this.online = true,
    this.physical = false,
    String? name,
  }) : name = name ?? id;
  final String id;
  String name, spaceId;
  bool online;
  bool physical;
  bool databaseBacked = false;
  bool? databaseOnline;
  String? databaseId;
  DateTime lastSeen = DateTime.now();
  int messages = 1248;
}

class AlertData {
  AlertData({
    required this.id,
    required this.title,
    required this.spaceId,
    required this.deviceId,
    required this.description,
    required this.level,
    required this.detected,
    this.resolved = false,
  });
  final String id, title, spaceId, deviceId;
  String description;
  final AlertLevel level;
  DateTime detected;
  bool resolved;
}

class _SimulationTrend {
  _SimulationTrend(SpaceData space)
    : temperatureDirection = space.temperature > 27 ? -1 : 1,
      humidityDirection = space.humidity > 70 ? -1 : 1,
      lightDirection = space.light > 1023 ? -1 : 1;

  int temperatureDirection;
  int humidityDirection;
  int lightDirection;
}

/// Uma única fonte de dados para todas as telas. Sem sorteios durante render.
class NexusStore extends ChangeNotifier {
  static const _physicalDeviceId = 'ESP32-001';

  NexusStore({this.repository, bool autoStart = true}) {
    _seed();
    if (autoStart) {
      state = ViewState.loading;
      _loading = Timer(const Duration(milliseconds: 650), () {
        state = ViewState.normal;
        notifyListeners();
      });
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        advance();
        final lastAttempt = databaseAttemptedAt;
        final refreshInterval = databaseRealtimeConnected
            ? const Duration(seconds: 60)
            : const Duration(seconds: 15);
        if (repository?.client.auth.currentUser != null &&
            (lastAttempt == null ||
                DateTime.now().difference(lastAttempt) >= refreshInterval)) {
          unawaited(refreshFromDatabase());
        }
      });
    }
    if (repository?.client.auth.currentUser != null) {
      unawaited(refreshFromDatabase());
    }
  }

  final NexusRepository? repository;
  final List<SpaceData> spaces = [];
  final List<DeviceData> devices = [];
  final List<AlertData> alerts = [];
  final List<Map<String, dynamic>> databaseReadings = [];
  Timer? _timer, _loading;
  Timer? _realtimeNotifyTimer;
  final ValueNotifier<bool> reduceMotionListenable = ValueNotifier(false);
  final Map<String, _SimulationTrend> _simulationTrends = {};
  final List<DateTime> _simulatedReadingTimes = [];
  RealtimeChannel? _deviceEventsChannel;
  String? _realtimeDeviceDatabaseId;
  bool _disposed = false;
  bool _refreshingDatabase = false;
  bool _refreshQueued = false;
  DateTime? databaseSyncedAt;
  DateTime? databaseAttemptedAt;
  String? databaseError;
  bool databaseRealtimeConnected = false;
  String membershipRole = '';
  int tick = 0;
  bool paused = false, notifications = true, reduceMotion = false;
  bool showHotelViewer = true;
  String hotelName = 'Hotel Vista Real', userName = 'Kauã Oliveira';
  String userEmail = '';
  ViewState state = ViewState.normal;
  DemoScenario? scenario;
  DateTime updatedAt = DateTime.now();

  SpaceData space(String id) => spaces.firstWhere((s) => s.id == id);
  DeviceData device(String id) => devices.firstWhere((d) => d.id == id);
  List<DeviceData> devicesIn(String id) =>
      devices.where((d) => d.spaceId == id).toList();
  List<AlertData> alertsIn(String id) =>
      alerts.where((a) => a.spaceId == id && !a.resolved).toList();
  int get onlineDevices => devices.where((d) => d.online).length;
  int get databaseSpaceCount => spaces.where((s) => s.databaseBacked).length;
  int get databaseDeviceCount => devices.where((d) => d.databaseBacked).length;
  int get databaseOnlineDeviceCount =>
      devices.where((d) => d.databaseBacked && d.databaseOnline == true).length;
  int get simulatedDeviceCount => devices.where((d) => !d.physical).length;
  int get recentReadingCount {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    final stored = databaseReadings.where((row) {
      final time = DateTime.tryParse(row['recorded_at']?.toString() ?? '');
      return time != null && time.isAfter(cutoff);
    }).length;
    return stored +
        _simulatedReadingTimes.where((time) => time.isAfter(cutoff)).length;
  }

  int get activeAlerts => alerts.where((a) => !a.resolved).length;
  int get occupiedSpaces => spaces.where((s) => s.presence && s.online).length;
  double get activity => occupiedSpaces / spaces.length * 100;
  double get averageTemperature => _onlineAverage((s) => s.temperature);
  double get averageHumidity => _onlineAverage((s) => s.humidity);
  double get averageLight => _onlineAverage((s) => s.light.toDouble());
  double _onlineAverage(double Function(SpaceData) select) {
    final online = spaces.where((s) => s.online).toList();
    return online.isEmpty
        ? 0
        : online.map(select).reduce((a, b) => a + b) / online.length;
  }

  List<double> get activityHistory =>
      series('Ocupação', 'Hoje').map((v) => v / 100).toList();

  /// Histórico demonstrativo determinístico, com último ponto igual à leitura atual.
  List<double> series(String metric, String period, {String? spaceId}) {
    final target = spaceId == null ? null : space(spaceId);
    final current = metric == 'Temperatura'
        ? (target?.temperature ?? averageTemperature)
        : metric == 'Umidade'
        ? (target?.humidity ?? averageHumidity)
        : activity;
    final spread = metric == 'Temperatura'
        ? 1.2
        : metric == 'Umidade'
        ? 4.0
        : 25.0;
    final frequency = switch (period) {
      '1H' => 7.0,
      '6H' => 4.5,
      '7D' || '7 dias' => 2.8,
      '30 dias' => 1.7,
      _ => 3.8,
    };
    return List.generate(24, (i) {
      final distance = (23 - i) / 23;
      final delta = math.sin((23 - i) / frequency) * spread * distance;
      return (current + delta)
          .clamp(
            metric == 'Temperatura' ? 18 : 0,
            metric == 'Temperatura' ? 35 : 100,
          )
          .toDouble();
    });
  }

  double periodAverage(String metric, String period) {
    final points = series(metric, period);
    return points.reduce((a, b) => a + b) / points.length;
  }

  Future<void> refreshFromDatabase() async {
    final source = repository;
    if (source == null || _refreshingDatabase) return;
    _refreshingDatabase = true;
    databaseAttemptedAt = DateTime.now();
    try {
      final snapshot = await source.loadDashboard();
      final hotel = snapshot['hotel'] as Map<String, dynamic>?;
      final profile = snapshot['profile'] as Map<String, dynamic>?;
      final membership = snapshot['membership'] as Map<String, dynamic>?;
      if (hotel?['name'] != null) hotelName = hotel!['name'].toString();
      if (profile?['full_name'] != null &&
          profile!['full_name'].toString().trim().isNotEmpty) {
        userName = profile['full_name'].toString();
      } else {
        userName = source.client.auth.currentUser?.email ?? userName;
      }
      userEmail = source.client.auth.currentUser?.email ?? '';
      membershipRole = membership?['role']?.toString() ?? '';

      final databaseSpaces =
          (snapshot['spaces'] as List<Map<String, dynamic>>? ?? []).where((
            row,
          ) {
            final type = row['type']?.toString().toLowerCase();
            final name = row['name']?.toString().trim().toLowerCase();
            return type != 'test' && name != 'sala de testes';
          }).toList();
      final byDatabaseSpaceId = <String, SpaceData>{};
      for (final row in databaseSpaces) {
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        final name = row['name']?.toString() ?? 'Espaço';
        SpaceData? target;
        for (final candidate in spaces) {
          if (candidate.databaseId == id ||
              candidate.name.toLowerCase() == name.toLowerCase()) {
            target = candidate;
            break;
          }
        }
        if (target == null) {
          target = SpaceData(
            id: 'database-$id',
            name: name,
            type: _spaceType(row['type']?.toString()),
            presence: false,
            online: true,
            temperature: 22.5,
            humidity: 55,
            light: 460,
            deviceCount: 1,
            simulated: true,
          );
          spaces.add(target);
        }
        target
          ..databaseId = id
          ..databaseBacked = true
          ..physical = target.physical
          ..simulated = !target.physical;
        byDatabaseSpaceId[id] = target;
      }

      final databaseDevices =
          snapshot['devices'] as List<Map<String, dynamic>>? ?? [];
      final byDatabaseDeviceId = <String, DeviceData>{};
      for (final row in databaseDevices) {
        final databaseId = row['id']?.toString();
        final id = row['device_id']?.toString();
        final roomId = row['space_id']?.toString();
        final room = roomId == null ? null : byDatabaseSpaceId[roomId];
        if (databaseId == null ||
            id == null ||
            id == 'ESP32-00' ||
            room == null) {
          continue;
        }
        DeviceData? target;
        for (final candidate in devices) {
          if (candidate.id == id) {
            target = candidate;
            break;
          }
        }
        if (target == null) {
          target = DeviceData(id, room.id, online: false);
          devices.add(target);
        }
        final lastSeen = DateTime.tryParse(
          row['last_seen_at']?.toString() ?? '',
        );
        final databaseOnline =
            lastSeen != null &&
            DateTime.now().difference(lastSeen.toLocal()) >= Duration.zero &&
            DateTime.now().difference(lastSeen.toLocal()) <=
                const Duration(minutes: 2);
        target
          ..databaseId = databaseId
          ..databaseBacked = true
          ..physical = id == _physicalDeviceId
          ..name = row['name']?.toString() ?? id
          ..spaceId = room.id
          ..databaseOnline = databaseOnline;
        target
          ..lastSeen = lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0)
          ..online = databaseOnline;
        room
          ..physical = room.physical || target.physical
          ..simulated = !room.physical;
        byDatabaseDeviceId[databaseId] = target;
      }

      final readings =
          snapshot['readings'] as List<Map<String, dynamic>>? ?? [];
      databaseReadings
        ..clear()
        ..addAll(
          readings.where((row) => row['sensor_type']?.toString() != 'door'),
        );
      for (final device in byDatabaseDeviceId.values) {
        device.messages = readings
            .where(
              (row) =>
                  row['device_id']?.toString() == device.databaseId &&
                  row['sensor_type']?.toString() != 'door',
            )
            .length;
      }
      final latestBySpaceAndType = <String, Set<String>>{};
      final temperatureHistory = <String, List<Map<String, dynamic>>>{};
      final newestTimeBySpace = <String, DateTime>{};
      for (final row in readings) {
        final deviceId = row['device_id']?.toString();
        final device = deviceId == null ? null : byDatabaseDeviceId[deviceId];
        if (device == null) continue;
        final room = spaces.firstWhere((space) => space.id == device.spaceId);
        if (!room.databaseBacked) continue;
        final type = row['sensor_type']?.toString() ?? '';
        if (type == 'door') continue;
        final value = row['value_numeric'];
        final boolean = row['value_boolean'];
        final seenTypes = latestBySpaceAndType.putIfAbsent(room.id, () => {});
        if (!seenTypes.contains(type)) {
          switch (type) {
            case 'temperature':
              final number = _number(value);
              if (number != null) room.temperature = number;
              break;
            case 'humidity':
              final number = _number(value);
              if (number != null) room.humidity = number;
              break;
            case 'light':
              final number = _number(value);
              if (number != null) room.light = number.round();
              break;
            case 'presence':
              if (boolean is bool) room.presence = boolean;
              break;
          }
          seenTypes.add(type);
        }
        if (type == 'temperature' && value != null) {
          temperatureHistory.putIfAbsent(room.id, () => []).add(row);
        }
        final recordedAt = DateTime.tryParse(
          row['recorded_at']?.toString() ?? '',
        );
        if (recordedAt != null &&
            (newestTimeBySpace[room.id] == null ||
                recordedAt.isAfter(newestTimeBySpace[room.id]!))) {
          newestTimeBySpace[room.id] = recordedAt;
        }
      }
      for (final room in byDatabaseSpaceId.values) {
        if (!devices.any((device) => device.spaceId == room.id)) {
          devices.add(
            DeviceData(
              'SIM-ESP32-${(devices.length + 1).toString().padLeft(3, '0')}',
              room.id,
              online: true,
            ),
          );
        }
        final roomDevices = devices
            .where((device) => device.spaceId == room.id)
            .toList();
        final hasPhysicalDevice = roomDevices.any((device) => device.physical);
        room
          ..deviceCount = roomDevices.length
          ..physical = hasPhysicalDevice
          ..simulated = !hasPhysicalDevice
          ..online = hasPhysicalDevice
              ? roomDevices.any(
                  (device) => device.physical && device.databaseOnline == true,
                )
              : true;
        final latest = newestTimeBySpace[room.id];
        if (latest != null) room.lastReading = latest.toLocal();
        final history = temperatureHistory[room.id];
        if (history != null && history.isNotEmpty) {
          history.sort(
            (a, b) => DateTime.parse(
              a['recorded_at'].toString(),
            ).compareTo(DateTime.parse(b['recorded_at'].toString())),
          );
          room.history
            ..clear()
            ..addAll(
              history
                  .map((row) => _number(row['value_numeric']))
                  .whereType<double>(),
            );
        }
        room.events.clear();
        for (final row in readings) {
          final databaseDeviceId = row['device_id']?.toString();
          final device = databaseDeviceId == null
              ? null
              : byDatabaseDeviceId[databaseDeviceId];
          if (device == null ||
              device.spaceId != room.id ||
              row['sensor_type']?.toString() == 'door') {
            continue;
          }
          final recordedAt = DateTime.tryParse(
            row['recorded_at']?.toString() ?? '',
          );
          if (recordedAt == null) continue;
          final value = row['value_boolean'] ?? row['value_numeric'] ?? '—';
          room.events.add(
            SpaceEvent(
              '${_readingName(row['sensor_type'])}: $value',
              row['sensor_type']?.toString() ?? 'reading',
              recordedAt.toLocal(),
            ),
          );
        }
      }
      for (final room in byDatabaseSpaceId.values.where(
        (room) => room.physical,
      )) {
        _syncPhysicalTemperatureAlert(room);
      }
      final physicalDevice = devices
          .where(
            (device) =>
                device.id == _physicalDeviceId && device.databaseId != null,
          )
          .firstOrNull;
      _syncRealtimeSubscription(physicalDevice?.databaseId);
      databaseSyncedAt = DateTime.now();
      databaseError = null;
    } catch (error) {
      databaseError = error.toString();
    } finally {
      _refreshingDatabase = false;
      notifyListeners();
      if (_refreshQueued && !_disposed) {
        _refreshQueued = false;
        unawaited(refreshFromDatabase());
      }
    }
  }

  void _syncRealtimeSubscription(String? databaseDeviceId) {
    final source = repository;
    if (source == null || databaseDeviceId == null) return;
    if (_realtimeDeviceDatabaseId == databaseDeviceId &&
        _deviceEventsChannel != null) {
      return;
    }
    final previous = _deviceEventsChannel;
    _deviceEventsChannel = null;
    _realtimeDeviceDatabaseId = databaseDeviceId;
    if (previous != null) unawaited(source.unsubscribe(previous));
    _deviceEventsChannel = source.subscribeToDeviceEvents(
      databaseDeviceId: databaseDeviceId,
      onChange: _applyRealtimeChange,
      onRealtimeReady: (ready) {
        if (_disposed) return;
        databaseRealtimeConnected = ready;
        if (ready) {
          if (_refreshingDatabase) {
            _refreshQueued = true;
          } else {
            unawaited(refreshFromDatabase());
          }
        }
        notifyListeners();
      },
    );
  }

  void _applyRealtimeChange(PostgresChangePayload payload) {
    if (_disposed) return;
    final record = payload.newRecord;
    if (payload.table == 'sensor_readings' &&
        record['sensor_type']?.toString() == 'door') {
      return;
    }
    final device = devices
        .where(
          (item) =>
              item.databaseId == record['id'] ||
              item.databaseId == record['device_id'],
        )
        .firstOrNull;
    if (device == null) {
      _refreshQueued = true;
      if (!_refreshingDatabase) unawaited(refreshFromDatabase());
      return;
    }

    if (payload.table == 'devices') {
      final lastSeen = DateTime.tryParse(
        record['last_seen_at']?.toString() ?? '',
      );
      final age = lastSeen == null
          ? null
          : DateTime.now().difference(lastSeen.toLocal());
      final isOnline =
          age != null &&
          age >= Duration.zero &&
          age <= const Duration(minutes: 2);
      device
        ..lastSeen = lastSeen ?? device.lastSeen
        ..databaseOnline = isOnline
        ..online = isOnline;
      final room = spaces
          .where((space) => space.id == device.spaceId)
          .firstOrNull;
      if (room != null) {
        room.online = devices.any(
          (item) =>
              item.databaseBacked &&
              item.spaceId == room.id &&
              item.databaseOnline == true,
        );
      }
    } else if (payload.table == 'sensor_readings') {
      final reading = Map<String, dynamic>.from(record);
      databaseReadings.insert(0, reading);
      if (databaseReadings.length > 1000) databaseReadings.removeLast();
      device.messages++;
      final room = spaces
          .where((space) => space.id == device.spaceId)
          .firstOrNull;
      final type = record['sensor_type']?.toString() ?? '';
      final value = record['value_numeric'];
      final boolean = record['value_boolean'];
      final recordedAt = DateTime.tryParse(
        record['recorded_at']?.toString() ?? '',
      );
      if (room != null) {
        switch (type) {
          case 'temperature':
            final number = _number(value);
            if (number != null) {
              room.temperature = number;
              room.history.add(number);
              if (room.history.length > 100) room.history.removeAt(0);
              if (device.physical) _syncPhysicalTemperatureAlert(room);
            }
            break;
          case 'humidity':
            final number = _number(value);
            if (number != null) room.humidity = number;
            break;
          case 'light':
            final number = _number(value);
            if (number != null) room.light = number.round();
            break;
          case 'presence':
            if (boolean is bool) room.presence = boolean;
            break;
        }
        if (recordedAt != null) {
          room.lastReading = recordedAt.toLocal();
          final readingValue = boolean ?? value ?? '—';
          room.events.insert(
            0,
            SpaceEvent(
              '${_readingName(type)}: $readingValue',
              type,
              recordedAt.toLocal(),
            ),
          );
          if (room.events.length > 100) room.events.removeLast();
        }
      }
    }
    databaseSyncedAt = DateTime.now();
    databaseError = null;
    updatedAt = DateTime.now();
    _scheduleRealtimeNotification();
  }

  void _scheduleRealtimeNotification() {
    if (_disposed || _realtimeNotifyTimer?.isActive == true) return;
    _realtimeNotifyTimer = Timer(const Duration(milliseconds: 120), () {
      _realtimeNotifyTimer = null;
      if (!_disposed) notifyListeners();
    });
  }

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String _readingName(dynamic value) => switch (value?.toString()) {
    'temperature' => 'Temperatura',
    'humidity' => 'Umidade',
    'presence' => 'Presença',
    'light' => 'Luminosidade',
    _ => 'Leitura',
  };

  void _syncPhysicalTemperatureAlert(SpaceData room) {
    const threshold = 28.0;
    final alertId = 'high-temperature-${room.id}';
    final existing = alerts.where((alert) => alert.id == alertId).firstOrNull;
    if (room.temperature > threshold) {
      final device = devices
          .where((item) => item.physical && item.spaceId == room.id)
          .firstOrNull;
      if (device == null) return;
      _alert(
        alertId,
        'Temperatura elevada',
        room.id,
        device.id,
        'Temperatura atual: ${room.temperature.toStringAsFixed(1)} °C. Limite de alerta: acima de 28 °C.',
        AlertLevel.critical,
      );
    } else if (existing != null && !existing.resolved) {
      existing
        ..resolved = true
        ..description =
            'Temperatura normalizada: ${room.temperature.toStringAsFixed(1)} °C.';
    }
  }

  static String _spaceType(String? value) => switch (value) {
    'test' => 'Área comum',
    'pool' => 'Lazer',
    'lobby' || 'reception' => 'Recepção',
    'restaurant' => 'Restaurante',
    'corridor' => 'Circulação',
    'gym' || 'spa' => 'Bem-estar',
    'conference' => 'Eventos',
    'garden' || 'outdoor' => 'Área externa',
    'laundry' || 'kitchen' || 'storage' => 'Serviço',
    'parking' => 'Estacionamento',
    _ => 'Área comum',
  };

  void _seed() {
    spaces.addAll([
      SpaceData(
        id: 'lobby',
        name: 'Lobby',
        type: 'Área comum',
        temperature: 23.4,
        humidity: 58,
        light: 742,
        presence: true,
      ),
      SpaceData(
        id: 'parking',
        name: 'Estacionamento',
        type: 'Estacionamento',
        temperature: 22.8,
        humidity: 53,
        light: 320,
        presence: true,
      ),
      SpaceData(
        id: 'gym',
        name: 'Academia',
        type: 'Bem-estar',
        temperature: 24.8,
        humidity: 63,
        light: 650,
        presence: true,
      ),
      SpaceData(
        id: 'restaurant',
        name: 'Restaurante',
        type: 'Gastronomia',
        temperature: 24.2,
        humidity: 57,
        light: 590,
        presence: true,
      ),
      SpaceData(
        id: 'pool',
        name: 'Piscina',
        type: 'Lazer',
        temperature: 25.6,
        humidity: 66,
        light: 920,
        presence: true,
        simulated: false,
        physical: true,
      ),
      SpaceData(
        id: 'corridor',
        name: 'Corredor · 1º andar',
        type: 'Circulação',
        temperature: 23.1,
        humidity: 52,
        light: 420,
        presence: true,
      ),
      SpaceData(
        id: 'conference',
        name: 'Salão de eventos',
        type: 'Eventos',
        temperature: 28.7,
        humidity: 61,
        light: 820,
        presence: true,
      ),
      SpaceData(
        id: 'storage',
        name: 'Depósito',
        type: 'Serviço',
        temperature: 22.9,
        humidity: 49,
        light: 120,
        presence: false,
      ),
      SpaceData(
        id: 'garden',
        name: 'Jardim interno',
        type: 'Área comum',
        temperature: 24.5,
        humidity: 62,
        light: 1050,
        presence: true,
      ),
      SpaceData(
        id: 'spa',
        name: 'Spa',
        type: 'Bem-estar',
        temperature: 23.2,
        humidity: 60,
        light: 220,
        presence: true,
      ),
      SpaceData(
        id: 'laundry',
        name: 'Lavanderia',
        type: 'Serviço',
        temperature: 25.1,
        humidity: 64,
        light: 560,
        presence: true,
      ),
      SpaceData(
        id: 'kitchen',
        name: 'Cozinha',
        type: 'Serviço',
        temperature: 25.4,
        humidity: 59,
        light: 710,
        presence: true,
      ),
      SpaceData(
        id: 'outdoor',
        name: 'Área externa',
        type: 'Área externa',
        temperature: 26.1,
        humidity: 57,
        light: 980,
        presence: false,
      ),
    ]);
    final now = DateTime.now();
    var simulatedDeviceNumber = 2;
    for (var i = 0; i < spaces.length; i++) {
      final s = spaces[i];
      final deviceId = s.id == 'pool'
          ? 'ESP32-001'
          : 'SIM-ESP32-${(simulatedDeviceNumber++).toString().padLeft(3, '0')}';
      devices.add(
        DeviceData(
          deviceId,
          s.id,
          online: s.online,
          physical: deviceId == _physicalDeviceId,
          name: deviceId == _physicalDeviceId ? '001' : deviceId,
        ),
      );
      s.lastReading = s.online
          ? now
          : now.subtract(const Duration(minutes: 23));
      s.history.addAll(
        List.generate(24, (j) => s.temperature + math.sin(j / 4) * 0.6),
      );
      s.events.addAll([
        SpaceEvent(
          'Presença ${s.presence ? 'detectada' : 'não detectada'}',
          'presence',
          now.subtract(const Duration(minutes: 2)),
        ),
        SpaceEvent(
          'Temperatura: ${s.temperature.toStringAsFixed(1)} °C',
          'temperature',
          now.subtract(const Duration(minutes: 13)),
        ),
      ]);
    }
    for (final d in devices.where((d) => !d.online)) {
      d.lastSeen = now.subtract(const Duration(minutes: 23));
    }
    _alert(
      'heat-conference',
      'Temperatura elevada',
      'conference',
      devicesIn('conference').first.id,
      'A temperatura atingiu 28,7 °C. Faixa de conforto: 20–26 °C.',
      AlertLevel.critical,
    );
    for (var i = 0; i < 8; i++) {
      alerts.add(
        AlertData(
          id: 'resolved-$i',
          title: i.isEven ? 'Conexão restabelecida' : 'Temperatura normalizada',
          spaceId: spaces[i].id,
          deviceId: devices[i].id,
          description: 'A condição voltou à faixa esperada.',
          level: AlertLevel.info,
          detected: now.subtract(Duration(hours: i + 1)),
          resolved: true,
        ),
      );
    }
  }

  void _alert(
    String id,
    String title,
    String spaceId,
    String deviceId,
    String description,
    AlertLevel level,
  ) {
    final found = alerts.where((a) => a.id == id).firstOrNull;
    if (found != null) {
      if (found.resolved) found.detected = DateTime.now();
      found.description = description;
      found.resolved = false;
      return;
    }
    alerts.insert(
      0,
      AlertData(
        id: id,
        title: title,
        spaceId: spaceId,
        deviceId: deviceId,
        description: description,
        level: level,
        detected: DateTime.now(),
      ),
    );
  }

  void advance() {
    if (paused || state != ViewState.normal) return;
    tick++;
    updatedAt = DateTime.now();
    for (var i = 0; i < spaces.length; i++) {
      final s = spaces[i];
      final hasLiveDatabaseDevice = devices.any(
        (device) => device.spaceId == s.id && device.databaseBacked,
      );
      if (!s.online || s.physical || hasLiveDatabaseDevice) continue;
      final trend = _simulationTrends.putIfAbsent(
        s.id,
        () => _SimulationTrend(s),
      );
      s.temperature = _stepSimulation(
        s.temperature,
        min: 20,
        max: 27,
        step: .08,
        direction: () => trend.temperatureDirection,
        setDirection: (value) => trend.temperatureDirection = value,
      );
      s.humidity = _stepSimulation(
        s.humidity,
        min: 40,
        max: 70,
        step: .15,
        direction: () => trend.humidityDirection,
        setDirection: (value) => trend.humidityDirection = value,
      );
      s.light = _stepSimulation(
        s.light.toDouble(),
        min: 60,
        max: 1023,
        step: 5,
        direction: () => trend.lightDirection,
        setDirection: (value) => trend.lightDirection = value,
      ).round();
      s.lastReading = updatedAt;
      _simulatedReadingTimes.addAll([updatedAt, updatedAt, updatedAt]);
      s.history.add(s.temperature);
      if (s.history.length > 48) s.history.removeAt(0);
    }
    for (final d in devices.where(
      (d) => d.online && !d.physical && !d.databaseBacked,
    )) {
      d.lastSeen = updatedAt;
      d.messages += 3;
    }
    // Mudanças espaçadas e reproduzíveis; as mesmas condições alimentam todas as telas.
    if (tick % 8 == 0) {
      final s = space('lobby');
      s.presence = !s.presence;
      _event(
        s,
        'Presença ${s.presence ? 'detectada' : 'encerrada'}',
        'presence',
      );
    }
    _simulatedReadingTimes.removeWhere(
      (time) => updatedAt.difference(time) > const Duration(minutes: 5),
    );
    notifyListeners();
  }

  double _stepSimulation(
    double value, {
    required double min,
    required double max,
    required double step,
    required int Function() direction,
    required void Function(int) setDirection,
  }) {
    var nextDirection = direction();
    if (value >= max) nextDirection = -1;
    if (value <= min) nextDirection = 1;
    var next = value + step * nextDirection;
    if (next > max) {
      next = max - (next - max);
      nextDirection = -1;
    } else if (next < min) {
      next = min + (min - next);
      nextDirection = 1;
    }
    setDirection(nextDirection);
    return next;
  }

  void _event(SpaceData s, String message, String kind) {
    s.events.insert(0, SpaceEvent(message, kind, DateTime.now()));
    if (s.events.length > 16) s.events.removeLast();
  }

  void _connection(bool online) {
    final s = space('gym');
    if (s.physical) return;
    if (s.online == online) return;
    s.online = online;
    for (final d in devicesIn(s.id)) {
      d.online = online;
      if (online) d.lastSeen = DateTime.now();
    }
    if (online) {
      for (final a in alerts.where((a) => a.id == 'offline-gym')) {
        a.resolved = true;
      }
    } else {
      _alert(
        'offline-gym',
        'Dispositivo offline',
        'gym',
        devicesIn('gym').first.id,
        'A conexão MQTT foi interrompida. Última leitura preservada.',
        AlertLevel.warning,
      );
    }
    _event(
      s,
      online ? 'Conexão restabelecida' : 'Comunicação interrompida',
      'connection',
    );
  }

  void applyScenario(DemoScenario value) {
    _loading?.cancel();
    state = ViewState.normal;
    scenario = value;
    switch (value) {
      case DemoScenario.normal:
        _connection(true);
        if (!space('conference').physical) {
          space('conference').temperature = 24.1;
        }
        for (final a in alerts) {
          a.resolved = true;
        }
        break;
      case DemoScenario.offline:
        _connection(false);
        break;
      case DemoScenario.heat:
        final s = space('conference');
        if (!s.physical) {
          s.temperature = 28.7;
          _event(s, 'Temperatura acima de 26 °C', 'temperature');
          _alert(
            'heat-conference',
            'Temperatura elevada',
            s.id,
            devicesIn(s.id).first.id,
            'A temperatura atingiu 28,7 °C. Faixa de conforto: 20–26 °C.',
            AlertLevel.critical,
          );
        }
        break;
      case DemoScenario.presence:
        final s = space('parking');
        if (!s.physical) {
          s.presence = !s.presence;
          _event(
            s,
            s.presence ? 'Presença detectada' : 'Presença encerrada',
            'presence',
          );
        }
        break;
      case DemoScenario.light:
        final s = space('restaurant');
        if (!s.physical) {
          s.light = s.light > 500 ? 240 : 780;
          _event(s, 'Luminosidade: ${s.light} raw', 'light');
        }
        break;
    }
    updatedAt = DateTime.now();
    for (final s in spaces.where(
      (s) => s.online && !s.physical && !s.databaseBacked,
    )) {
      s.lastReading = updatedAt;
      s.history.add(s.temperature);
      if (s.history.length > 48) s.history.removeAt(0);
    }
    for (final d in devices.where(
      (d) => d.online && !d.physical && !d.databaseBacked,
    )) {
      d.lastSeen = updatedAt;
    }
    notifyListeners();
  }

  void resolve(String id) {
    alerts.firstWhere((a) => a.id == id).resolved = true;
    notifyListeners();
  }

  void setState(ViewState value) {
    _loading?.cancel();
    state = value;
    notifyListeners();
    if (value == ViewState.loading) {
      _loading = Timer(
        const Duration(seconds: 1),
        () => setState(ViewState.normal),
      );
    }
  }

  void setPaused(bool value) {
    paused = value;
    notifyListeners();
  }

  void updatePreferences({
    bool? notify,
    bool? motion,
    bool? showHotelViewer,
    String? hotel,
    String? user,
  }) {
    notifications = notify ?? notifications;
    reduceMotion = motion ?? reduceMotion;
    if (motion != null && reduceMotionListenable.value != reduceMotion) {
      reduceMotionListenable.value = reduceMotion;
    }
    this.showHotelViewer = showHotelViewer ?? this.showHotelViewer;
    hotelName = hotel ?? hotelName;
    userName = user ?? userName;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _loading?.cancel();
    _realtimeNotifyTimer?.cancel();
    if (_deviceEventsChannel != null && repository != null) {
      unawaited(repository!.unsubscribe(_deviceEventsChannel!));
    }
    reduceMotionListenable.dispose();
    super.dispose();
  }
}

String timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String ageLabel(DateTime date) {
  final minutes = DateTime.now().difference(date).inMinutes;
  return minutes < 1
      ? 'agora'
      : minutes < 60
      ? 'há $minutes min'
      : 'há ${minutes ~/ 60} h';
}

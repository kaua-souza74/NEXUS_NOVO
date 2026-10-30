import 'package:supabase_flutter/supabase_flutter.dart';

class NexusRepository {
  NexusRepository(this.client);

  final SupabaseClient client;

  RealtimeChannel subscribeToDeviceEvents({
    required String databaseDeviceId,
    required void Function(PostgresChangePayload payload) onChange,
    required void Function(bool ready) onRealtimeReady,
  }) {
    return client
        .channel(
          'nexus-device-$databaseDeviceId',
          opts: const RealtimeChannelConfig(replicationReady: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sensor_readings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'device_id',
            value: databaseDeviceId,
          ),
          callback: onChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'devices',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: databaseDeviceId,
          ),
          callback: onChange,
        )
        .onSystemEvents((payload) {
          if (payload is Map) {
            if (payload['status'] == 'ok') onRealtimeReady(true);
            if (payload['status'] == 'error') onRealtimeReady(false);
          }
        })
        .subscribe((status, _) {
          if (status != RealtimeSubscribeStatus.subscribed) {
            onRealtimeReady(false);
          }
        });
  }

  Future<void> unsubscribe(RealtimeChannel channel) async {
    await client.removeChannel(channel);
  }

  Future<Map<String, dynamic>?> loadMembership() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    final rows = await client
        .from('hotel_members')
        .select('hotel_id, role, hotels(id, name)')
        .eq('user_id', user.id)
        .limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>?> loadHotel() async {
    final membership = await loadMembership();
    final relatedHotel = membership?['hotels'];
    if (relatedHotel is Map) return Map<String, dynamic>.from(relatedHotel);
    final hotelId = membership?['hotel_id'];
    if (hotelId == null) return null;
    return client
        .from('hotels')
        .select('id, name')
        .eq('id', hotelId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> loadSpaces() async {
    final membership = await loadMembership();
    final hotelId = membership?['hotel_id'];
    if (hotelId == null) return [];
    final rows = await client
        .from('spaces')
        .select('id, hotel_id, name, type, floor, created_at')
        .eq('hotel_id', hotelId)
        .order('name');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> loadDevices() async {
    final membership = await loadMembership();
    final hotelId = membership?['hotel_id'];
    if (hotelId == null) return [];
    final rows = await client
        .from('devices')
        .select('id, device_id, name, last_seen_at, space_id, spaces(name)')
        .eq('hotel_id', hotelId)
        .order('device_id');
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<List<Map<String, dynamic>>> loadReadings({int limit = 1000}) async {
    final devices = await loadDevices();
    final deviceIds = devices
        .map((row) => row['id'])
        .whereType<String>()
        .toList();
    if (deviceIds.isEmpty) return [];
    final rows = await client
        .from('sensor_readings')
        .select(
          'id, device_id, sensor_type, value_numeric, value_boolean, unit, recorded_at',
        )
        .inFilter('device_id', deviceIds)
        .order('recorded_at', ascending: false)
        .limit(limit);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>?> loadProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    return client
        .from('profiles')
        .select('id, full_name')
        .eq('id', user.id)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> loadDashboard() async {
    final values = await Future.wait([
      loadHotel(),
      loadSpaces(),
      loadDevices(),
      loadReadings(limit: 1000),
      loadMembership(),
      loadProfile(),
    ]);
    return {
      'hotel': values[0],
      'spaces': values[1] as List<Map<String, dynamic>>,
      'devices': values[2] as List<Map<String, dynamic>>,
      'readings': values[3] as List<Map<String, dynamic>>,
      'membership': values[4],
      'profile': values[5],
    };
  }
}

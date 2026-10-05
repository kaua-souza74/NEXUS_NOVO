import 'package:supabase_flutter/supabase_flutter.dart';

class NexusRepository {
  NexusRepository(this.client);

  final SupabaseClient client;

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
    return client.from('hotels').select('id, name').eq('id', hotelId).maybeSingle();
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

  Future<List<Map<String, dynamic>>> loadReadings({int limit = 100}) async {
    final devices = await loadDevices();
    final deviceIds = devices.map((row) => row['id']).whereType<String>().toList();
    if (deviceIds.isEmpty) return [];
    final rows = await client
        .from('sensor_readings')
        .select('id, device_id, sensor_type, value_numeric, value_boolean, unit, recorded_at')
        .inFilter('device_id', deviceIds)
        .order('recorded_at', ascending: false)
        .limit(limit);
    return rows.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  Future<Map<String, dynamic>?> loadProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    return client.from('profiles').select('id, full_name').eq('id', user.id).maybeSingle();
  }

  Future<Map<String, dynamic>> loadDashboard() async {
    final values = await Future.wait([
      loadHotel(),
      loadSpaces(),
      loadDevices(),
      loadReadings(limit: 100),
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

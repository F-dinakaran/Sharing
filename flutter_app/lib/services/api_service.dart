import 'dart:convert';
import 'package:http/http.dart' as http;

// ⚠️ Change this to your server's IP address
// Use your local IP (e.g. 192.168.1.42) when testing on a real device
// Use 10.0.2.2 when testing on Android emulator
const String BASE_URL = 'http://10.0.2.2:3000';

class ApiService {
  final String token;
  ApiService(this.token);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ─── Auth ───────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$BASE_URL/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return jsonDecode(res.body);
  }

  // ─── Users ──────────────────────────────────────────────
  Future<List<dynamic>> getUsers() async {
    final res = await http.get(Uri.parse('$BASE_URL/api/users'), headers: _headers);
    return jsonDecode(res.body);
  }

  // ─── Messages ────────────────────────────────────────────
  Future<List<dynamic>> getPublicMessages() async {
    final res = await http.get(Uri.parse('$BASE_URL/api/messages/public'), headers: _headers);
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getPrivateMessages(String otherUserId) async {
    final res = await http.get(
      Uri.parse('$BASE_URL/api/messages/private/$otherUserId'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  // ─── Appointments ────────────────────────────────────────
  Future<List<dynamic>> getAvailableSlots() async {
    final res = await http.get(
      Uri.parse('$BASE_URL/api/availability/available'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  Future<List<dynamic>> getMyAppointments() async {
    final res = await http.get(
      Uri.parse('$BASE_URL/api/availability/my'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> bookSlot(String slotId, String reason) async {
    final res = await http.patch(
      Uri.parse('$BASE_URL/api/availability/$slotId/book'),
      headers: _headers,
      body: jsonEncode({'reason': reason}),
    );
    return jsonDecode(res.body);
  }

  // ─── Doctor: create availability ─────────────────────────
  Future<Map<String, dynamic>> createAvailability({
    required String date,
    required String startTime,
    required String endTime,
    required int duration,
  }) async {
    final res = await http.post(
      Uri.parse('$BASE_URL/api/availability'),
      headers: _headers,
      body: jsonEncode({
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'duration': duration,
      }),
    );
    return jsonDecode(res.body);
  }

  Future<Map<String, dynamic>> deleteSlot(String slotId) async {
    final res = await http.delete(
      Uri.parse('$BASE_URL/api/availability/$slotId'),
      headers: _headers,
    );
    return jsonDecode(res.body);
  }
}

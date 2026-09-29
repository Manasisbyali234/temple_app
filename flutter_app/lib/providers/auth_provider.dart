import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthProvider extends ChangeNotifier {
  AuthUser? _user;
  bool _loading = true;

  AuthUser? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.role == 'admin';

  ApiService get api => ApiService(memberId: _user?.id, role: _user?.role);

  AuthProvider() {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role');
    final id = prefs.getString('id');
    final name = prefs.getString('name');
    final email = prefs.getString('email');
    final phone = prefs.getString('phone');
    if (token != null && role != null && id != null) {
      _user = AuthUser(id: id, name: name ?? '', email: email ?? '', phone: phone, role: role);
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> _saveSession(Map<String, dynamic> userData, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('role', userData['role']);
    await prefs.setString('id', userData['id'].toString());
    await prefs.setString('name', userData['name'] ?? '');
    await prefs.setString('email', userData['email'] ?? '');
    if (userData['phone'] != null) await prefs.setString('phone', userData['phone']);
  }

  Future<void> _doLogin(String endpoint, String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw ApiException(body['error']?.toString() ?? 'Login failed');
    final token = body['token'] as String;
    final userData = body['user'] as Map<String, dynamic>;
    _user = AuthUser(
      id: userData['id'].toString(),
      name: userData['name'] ?? '',
      email: userData['email'] ?? '',
      phone: userData['phone'],
      role: userData['role'],
    );
    await _saveSession(userData, token);
    notifyListeners();
  }

  Future<void> loginAdmin(String email, String password) =>
      _doLogin('/auth/admin/login', email, password);

  Future<void> loginMember(String email, String password) =>
      _doLogin('/auth/member/login', email, password);

  Future<void> logout() async {
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}

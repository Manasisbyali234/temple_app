import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiLoginException implements Exception {
  final String message;
  ApiLoginException(this.message);
  @override
  String toString() => message;
}

class LocalDb {
  static SharedPreferences? _prefs;

  static bool _seeded = false;

  static Future<SharedPreferences> get db async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!_seeded) {
      _seeded = true;
      await _ensureSeeded();
    }
    return _prefs!;
  }

  static String _hash(String pw) => sha256.convert(utf8.encode(pw)).toString();

  // ── Generic table helpers ─────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> _getTable(String table) async {
    final p = await db;
    final raw = p.getString('table_$table');
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(raw));
  }

  static Future<void> _saveTable(String table, List<Map<String, dynamic>> rows) async {
    final p = await db;
    await p.setString('table_$table', jsonEncode(rows));
  }

  static Future<int> _nextId(String table) async {
    final p = await db;
    final id = (p.getInt('seq_$table') ?? 0) + 1;
    await p.setInt('seq_$table', id);
    return id;
  }

  static Future<Map<String, dynamic>> _insert(String table, Map<String, dynamic> row) async {
    final rows = await _getTable(table);
    final id = await _nextId(table);
    final newRow = {'id': id, ...row};
    rows.add(newRow);
    await _saveTable(table, rows);
    return newRow;
  }

  static Future<void> _update(String table, int id, Map<String, dynamic> updates) async {
    final rows = await _getTable(table);
    final idx = rows.indexWhere((r) => r['id'] == id);
    if (idx != -1) rows[idx] = {...rows[idx], ...updates};
    await _saveTable(table, rows);
  }

  // ── Seed default admin ────────────────────────────────────────────────────

  static Future<void> _ensureSeeded() async {
    final p = _prefs!;
    final raw = p.getString('table_users');
    if (raw == null) {
      final admin = {
        'id': 1,
        'name': 'Admin',
        'email': 'admin@temple.com',
        'phone': '',
        'password_hash': _hash('admin123'),
        'role': 'admin',
        'status': 'active',
      };
      await p.setString('table_users', jsonEncode([admin]));
      await p.setInt('seq_users', 1);
    } else {
      var users = List<Map<String, dynamic>>.from(jsonDecode(raw));

      // Fix any member whose status is missing or not a valid string
      bool changed = false;
      users = users.map((u) {
        final s = u['status'];
        if (u['role'] == 'member' && (s == null || s.toString().trim().isEmpty)) {
          changed = true;
          return {...u, 'status': 'active'};
        }
        return u;
      }).toList();

      // Ensure admin exists
      final hasAdmin = users.any((u) => u['email'] == 'admin@temple.com' && u['role'] == 'admin');
      if (!hasAdmin) {
        users.insert(0, {
          'id': 1,
          'name': 'Admin',
          'email': 'admin@temple.com',
          'phone': '',
          'password_hash': _hash('admin123'),
          'role': 'admin',
          'status': 'active',
        });
        changed = true;
      }

      if (changed) await p.setString('table_users', jsonEncode(users));

      // Ensure seq_users is at least as large as the max existing id
      final maxId = users.fold<int>(1, (m, u) => (u['id'] as int) > m ? (u['id'] as int) : m);
      final currentSeq = p.getInt('seq_users') ?? 0;
      if (currentSeq < maxId) await p.setInt('seq_users', maxId);
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> login(String email, String password, String role) async {
    final rows = await _getTable('users');
    final normalizedEmail = email.trim().toLowerCase();
    final byEmail = rows.where((r) =>
        (r['email'] as String).toLowerCase() == normalizedEmail &&
        r['role'] == role).toList();
    if (byEmail.isEmpty) throw ApiLoginException('No $role account found for that email.');
    final user = byEmail.first;
    final storedStatus = (user['status'] ?? '').toString().trim();
    if (storedStatus != 'active') throw ApiLoginException('Account is inactive (status="$storedStatus"). Contact admin.');
    if (user['password_hash'] != _hash(password)) throw ApiLoginException('Wrong password.');
    return user;
  }

  /// Wipe all data and re-seed (useful for dev reset)
  static Future<void> resetAll() async {
    final p = await db;
    await p.clear();
    _prefs = null;
    await db; // re-seeds admin
  }

  static Future<Map<String, dynamic>> createMember(Map<String, dynamic> data) async {
    final email = (data['email'] as String).trim().toLowerCase();
    final existing = await _getTable('users');
    if (existing.any((r) => (r['email'] as String).toLowerCase() == email && r['role'] == 'member')) {
      throw Exception('A member with this email already exists');
    }
    return _insert('users', {
      'name': data['name'],
      'email': email,
      'phone': data['phone'] ?? '',
      'password_hash': _hash(data['password']),
      'role': 'member',
      'status': 'active',
    });
  }

  // ── Members (admin view) ──────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getMembers() async {
    final users = await _getTable('users');
    final members = users.where((r) => r['role'] == 'member').toList();
    final devs = await _getTable('devotees');
    final dons = await _getTable('donations');
    return members.map((m) {
      final mid = m['id'];
      final mDevs = devs.where((d) => d['member_id'] == mid).toList();
      final mDons = dons.where((d) => d['member_id'] == mid).toList();
      final totalCollection = mDevs.fold<double>(0, (s, r) => s + (r['paid_amount'] as num).toDouble()) +
          mDons.where((r) => r['paid'] == true).fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
      final totalOutstanding = mDevs.fold<double>(
          0, (s, r) => s + ((r['total_amount'] as num) - (r['paid_amount'] as num)).toDouble());
      return {
        ...m,
        'total_collection': totalCollection,
        'total_outstanding': totalOutstanding,
        'devotee_count': mDevs.length,
        'donation_count': mDons.length,
      };
    }).toList();
  }

  static Future<Map<String, dynamic>> getAdminDashboard() async {
    final users = await _getTable('users');
    final devs = await _getTable('devotees');
    final dons = await _getTable('donations');
    final pooja = await _getTable('pooja_bookings');
    final sankalp = await _getTable('sankalp_bookings');
    return {
      'total_members': users.where((r) => r['role'] == 'member').length,
      'total_devotees': devs.length,
      'total_donations': dons.length,
      'total_pooja_bookings': pooja.length,
      'total_sankalp_bookings': sankalp.length,
      'total_collection': devs.fold<double>(0, (s, r) => s + (r['paid_amount'] as num).toDouble()) +
          dons.where((r) => r['paid'] == true).fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble()),
      'total_outstanding': devs.fold<double>(
          0, (s, r) => s + ((r['total_amount'] as num) - (r['paid_amount'] as num)).toDouble()),
    };
  }

  static Future<Map<String, dynamic>> getMemberSummary(int memberId) async {
    final users = await _getTable('users');
    final memberRows = users.where((r) => r['id'] == memberId).toList();
    if (memberRows.isEmpty) throw Exception('Member not found');
    final devs = (await _getTable('devotees')).where((r) => r['member_id'] == memberId).toList();
    final dons = (await _getTable('donations')).where((r) => r['member_id'] == memberId).toList();
    final pooja = (await _getTable('pooja_bookings')).where((r) => r['member_id'] == memberId).toList();
    final sankalp = (await _getTable('sankalp_bookings')).where((r) => r['member_id'] == memberId).toList();
    final totalCollection = devs.fold<double>(0, (s, r) => s + (r['paid_amount'] as num).toDouble()) +
        dons.where((r) => r['paid'] == true).fold<double>(0, (s, r) => s + (r['amount'] as num).toDouble());
    final totalOutstanding = devs.fold<double>(
        0, (s, r) => s + ((r['total_amount'] as num) - (r['paid_amount'] as num)).toDouble());
    return {
      'member': memberRows.first,
      'totals': {
        'total_collection': totalCollection,
        'total_outstanding': totalOutstanding,
        'devotee_count': devs.length,
      },
      'devotees': devs,
      'donations': dons,
      'pooja_bookings': pooja,
      'sankalp_bookings': sankalp,
    };
  }

  static Future<void> updateMemberStatus(int memberId, String status) async {
    await _update('users', memberId, {'status': status});
  }

  // ── Devotees ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getDevotees(int memberId) async {
    final rows = await _getTable('devotees');
    return rows.where((r) => r['member_id'] == memberId).toList().reversed.toList();
  }

  static Future<Map<String, dynamic>> addDevotee(int memberId, Map<String, dynamic> data) async {
    final total = (data['total_amount'] as num?)?.toDouble() ??
        (data['initial_payment'] as num?)?.toDouble() ?? 0.0;
    final paid = (data['initial_payment'] as num?)?.toDouble() ?? 0.0;
    final status = paid >= total ? 'paid' : paid > 0 ? 'partially_paid' : 'pending';
    return _insert('devotees', {
      'member_id': memberId,
      'name': data['name'],
      'address': data['address'] ?? '',
      'phone': data['phone'] ?? '',
      'initial_payment': paid,
      'payment_method': data['payment_method'] ?? 'cash',
      'total_amount': total,
      'paid_amount': paid,
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>> payDevotee(int devoteeId, double amount, String method) async {
    final rows = await _getTable('devotees');
    final dev = rows.firstWhere((r) => r['id'] == devoteeId);
    final newPaid = (dev['paid_amount'] as num).toDouble() + amount;
    final total = (dev['total_amount'] as num).toDouble();
    final status = newPaid >= total ? 'paid' : 'partially_paid';
    await _update('devotees', devoteeId, {'paid_amount': newPaid, 'status': status});
    final updated = await _getTable('devotees');
    return updated.firstWhere((r) => r['id'] == devoteeId);
  }

  static Future<Map<String, dynamic>> getDevoteeSummary(int memberId) async {
    final devs = (await _getTable('devotees')).where((r) => r['member_id'] == memberId).toList();
    return {
      'total_collected': devs.fold<double>(0, (s, r) => s + (r['paid_amount'] as num).toDouble()),
      'total_outstanding': devs.fold<double>(
          0, (s, r) => s + ((r['total_amount'] as num) - (r['paid_amount'] as num)).toDouble()),
      'count': devs.length,
    };
  }

  // ── Donations ─────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getDonations(int memberId) async {
    final rows = await _getTable('donations');
    return rows.where((r) => r['member_id'] == memberId).toList().reversed.toList();
  }

  static Future<Map<String, dynamic>> addDonation(int memberId, Map<String, dynamic> data) async {
    return _insert('donations', {
      'member_id': memberId,
      'donor_name': data['donor_name'],
      'donor_phone': data['donor_phone'] ?? '',
      'section': data['section'],
      'description': data['description'] ?? '',
      'amount': data['amount'] ?? 0,
      'payment_method': data['payment_method'] ?? 'cash',
      'paid': data['paid'] == true,
      'donation_date': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getDonationSummary(int memberId) async {
    final dons = (await _getTable('donations'))
        .where((r) => r['member_id'] == memberId && r['paid'] == true)
        .toList();
    final Map<String, double> bySection = {};
    for (final r in dons) {
      final s = r['section'] as String;
      bySection[s] = (bySection[s] ?? 0) + (r['amount'] as num).toDouble();
    }
    return bySection.entries.map((e) => {'section': e.key, 'total_paid': e.value}).toList();
  }

  // ── Banners ───────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getBanners(int memberId) async {
    final rows = await _getTable('banners');
    return rows.where((r) => r['member_id'] == memberId).toList().reversed.toList();
  }

  static Future<Map<String, dynamic>> addBanner(int memberId, Map<String, dynamic> data) async {
    return _insert('banners', {
      'member_id': memberId,
      'title': data['title'],
      'description': data['description'] ?? '',
      'image_url': data['image_url'] ?? '',
      'start_date': data['start_date'],
      'end_date': data['end_date'],
      'start_time': data['start_time'],
      'end_time': data['end_time'],
      'active': true,
    });
  }

  // ── Pooja Bookings ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getPoojaBookings(int memberId) async {
    final rows = await _getTable('pooja_bookings');
    return rows.where((r) => r['member_id'] == memberId).toList().reversed.toList();
  }

  static Future<Map<String, dynamic>> addPoojaBooking(int memberId, Map<String, dynamic> data) async {
    return _insert('pooja_bookings', {
      'member_id': memberId,
      'devotee_name': data['devotee_name'],
      'phone': data['phone'] ?? '',
      'pooja_name': data['pooja_name'],
      'booking_date': data['booking_date'],
      'booking_time': data['booking_time'],
      'amount': data['amount'] ?? 0,
      'payment_method': data['payment_method'] ?? 'cash',
      'status': 'booked',
    });
  }

  // ── Sankalp Bookings ──────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSankalpBookings(int memberId) async {
    final rows = await _getTable('sankalp_bookings');
    return rows.where((r) => r['member_id'] == memberId).toList().reversed.toList();
  }

  static Future<Map<String, dynamic>> addSankalpBooking(int memberId, Map<String, dynamic> data) async {
    return _insert('sankalp_bookings', {
      'member_id': memberId,
      'devotee_name': data['devotee_name'],
      'phone': data['phone'] ?? '',
      'sankalp_type': data['sankalp_type'],
      'booking_date': data['booking_date'],
      'booking_time': data['booking_time'],
      'amount': data['amount'] ?? 0,
      'payment_method': data['payment_method'] ?? 'cash',
      'status': 'booked',
    });
  }

  // ── Meetings ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getMeetings(int memberId) async {
    final meetings = (await _getTable('meetings'))
        .where((r) => r['member_id'] == memberId)
        .toList()
        .reversed
        .toList();
    final items = await _getTable('meeting_items');
    return meetings.map((m) {
      final mItems = items.where((i) => i['meeting_id'] == m['id']).toList();
      return {...m, 'items': mItems};
    }).toList();
  }

  static Future<Map<String, dynamic>> addMeeting(int memberId, Map<String, dynamic> data) async {
    final meeting = await _insert('meetings', {
      'member_id': memberId,
      'title': data['title'],
      'meeting_date': data['meeting_date'],
      'meeting_time': data['meeting_time'],
      'notes': data['notes'] ?? '',
    });
    final itemsList = data['items'] as List<dynamic>? ?? [];
    final savedItems = <Map<String, dynamic>>[];
    for (final item in itemsList) {
      final saved = await _insert('meeting_items', {
        'meeting_id': meeting['id'],
        'item_name': item['item_name'],
        'item_type': item['item_type'] ?? '',
        'quantity': item['quantity'] ?? '',
        'notes': item['notes'] ?? '',
      });
      savedItems.add(saved);
    }
    return {...meeting, 'items': savedItems};
  }
}

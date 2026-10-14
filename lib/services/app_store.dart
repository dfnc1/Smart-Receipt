import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils.dart';
import '../models/tx.dart';
import '../models/user_account.dart';

class AppStore extends ChangeNotifier {
  late SharedPreferences _prefs;
  List<UserAccount> _users = [];
  UserAccount? current;
  List<Tx> transactions = [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final raw = _prefs.getString('users');
      if (raw != null) {
        _users = (jsonDecode(raw) as List)
            .map((e) => UserAccount.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final email = _prefs.getString('session_email');
      if (email != null) {
        final idx = _users.indexWhere((u) => u.email == email);
        if (idx != -1) {
          current = _users[idx];
          _loadTransactions();
        }
      }
    } catch (_) {
      // Data lokal rusak: mulai dari kosong
      _users = [];
      current = null;
    }
  }

  String get _txKey => 'tx_${current!.email}';

  void _loadTransactions() {
    try {
      final raw = _prefs.getString(_txKey);
      transactions = raw == null
          ? []
          : (jsonDecode(raw) as List)
              .map((e) => Tx.fromJson(e as Map<String, dynamic>))
              .toList();
    } catch (_) {
      transactions = [];
    }
    _sort();
  }

  void _sort() => transactions.sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.id.compareTo(a.id);
      });

  Future<void> _saveTransactions() => _prefs.setString(
      _txKey, jsonEncode(transactions.map((t) => t.toJson()).toList()));

  // ---- Akun ----

  /// Mengembalikan pesan error, atau null jika berhasil.
  String? register(String name, String email, String password) {
    final e = email.trim().toLowerCase();
    if (_users.any((u) => u.email == e)) return 'Email sudah terdaftar';
    _users.add(UserAccount(name.trim(), e, hashPassword(password, e)));
    _prefs.setString(
        'users', jsonEncode(_users.map((u) => u.toJson()).toList()));
    return null;
  }

  String? login(String email, String password) {
    final e = email.trim().toLowerCase();
    final idx = _users.indexWhere(
        (u) => u.email == e && u.passwordHash == hashPassword(password, e));
    if (idx == -1) return 'Username atau Password salah';
    current = _users[idx];
    _prefs.setString('session_email', current!.email);
    _loadTransactions();
    notifyListeners();
    return null;
  }

  void logout() {
    current = null;
    transactions = [];
    _prefs.remove('session_email');
    notifyListeners();
  }

  // ---- Transaksi ----

  void addTransaction(Tx t) {
    transactions.add(t);
    _sort();
    _saveTransactions();
    notifyListeners();
  }

  void deleteTransaction(String id) {
    transactions.removeWhere((t) => t.id == id);
    _saveTransactions();
    notifyListeners();
  }

  void updateTransaction(Tx updated) {
    final idx = transactions.indexWhere((t) => t.id == updated.id);
    if (idx == -1) return;
    transactions[idx] = updated;
    _sort();
    _saveTransactions();
    notifyListeners();
  }

  void clearTransactions() {
    transactions = [];
    _saveTransactions();
    notifyListeners();
  }

  // ---- Ringkasan ----

  double monthTotal(DateTime m) => transactions
      .where((t) => t.date.year == m.year && t.date.month == m.month)
      .fold<double>(0, (s, t) => s + t.total);

  /// Total per kategori (dihitung dari barang) pada bulan tertentu.
  Map<String, double> categoryTotals(DateTime m) {
    final result = <String, double>{};
    for (final t in transactions) {
      if (t.date.year != m.year || t.date.month != m.month) continue;
      for (final i in t.items) {
        result[i.category] = (result[i.category] ?? 0) + i.price;
      }
    }
    return result;
  }
}

final AppStore store = AppStore();

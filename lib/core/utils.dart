import 'dart:convert';
import 'package:crypto/crypto.dart';

const List<String> _bulan = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

String two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime d) => '${d.day} ${_bulan[d.month - 1]} ${d.year}';

String monthLabel(DateTime d) => '${_bulan[d.month - 1]} ${d.year}';

/// 27500 -> "27.500"
String plainNumber(num v) => v.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

/// 27500 -> "Rp 27.500"
String rupiah(num v) => 'Rp ${plainNumber(v)}';

/// "27.500" / "Rp 27.500" / "27.500,50" -> angka
double? parseAmount(String input) {
  final s = input.replaceAll(RegExp(r'[^0-9.,]'), '');
  if (s.isEmpty) return null;
  final comma = s.lastIndexOf(',');
  if (comma != -1 && s.length - comma - 1 <= 2) {
    final intPart = s.substring(0, comma).replaceAll(RegExp(r'[.,]'), '');
    final dec = s.substring(comma + 1);
    return double.tryParse(
        '${intPart.isEmpty ? '0' : intPart}.${dec.isEmpty ? '0' : dec}');
  }
  return double.tryParse(s.replaceAll(RegExp(r'[.,]'), ''));
}

/// Hash password menggunakan SHA-256 untuk penyimpanan lokal yang lebih aman.
String hashPassword(String password, String email) {
  final key = '$email::$password::smartreceipt_2025';
  final bytes = utf8.encode(key);
  return sha256.convert(bytes).toString();
}

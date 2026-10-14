// ============================================================================
// SmartReceipt (VERSI MANDIRI) - lib/main.dart
//
// Berjalan hanya dengan Flutter: TANPA backend Python, TANPA MySQL/SQLite.
// Cocok untuk emulator Android Studio.
//
// Yang berfungsi sungguhan di versi ini:
//  - Registrasi & login lokal (data akun disimpan di HP via shared_preferences)
//  - Parsing teks struk (Regex): merchant, tanggal, total, daftar barang
//  - Klasifikasi kategori per barang: TF-IDF + Multinomial Naive Bayes yang
//    ditulis langsung dalam Dart (dilatih dari data contoh kecil di bawah)
//  - Pratinjau & koreksi, simpan, dashboard, riwayat, detail, hapus
//
// Yang BELUM aktif di versi ini:
//  - OCR kamera/galeri (Google ML Kit). Sebagai gantinya, teks struk dipilih
//    dari contoh atau diketik/ditempel. Hasil parsing & klasifikasi tetap nyata.
//
// Satu-satunya dependency tambahan: shared_preferences
//   flutter pub add shared_preferences
// ============================================================================

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// BAGIAN 1: KONSTANTA & FUNGSI BANTU
// ============================================================================

const List<String> kCategories = [
  'Konsumsi',
  'Transportasi',
  'Kesehatan',
  'Belanja',
  'Lainnya',
];

const Color kPrimary = Color(0xFF12A37A);
const Color kPrimaryDark = Color(0xFF0E8A68);
const Color kBg = Color(0xFFF1F6F5);
const Color kTextDark = Color(0xFF1F2D3D);
const Color kTextGrey = Color(0xFF6B7C8A);
const Color kBorder = Color(0xFFD5E0DE);
const Color kError = Color(0xFFD64545);

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

Color categoryColor(String? c) {
  switch (c) {
    case 'Konsumsi':
      return const Color(0xFF12A37A);
    case 'Transportasi':
      return const Color(0xFF3B82F6);
    case 'Kesehatan':
      return const Color(0xFFE5484D);
    case 'Belanja':
      return const Color(0xFF8B5CF6);
    default:
      return const Color(0xFF8A97A3);
  }
}

IconData categoryIcon(String? c) {
  switch (c) {
    case 'Konsumsi':
      return Icons.restaurant_outlined;
    case 'Transportasi':
      return Icons.directions_car_outlined;
    case 'Kesehatan':
      return Icons.medical_services_outlined;
    case 'Belanja':
      return Icons.shopping_basket_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

/// Hash sederhana HANYA untuk demo agar password tidak tersimpan polos.
/// Bukan keamanan sungguhan. Di versi lengkap, hashing dilakukan backend (bcrypt).
String hashPassword(String password, String email) {
  var h = 0x811C9DC5;
  for (final c in '$email::$password::smartreceipt'.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16);
}

// ============================================================================
// BAGIAN 2: MODEL DATA
// ============================================================================

class UserAccount {
  final String name;
  final String email;
  final String passwordHash;
  const UserAccount(this.name, this.email, this.passwordHash);

  Map<String, dynamic> toJson() =>
      {'name': name, 'email': email, 'password_hash': passwordHash};

  factory UserAccount.fromJson(Map<String, dynamic> j) => UserAccount(
      j['name'] as String, j['email'] as String, j['password_hash'] as String);
}

class TxItem {
  String name;
  double price;
  String category;
  double? probability; // null jika kategori dipilih/diubah manual

  TxItem(this.name, this.price, this.category, [this.probability]);

  Map<String, dynamic> toJson() => {
    'name': name,
    'price': price,
    'category': category,
    'probability': probability,
  };

  factory TxItem.fromJson(Map<String, dynamic> j) => TxItem(
    j['name'] as String,
    (j['price'] as num).toDouble(),
    j['category'] as String,
    (j['probability'] as num?)?.toDouble(),
  );
}

class Tx {
  final String id;
  final String merchant;
  final DateTime date;
  final double total;
  final String category; // kategori dominan (total harga terbesar)
  final List<TxItem> items;
  final bool manualEdit;

  Tx({
    required this.id,
    required this.merchant,
    required this.date,
    required this.total,
    required this.category,
    required this.items,
    required this.manualEdit,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'merchant': merchant,
    'date': date.toIso8601String(),
    'total': total,
    'category': category,
    'manual_edit': manualEdit,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory Tx.fromJson(Map<String, dynamic> j) => Tx(
    id: j['id'] as String,
    merchant: j['merchant'] as String,
    date: DateTime.parse(j['date'] as String),
    total: (j['total'] as num).toDouble(),
    category: j['category'] as String,
    manualEdit: j['manual_edit'] as bool? ?? false,
    items: (j['items'] as List)
        .map((e) => TxItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ============================================================================
// BAGIAN 3: KLASIFIKASI TF-IDF + MULTINOMIAL NAIVE BAYES (ditulis dalam Dart)
// ============================================================================

/// Data latih contoh (kecil). Tambah kata di sini agar model makin pintar.
const Map<String, List<String>> kTrainingData = {
  'Konsumsi': [
    'roti tawar', 'roti coklat', 'air mineral', 'susu uht', 'susu', 'kopi',
    'teh botol', 'nasi goreng', 'ayam goreng', 'mie instan', 'indomie',
    'biskuit', 'snack keripik', 'coklat', 'telur', 'gula pasir', 'es jeruk',
    'jus alpukat', 'burger', 'pizza', 'makan siang', 'minuman', 'permen',
    'beras', 'minyak goreng', 'yogurt', 'keju', 'sosis',
  ],
  'Transportasi': [
    'pertalite', 'pertamax', 'solar', 'bensin', 'bbm', 'parkir motor',
    'parkir mobil', 'parkir', 'tol', 'ojek online', 'grab', 'gojek',
    'tiket kereta', 'tiket bus', 'angkot', 'oli mesin', 'servis motor',
    'travel', 'taksi',
  ],
  'Kesehatan': [
    'paracetamol', 'obat batuk', 'obat flu', 'vitamin', 'masker medis',
    'antiseptik', 'betadine', 'plester', 'sirup obat', 'tablet', 'kapsul',
    'salep', 'minyak kayu putih', 'hand sanitizer', 'termometer',
    'antibiotik', 'obat maag',
  ],
  'Belanja': [
    'sabun mandi', 'shampoo', 'deterjen', 'tisu', 'kaos', 'baju', 'sepatu',
    'tas', 'pulpen', 'buku tulis', 'sandal', 'pasta gigi', 'handuk',
    'lampu', 'baterai', 'sikat gigi', 'pembersih lantai', 'celana',
  ],
  'Lainnya': [
    'donasi', 'biaya admin', 'pulsa', 'token listrik', 'pajak', 'denda',
    'iuran', 'zakat', 'infaq', 'biaya layanan', 'materai',
  ],
};

class ClassResult {
  final String? category;
  final double? probability;
  const ClassResult(this.category, this.probability);
}

class NaiveBayesClassifier {
  final Map<String, double> _idf = {};
  final Map<String, Map<String, double>> _classWeights = {};
  final Map<String, double> _classTotal = {};
  final Map<String, int> _classDocs = {};
  int _docCount = 0;

  /// Preprocessing: huruf kecil, buang angka/simbol, token minimal 2 huruf.
  static List<String> tokenize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length >= 2)
      .toList();

  /// Pelatihan: hitung IDF, lalu akumulasi bobot TF-IDF per kelas.
  void train(Map<String, List<String>> data) {
    final docs = <MapEntry<String, List<String>>>[];
    final df = <String, int>{};

    data.forEach((label, texts) {
      for (final t in texts) {
        final tokens = tokenize(t);
        if (tokens.isEmpty) continue;
        docs.add(MapEntry(label, tokens));
        for (final term in tokens.toSet()) {
          df[term] = (df[term] ?? 0) + 1;
        }
      }
    });

    _docCount = docs.length;
    // IDF = ln((1+N)/(1+df)) + 1
    df.forEach((term, d) {
      _idf[term] = math.log((1 + _docCount) / (1 + d)) + 1;
    });

    for (final doc in docs) {
      final counts = <String, int>{};
      for (final t in doc.value) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
      final weights = _classWeights.putIfAbsent(doc.key, () => {});
      counts.forEach((term, c) {
        final w = (c / doc.value.length) * _idf[term]!; // TF x IDF
        weights[term] = (weights[term] ?? 0) + w;
        _classTotal[doc.key] = (_classTotal[doc.key] ?? 0) + w;
      });
      _classDocs[doc.key] = (_classDocs[doc.key] ?? 0) + 1;
    }
  }

  /// Prediksi kategori. Mengembalikan null jika kata tidak dikenal atau
  /// probabilitas terlalu rendah (tidak menebak asal).
  ClassResult predict(String text) {
    final known = tokenize(text).where(_idf.containsKey).toList();
    if (known.isEmpty || _docCount == 0) return const ClassResult(null, null);

    final counts = <String, int>{};
    for (final t in known) {
      counts[t] = (counts[t] ?? 0) + 1;
    }

    final vocab = _idf.length;
    final scores = <String, double>{};
    _classWeights.forEach((label, weights) {
      var score = math.log(_classDocs[label]! / _docCount); // prior
      counts.forEach((term, c) {
        final x = (c / known.length) * _idf[term]!;
        // Likelihood dengan Laplace smoothing
        score += x * math.log(((weights[term] ?? 0) + 1) / (_classTotal[label]! + vocab));
      });
      scores[label] = score;
    });

    // Softmax -> probabilitas
    final maxScore = scores.values.reduce(math.max);
    final exps = scores.map((k, v) => MapEntry(k, math.exp(v - maxScore)));
    final sum = exps.values.fold<double>(0, (a, b) => a + b);
    final best = exps.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final prob = best.value / sum;

    if (prob < 0.4) return const ClassResult(null, null);
    return ClassResult(best.key, prob);
  }
}

/// Satu instance model untuk seluruh aplikasi (dilatih saat aplikasi dibuka).
final NaiveBayesClassifier classifier = NaiveBayesClassifier()..train(kTrainingData);

// ============================================================================
// BAGIAN 4: SMART PARSING (Regex) UNTUK TEKS STRUK
// ============================================================================

class ParsedItem {
  final String name;
  final double? price;
  final String? category;
  final double? probability;
  const ParsedItem(this.name, this.price, this.category, this.probability);
}

class ParsedReceipt {
  final String? merchant;
  final DateTime? date;
  final double? total;
  final List<ParsedItem> items;
  const ParsedReceipt({this.merchant, this.date, this.total, this.items = const []});
}

class ReceiptParser {
  static final RegExp _dateRe = RegExp(r'(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})');
  static final RegExp _itemRe = RegExp(r'^(?=.*[A-Za-z])(.+?)\s+(\d[\d.,]*)$');
  static final RegExp _skipRe = RegExp(
      r'total|tunai|kembali|bayar|ppn|pajak|diskon|tgl|tanggal|telp|npwp|kasir|terima kasih|jl\.',
      caseSensitive: false);
  static final RegExp _totalRe = RegExp(r'(^|\s)total(\s|:|$)', caseSensitive: false);
  static final RegExp _numberEndRe = RegExp(r'([\d.,]+)\s*$');

  static ParsedReceipt parse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Merchant: baris pertama yang berisi huruf
    String? merchant;
    int merchantIndex = -1;
    for (var i = 0; i < lines.length; i++) {
      if (RegExp(r'[A-Za-z]').hasMatch(lines[i])) {
        merchant = lines[i];
        merchantIndex = i;
        break;
      }
    }

    // Tanggal
    DateTime? date;
    for (final l in lines) {
      final m = _dateRe.firstMatch(l);
      if (m == null) continue;
      final d = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      var y = int.parse(m.group(3)!);
      if (y < 100) y += 2000;
      final candidate = DateTime(y, mo, d);
      // Pastikan tanggalnya valid (misal 31/02 tidak diterima)
      if (candidate.year == y && candidate.month == mo && candidate.day == d) {
        date = candidate;
        break;
      }
    }

    // Total
    double? total;
    for (final l in lines) {
      if (_totalRe.hasMatch(l) && !l.toLowerCase().contains('sub')) {
        final m = _numberEndRe.firstMatch(l);
        if (m != null) {
          total = parseAmount(m.group(1)!);
          if (total != null) break;
        }
      }
    }

    // Barang: baris "nama  harga", selain baris merchant & baris non-barang
    final items = <ParsedItem>[];
    for (var i = 0; i < lines.length; i++) {
      if (i == merchantIndex) continue;
      final l = lines[i];
      if (_skipRe.hasMatch(l)) continue;
      final m = _itemRe.firstMatch(l);
      if (m == null) continue;
      final price = parseAmount(m.group(2)!);
      if (price == null) continue;
      final name = m.group(1)!.trim();
      final result = classifier.predict(name);
      items.add(ParsedItem(name, price, result.category, result.probability));
    }

    return ParsedReceipt(merchant: merchant, date: date, total: total, items: items);
  }
}

// ============================================================================
// BAGIAN 5: PENGELOLAAN DATA (AppStore + penyimpanan lokal)
// ============================================================================

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
    _prefs.setString('users', jsonEncode(_users.map((u) => u.toJson()).toList()));
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

// ============================================================================
// BAGIAN 6: MAIN & APLIKASI
// ============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.init(); // muat akun, sesi, dan transaksi tersimpan
  runApp(const SmartReceiptApp());
}

class SmartReceiptApp extends StatelessWidget {
  const SmartReceiptApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: kPrimary)
        .copyWith(primary: kPrimary, onPrimary: Colors.white);

    return MaterialApp(
      title: 'SmartReceipt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: kBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          foregroundColor: kTextDark,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: kTextDark,
            side: const BorderSide(color: kBorder),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      // Login/logout otomatis berpindah halaman karena store memberi notifikasi.
      home: ListenableBuilder(
        listenable: store,
        builder: (context, _) =>
        store.current == null ? const LoginScreen() : const HomeShell(),
      ),
    );
  }
}

// ============================================================================
// BAGIAN 7: WIDGET UMUM
// ============================================================================

InputDecoration fieldDecoration(
    String label, {
      IconData? icon,
      String? hint,
      String? prefix,
      Widget? suffix,
    }) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefix,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    suffixIcon: suffix,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(kBorder),
    enabledBorder: border(kBorder),
    focusedBorder: border(kPrimary, 1.6),
    errorBorder: border(kError),
    focusedErrorBorder: border(kError, 1.6),
  );
}

void showMessage(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? kError : kPrimaryDark,
      behavior: SnackBarBehavior.floating,
    ));
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3ECEA)),
      ),
      child: child,
    );
  }
}

class EmptyView extends StatelessWidget {
  final String message;
  const EmptyView({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 48, color: kTextGrey),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center, style: const TextStyle(color: kTextGrey)),
        ],
      ),
    );
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration:
          BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        const Text('SmartReceipt',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kTextDark)),
      ],
    );
  }
}

class TxTile extends StatelessWidget {
  final Tx tx;
  final VoidCallback onTap;
  const TxTile({super.key, required this.tx, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(tx.category);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)),
              child: Icon(categoryIcon(tx.category), color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.merchant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: kTextDark)),
                  const SizedBox(height: 2),
                  Text(fmtDate(tx.date),
                      style: const TextStyle(color: kTextGrey, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('- ${rupiah(tx.total)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: kTextDark)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: color.withAlpha(30), borderRadius: BorderRadius.circular(8)),
                  child: Text(tx.category, style: TextStyle(color: color, fontSize: 11)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Kolom pilihan kategori (membuka bottom sheet).
class CategoryPickerField extends StatelessWidget {
  final String? value;
  final String? errorText;
  final ValueChanged<String> onChanged;
  const CategoryPickerField(
      {super.key, required this.value, required this.onChanged, this.errorText});

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Pilih kategori',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            for (final c in kCategories)
              ListTile(
                leading: Icon(categoryIcon(c), color: categoryColor(c)),
                title: Text(c),
                trailing: c == value ? const Icon(Icons.check, color: kPrimary) : null,
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: fieldDecoration('Kategori', suffix: const Icon(Icons.arrow_drop_down))
            .copyWith(errorText: errorText),
        child: Text(value ?? 'Pilih',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: value == null ? kTextGrey : kTextDark)),
      ),
    );
  }
}

// ============================================================================
// BAGIAN 8: LOGIN & REGISTRASI
// ============================================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _pwCtl = TextEditingController();
  bool _hidePw = true;
  String? _error;

  @override
  void dispose() {
    _emailCtl.dispose();
    _pwCtl.dispose();
    super.dispose();
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    final err = store.login(_emailCtl.text, _pwCtl.text);
    // Jika berhasil, store memberi notifikasi dan halaman otomatis ke Beranda.
    if (err != null) setState(() => _error = err);
  }

  Future<void> _openRegister() async {
    final ok = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const RegisterScreen()));
    if (ok == true && mounted) {
      showMessage(context, 'Akun berhasil dibuat. Silakan login.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const BrandHeader(),
                const SizedBox(height: 40),
                const Text('Selamat datang kembali',
                    style: TextStyle(
                        fontSize: 28, fontWeight: FontWeight.w700, color: kTextDark)),
                const SizedBox(height: 8),
                const Text('Kelola setiap struk dan pengeluaran dalam satu tempat yang rapi.',
                    style: TextStyle(color: kTextGrey)),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _emailCtl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: fieldDecoration('Username/Email',
                      icon: Icons.mail_outline, hint: 'nama@email.com'),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Username/Email wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pwCtl,
                  obscureText: _hidePw,
                  decoration: fieldDecoration(
                    'Password',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(_hidePw
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() => _hidePw = !_hidePw),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: kError)),
                ],
                const SizedBox(height: 24),
                FilledButton(onPressed: _login, child: const Text('Login')),
                const SizedBox(height: 20),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Belum punya akun? ', style: TextStyle(color: kTextGrey)),
                      GestureDetector(
                        onTap: _openRegister,
                        child: const Text('Daftar di sini',
                            style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text('Data tersimpan hanya di perangkat ini.',
                      style: TextStyle(color: kTextGrey, fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _pwCtl = TextEditingController();
  bool _hidePw = true;
  String? _error;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _pwCtl.dispose();
    super.dispose();
  }

  void _register() {
    if (!_formKey.currentState!.validate()) return;
    final err = store.register(_nameCtl.text, _emailCtl.text, _pwCtl.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    Navigator.of(context).pop(true); // kembali ke Login
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const BrandHeader()),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Buat akun baru',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w700, color: kTextDark)),
                const SizedBox(height: 8),
                const Text('Mulai catat pengeluaran tanpa repot mengetik ulang struk.',
                    style: TextStyle(color: kTextGrey)),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameCtl,
                  textCapitalization: TextCapitalization.words,
                  decoration: fieldDecoration('Nama', icon: Icons.person_outline),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Nama minimal 2 karakter'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: fieldDecoration('Email', icon: Icons.mail_outline),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Email wajib diisi';
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                      return 'Format email belum lengkap';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pwCtl,
                  obscureText: _hidePw,
                  decoration: fieldDecoration(
                    'Password',
                    icon: Icons.lock_outline,
                    hint: 'Minimal 8 karakter dan 1 angka',
                    suffix: IconButton(
                      icon: Icon(_hidePw
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () => setState(() => _hidePw = !_hidePw),
                    ),
                  ),
                  validator: (v) {
                    final s = v ?? '';
                    if (s.length < 8) return 'Password minimal 8 karakter';
                    if (!RegExp(r'\d').hasMatch(s)) {
                      return 'Password harus mengandung minimal 1 angka';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: kError)),
                ],
                const SizedBox(height: 28),
                FilledButton(onPressed: _register, child: const Text('Simpan Akun')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// BAGIAN 9: KERANGKA UTAMA (bottom navigation + tombol Scan Struk)
// ============================================================================

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _openScan() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(onSeeAll: () => setState(() => _index = 1)),
          const HistoryScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScan,
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.photo_camera_outlined),
        label: const Text('Scan Struk'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0x2212A37A),
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Beranda'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Riwayat'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profil'),
        ],
      ),
    );
  }
}

// ============================================================================
// BAGIAN 10: DASHBOARD
// ============================================================================

class DashboardScreen extends StatefulWidget {
  final VoidCallback onSeeAll;
  const DashboardScreen({super.key, required this.onSeeAll});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _isCurrentMonth {
    final n = DateTime.now();
    return _month.year == n.year && _month.month == n.month;
  }

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final name = store.current?.name.trim().split(' ').first ?? '';
          final recent = store.transactions.take(5).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              const Text('Selamat datang,', style: TextStyle(color: kTextGrey)),
              Text(name,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: kTextDark)),
              const SizedBox(height: 16),
              _totalCard(),
              const SizedBox(height: 16),
              _categoryCard(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Riwayat Transaksi Terakhir',
                      style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark)),
                  TextButton(onPressed: widget.onSeeAll, child: const Text('Lihat semua')),
                ],
              ),
              if (recent.isEmpty)
                const EmptyView(
                    message:
                    'Belum ada transaksi.\nTekan "Scan Struk" untuk mencatat pengeluaran pertama Anda.')
              else
                ...recent.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TxTile(
                    tx: t,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TxDetailScreen(tx: t))),
                  ),
                )),
            ],
          );
        },
      ),
    );
  }

  Widget _totalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [kPrimary, kPrimaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _shiftMonth(-1),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text('Pengeluaran ${monthLabel(_month)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70)),
              ),
              IconButton(
                onPressed: _isCurrentMonth ? null : () => _shiftMonth(1),
                icon: Icon(Icons.chevron_right,
                    color: _isCurrentMonth ? Colors.white24 : Colors.white),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(rupiah(store.monthTotal(_month)),
                style: const TextStyle(
                    color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _categoryCard() {
    final totals = store.categoryTotals(_month);
    final cats = totals.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sum = cats.fold<double>(0, (s, e) => s + e.value);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pengeluaran per Kategori',
              style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark)),
          const SizedBox(height: 12),
          if (cats.isEmpty)
            const Text('Belum ada data kategori pada bulan ini.',
                style: TextStyle(color: kTextGrey))
          else
            ...cats.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key),
                      Text(rupiah(e.value),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: sum == 0 ? 0 : e.value / sum,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    backgroundColor: const Color(0xFFE7EFED),
                    color: categoryColor(e.key),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

// ============================================================================
// BAGIAN 11: RIWAYAT & DETAIL TRANSAKSI
// ============================================================================

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'Semua';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = _filter == 'Semua'
              ? store.transactions
              : store.transactions.where((t) => t.category == _filter).toList();
          final total = list.fold<double>(0, (s, t) => s + t.total);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              const Text('Riwayat Transaksi',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: kTextDark)),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Semua', ...kCategories]
                      .map((c) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: _filter == c,
                      showCheckmark: false,
                      selectedColor: const Color(0x3312A37A),
                      onSelected: (_) => setState(() => _filter = c),
                    ),
                  ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              Text('${list.length} transaksi - ${rupiah(total)}',
                  style: const TextStyle(color: kTextGrey)),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const EmptyView(message: 'Tidak ada transaksi untuk ditampilkan.')
              else
                ...list.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TxTile(
                    tx: t,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => TxDetailScreen(tx: t))),
                  ),
                )),
            ],
          );
        },
      ),
    );
  }
}

class TxDetailScreen extends StatelessWidget {
  final Tx tx;
  const TxDetailScreen({super.key, required this.tx});

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: const Text('Transaksi ini akan dihapus dari perangkat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    store.deleteTransaction(tx.id);
    Navigator.of(context).pop();
    showMessage(context, 'Transaksi dihapus.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Transaksi')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.merchant,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700, color: kTextDark)),
                  const SizedBox(height: 4),
                  Text(fmtDate(tx.date), style: const TextStyle(color: kTextGrey)),
                  const SizedBox(height: 12),
                  Text(rupiah(tx.total),
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w700, color: kPrimaryDark)),
                  if (tx.manualEdit)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Dikoreksi manual oleh pengguna',
                          style: TextStyle(color: kTextGrey, fontSize: 12)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Daftar barang',
                style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark)),
            const SizedBox(height: 8),
            ...tx.items.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(categoryIcon(i.category), color: categoryColor(i.category)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                              i.probability == null
                                  ? i.category
                                  : '${i.category} - Naive Bayes ${(i.probability! * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(color: kTextGrey, fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(rupiah(i.price),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline, color: kError),
              label: const Text('Hapus Transaksi', style: TextStyle(color: kError)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BAGIAN 12: PROFIL & PENGATURAN
// ============================================================================

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<bool> _confirm(BuildContext context, String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final user = store.current;
          if (user == null) return const SizedBox.shrink();
          final initial = user.name.isEmpty ? '?' : user.name.trim()[0].toUpperCase();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              const Text('Pengaturan & Profil',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700, color: kTextDark)),
              const SizedBox(height: 16),
              AppCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: kPrimary,
                      child: Text(initial,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: kTextDark)),
                          Text(user.email, style: const TextStyle(color: kTextGrey)),
                          const SizedBox(height: 4),
                          Text('${store.transactions.length} transaksi tersimpan',
                              style: const TextStyle(color: kTextGrey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.delete_sweep_outlined, color: kPrimary),
                      title: const Text('Hapus semua transaksi'),
                      subtitle: const Text('Mengosongkan data milik akun ini'),
                      onTap: () async {
                        final ok = await _confirm(context, 'Hapus semua transaksi?',
                            'Semua transaksi akun ini akan dihapus dan tidak bisa dikembalikan.', 'Hapus');
                        if (ok) {
                          store.clearTransactions();
                          if (context.mounted) showMessage(context, 'Semua transaksi dihapus.');
                        }
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: kPrimary),
                      title: const Text('Tentang Aplikasi'),
                      subtitle: const Text('Versi mandiri (tanpa server)'),
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: 'SmartReceipt',
                        applicationVersion: '1.0.0-mandiri',
                        children: const [
                          Text(
                              'Pencatatan keuangan pribadi dengan parsing struk dan klasifikasi kategori TF-IDF + Naive Bayes. Seluruh data disimpan lokal di perangkat.'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await _confirm(context, 'Keluar dari akun?',
                      'Anda perlu login lagi untuk memakai SmartReceipt.', 'Logout');
                  if (ok) store.logout();
                },
                icon: const Icon(Icons.logout, color: kError),
                label: const Text('Logout', style: TextStyle(color: kError)),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDEEEE),
                  side: const BorderSide(color: Color(0xFFF3C8C8)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// BAGIAN 13: SCAN STRUK (versi mandiri: teks contoh / ketik / tempel)
// ============================================================================

String _todayText() {
  final n = DateTime.now();
  return '${two(n.day)}/${two(n.month)}/${n.year}';
}

/// Contoh teks struk; tanggalnya otomatis hari ini agar muncul di dashboard.
final Map<String, String Function()> kSampleReceipts = {
  'Minimarket': () =>
  'INDOMARET\nJl. Raya Malang\n${_todayText()}\nRoti Tawar 15.000\nAir Mineral 5.000\nSusu UHT 7.500\nTOTAL 27.500\nTUNAI 30.000\nKEMBALI 2.500',
  'Apotek': () =>
  'APOTEK K24\nJl. Veteran\n${_todayText()}\nParacetamol 500mg 8.000\nVitamin C 22.000\nMasker Medis 12.000\nTOTAL 42.000\nTUNAI 50.000',
  'SPBU': () =>
  'SPBU PERTAMINA\nJl. Soekarno Hatta\n${_todayText()}\nPertalite 5.2 L 52.000\nParkir Motor 2.000\nTOTAL 54.000',
};

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _textCtl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _textCtl.dispose();
    super.dispose();
  }

  void _process() {
    final text = _textCtl.text.trim();
    if (text.length < 10) {
      setState(() => _error = 'Teks struk terlalu pendek atau tidak jelas. Silakan ulangi.');
      return;
    }
    setState(() => _error = null);
    _openPreview(ReceiptParser.parse(text), text);
  }

  void _openPreview(ParsedReceipt parsed, String raw) {
    Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => PreviewScreen(parsed: parsed, rawText: raw),
    )).then((saved) {
      // Setelah tersimpan, tutup halaman scan dan kembali ke Beranda.
      if (saved == true && mounted) Navigator.of(context).pop();
    });
  }

  void _cameraInfo() => showMessage(context,
      'OCR kamera/galeri belum aktif di versi mandiri. Gunakan teks contoh atau ketik teks struk.');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pindai Struk')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Sumber struk',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: kTextDark)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cameraInfo,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _cameraInfo,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galeri'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Atau gunakan teks struk',
                style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark)),
            const SizedBox(height: 4),
            const Text('Pilih contoh, atau ketik/tempel teks hasil OCR struk.',
                style: TextStyle(color: kTextGrey, fontSize: 12)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: kSampleReceipts.entries
                  .map((e) => ActionChip(
                label: Text('Contoh: ${e.key}'),
                onPressed: () => setState(() {
                  _textCtl.text = e.value();
                  _error = null;
                }),
              ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textCtl,
              minLines: 8,
              maxLines: 14,
              keyboardType: TextInputType.multiline,
              decoration: fieldDecoration('Teks struk',
                  hint: 'Baris pertama = nama toko\nContoh: Roti Tawar 15.000')
                  .copyWith(errorText: _error),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _process, child: const Text('Proses Struk')),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => _openPreview(const ParsedReceipt(), ''),
              child: const Text('Isi Data Secara Manual'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BAGIAN 14: PRATINJAU & KOREKSI TRANSAKSI
// ============================================================================

class _ItemDraft {
  final TextEditingController name;
  final TextEditingController price;
  String? category;
  final double? probability;
  final String? origCategory; // kategori awal dari model
  final String origName;
  final double? origPrice;

  _ItemDraft.fromParsed(ParsedItem i)
      : name = TextEditingController(text: i.name),
        price = TextEditingController(text: i.price == null ? '' : plainNumber(i.price!)),
        category = i.category,
        probability = i.probability,
        origCategory = i.category,
        origName = i.name,
        origPrice = i.price;

  _ItemDraft.empty()
      : name = TextEditingController(),
        price = TextEditingController(),
        category = null,
        probability = null,
        origCategory = null,
        origName = '',
        origPrice = null;

  double? get priceValue => parseAmount(price.text);

  /// Probabilitas hanya tampil jika kategori masih hasil prediksi model.
  bool get showProbability =>
      probability != null && category != null && category == origCategory;

  bool get edited =>
      name.text.trim() != origName || priceValue != origPrice || category != origCategory;

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class PreviewScreen extends StatefulWidget {
  final ParsedReceipt parsed;
  final String rawText;
  const PreviewScreen({super.key, required this.parsed, required this.rawText});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchantCtl;
  late final TextEditingController _dateCtl;
  late final TextEditingController _totalCtl;
  late final List<_ItemDraft> _items;
  DateTime? _date;
  double _lastSum = 0;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final p = widget.parsed;
    _merchantCtl = TextEditingController(text: p.merchant ?? '');
    _date = p.date;
    _dateCtl = TextEditingController(text: _date == null ? '' : fmtDate(_date!));
    _totalCtl = TextEditingController(text: p.total == null ? '' : plainNumber(p.total!));
    _items = p.items.map(_ItemDraft.fromParsed).toList();
    _lastSum = _itemsSum;
  }

  @override
  void dispose() {
    _merchantCtl.dispose();
    _dateCtl.dispose();
    _totalCtl.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  /// Jumlah harga semua barang (dihitung ulang setiap perubahan).
  double get _itemsSum => _items.fold<double>(0, (s, i) => s + (i.priceValue ?? 0));

  void _onPriceChanged() {
    final newSum = _itemsSum;
    final total = parseAmount(_totalCtl.text);
    // Jika total sebelumnya sama dengan jumlah barang, ikut diperbarui.
    if (total == null || total == _lastSum) {
      _totalCtl.text = plainNumber(newSum);
    }
    _lastSum = newSum;
    setState(() {});
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateCtl.text = fmtDate(picked);
      });
    }
  }

  String _dominantCategory() {
    final totals = <String, double>{};
    for (final i in _items) {
      final c = i.category ?? 'Lainnya';
      totals[c] = (totals[c] ?? 0) + (i.priceValue ?? 0);
    }
    return totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  bool _isManualEdit(double total) {
    final p = widget.parsed;
    return _merchantCtl.text.trim() != (p.merchant ?? '') ||
        _date != p.date ||
        total != p.total ||
        _items.length != p.items.length ||
        _items.any((i) => i.edited);
  }

  void _save() {
    setState(() => _submitted = true);
    final formOk = _formKey.currentState!.validate();

    if (_items.isEmpty) {
      showMessage(context, 'Tambahkan minimal satu barang.', error: true);
      return;
    }
    if (!formOk || _items.any((i) => i.category == null)) {
      showMessage(context, 'Periksa kembali data yang belum lengkap.', error: true);
      return;
    }

    final total = parseAmount(_totalCtl.text)!;
    store.addTransaction(Tx(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      merchant: _merchantCtl.text.trim(),
      date: _date!,
      total: total,
      category: _dominantCategory(),
      manualEdit: _isManualEdit(total),
      items: _items
          .map((i) => TxItem(i.name.text.trim(), i.priceValue!, i.category!,
          i.showProbability ? i.probability : null))
          .toList(),
    ));

    showMessage(context, 'Transaksi berhasil disimpan.');
    Navigator.of(context).pop(true);
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pencatatan?'),
        content: const Text('Data struk ini tidak akan disimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Lanjut Edit')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Batalkan')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final total = parseAmount(_totalCtl.text);
    final sum = _itemsSum;
    final mismatch = _items.isNotEmpty && total != null && (total - sum).abs() > 0.5;
    final p = widget.parsed;
    final nothingRead =
        p.merchant == null && p.date == null && p.total == null && p.items.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Pratinjau & Validasi Data')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (nothingRead)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Tidak ada data yang terbaca otomatis. Silakan isi manual.',
                      style: TextStyle(color: kTextGrey)),
                ),
              const Text('Data transaksi',
                  style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark)),
              const Text('Periksa kembali hasil pemindaian sebelum disimpan.',
                  style: TextStyle(color: kTextGrey, fontSize: 12)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _merchantCtl,
                textCapitalization: TextCapitalization.words,
                decoration: fieldDecoration('Nama Merchant', icon: Icons.storefront_outlined),
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Nama merchant wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _dateCtl,
                readOnly: true,
                onTap: _pickDate,
                decoration: fieldDecoration('Tanggal Transaksi',
                    icon: Icons.calendar_today_outlined, hint: 'Ketuk untuk memilih tanggal'),
                validator: (v) => _date == null ? 'Tanggal transaksi wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _totalCtl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                onChanged: (_) => setState(() {}),
                decoration: fieldDecoration('Total Nominal', prefix: 'Rp '),
                validator: (v) {
                  final n = parseAmount(v ?? '');
                  if (n == null) return 'Total nominal wajib diisi';
                  if (n <= 0) return 'Total harus lebih dari 0';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Daftar barang',
                      style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark)),
                  Text('Jumlah item: ${rupiah(sum)}',
                      style: const TextStyle(color: kTextGrey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              if (mismatch)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E0), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            'Jumlah harga barang (${rupiah(sum)}) berbeda dengan total (${rupiah(total)}).',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () {
                          _totalCtl.text = plainNumber(sum);
                          _lastSum = sum;
                          setState(() {});
                        },
                        child: const Text('Samakan'),
                      ),
                    ],
                  ),
                ),
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Belum ada barang. Tambahkan barang secara manual.',
                      style: TextStyle(color: kTextGrey)),
                ),
              for (var i = 0; i < _items.length; i++) _buildItemCard(i),
              OutlinedButton.icon(
                onPressed: () => setState(() => _items.add(_ItemDraft.empty())),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Barang'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: _cancel, child: const Text('Batal'))),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(onPressed: _save, child: const Text('Simpan Transaksi')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.name,
                    decoration: fieldDecoration('Nama barang'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama barang wajib diisi' : null,
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus barang',
                  icon: const Icon(Icons.delete_outline, color: kError),
                  onPressed: () {
                    setState(() => _items.removeAt(index).dispose());
                    _onPriceChanged();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: item.price,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    onChanged: (_) => _onPriceChanged(),
                    decoration: fieldDecoration('Harga', prefix: 'Rp '),
                    validator: (v) {
                      final n = parseAmount(v ?? '');
                      if (n == null) return 'Harga wajib diisi';
                      if (n < 0) return 'Harga tidak valid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: CategoryPickerField(
                    value: item.category,
                    errorText:
                    (_submitted && item.category == null) ? 'Pilih kategori' : null,
                    onChanged: (c) => setState(() => item.category = c),
                  ),
                ),
              ],
            ),
            if (item.showProbability)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Naive Bayes: ${(item.probability! * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(color: kPrimaryDark, fontSize: 12)),
                ),
              )
            else if (item.origCategory == null)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Kategori belum dikenali, silakan pilih manual.',
                      style: TextStyle(color: kTextGrey, fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
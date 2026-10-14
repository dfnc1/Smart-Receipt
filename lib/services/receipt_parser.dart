import '../core/utils.dart';
import 'classifier.dart';

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

import 'tx_item.dart';

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

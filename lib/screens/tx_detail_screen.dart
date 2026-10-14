import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/tx.dart';
import '../services/app_store.dart';
import '../services/receipt_parser.dart';
import '../widgets/app_card.dart';
import '../widgets/field_decoration.dart';
import 'preview_screen.dart';

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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    store.deleteTransaction(tx.id);
    Navigator.of(context).pop();
    showMessage(context, 'Transaksi dihapus.');
  }

  Future<void> _edit(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          parsed: const ParsedReceipt(),
          rawText: '',
          editTx: tx, // kirim Tx asli untuk mode edit
        ),
      ),
    );
    if (saved == true && context.mounted) {
      Navigator.of(context).pop(); // kembali ke riwayat setelah disimpan
    }
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
                  Text(
                    tx.merchant,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(fmtDate(tx.date),
                      style: const TextStyle(color: kTextGrey)),
                  const SizedBox(height: 12),
                  Text(
                    rupiah(tx.total),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryDark,
                    ),
                  ),
                  if (tx.manualEdit)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Dikoreksi manual oleh pengguna',
                        style: TextStyle(color: kTextGrey, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Daftar barang',
              style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark),
            ),
            const SizedBox(height: 8),
            ...tx.items.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(categoryIcon(i.category),
                            color: categoryColor(i.category)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                i.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              Text(
                                i.probability == null
                                    ? i.category
                                    : '${i.category} - Naive Bayes ${(i.probability! * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(
                                    color: kTextGrey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          rupiah(i.price),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _edit(context),
                    icon: const Icon(Icons.edit_outlined, color: kPrimary),
                    label:
                        const Text('Edit', style: TextStyle(color: kPrimary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline, color: kError),
                    label: const Text('Hapus', style: TextStyle(color: kError)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../services/app_store.dart';
import '../widgets/empty_view.dart';
import '../widgets/field_decoration.dart';
import '../widgets/tx_tile.dart';
import 'tx_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'Semua';
  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final query = _searchCtl.text.trim().toLowerCase();
          final list = store.transactions.where((t) {
            final matchCat = _filter == 'Semua' || t.category == _filter;
            final matchQuery = query.isEmpty ||
                t.merchant.toLowerCase().contains(query) ||
                t.items.any((i) => i.name.toLowerCase().contains(query));
            return matchCat && matchQuery;
          }).toList();
          final total = list.fold<double>(0, (s, t) => s + t.total);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              const Text(
                'Riwayat Transaksi',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchCtl,
                onChanged: (_) => setState(() {}),
                decoration: fieldDecoration(
                  'Cari toko atau barang...',
                  icon: Icons.search,
                  suffix: _searchCtl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
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
              Text(
                '${list.length} transaksi - ${rupiah(total)}',
                style: const TextStyle(color: kTextGrey),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const EmptyView(
                    message: 'Tidak ada transaksi untuk ditampilkan.')
              else
                ...list.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TxTile(
                        tx: t,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TxDetailScreen(tx: t),
                          ),
                        ),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }
}

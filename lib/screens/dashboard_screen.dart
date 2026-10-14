import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../services/app_store.dart';
import '../widgets/app_card.dart';
import '../widgets/empty_view.dart';
import '../widgets/tx_tile.dart';
import 'tx_detail_screen.dart';

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
              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 16),
              _totalCard(),
              const SizedBox(height: 16),
              _categoryCard(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat Transaksi Terakhir',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: kTextDark,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onSeeAll,
                    child: const Text('Lihat semua'),
                  ),
                ],
              ),
              if (recent.isEmpty)
                const EmptyView(
                  message:
                      'Belum ada transaksi.\nTekan "Scan Struk" untuk mencatat pengeluaran pertama Anda.',
                )
              else
                ...recent.map((t) => Padding(
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

  Widget _totalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimary, kPrimaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                child: Text(
                  'Pengeluaran ${monthLabel(_month)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              IconButton(
                onPressed: _isCurrentMonth ? null : () => _shiftMonth(1),
                icon: Icon(
                  Icons.chevron_right,
                  color: _isCurrentMonth ? Colors.white24 : Colors.white,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              rupiah(store.monthTotal(_month)),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
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
          const Text(
            'Pengeluaran per Kategori',
            style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark),
          ),
          const SizedBox(height: 12),
          if (cats.isEmpty)
            const Text(
              'Belum ada data kategori pada bulan ini.',
              style: TextStyle(color: kTextGrey),
            )
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
                          Text(
                            rupiah(e.value),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
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

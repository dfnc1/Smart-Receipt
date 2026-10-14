import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../services/app_store.dart';
import '../widgets/app_card.dart';
import '../widgets/field_decoration.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<bool> _confirm(
      BuildContext context, String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
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
          final initial =
              user.name.isEmpty ? '?' : user.name.trim()[0].toUpperCase();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              const Text(
                'Pengaturan & Profil',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: kPrimary,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: kTextDark,
                            ),
                          ),
                          Text(user.email,
                              style: const TextStyle(color: kTextGrey)),
                          const SizedBox(height: 4),
                          Text(
                            '${store.transactions.length} transaksi tersimpan',
                            style: const TextStyle(
                              color: kTextGrey,
                              fontSize: 12,
                            ),
                          ),
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
                      leading: const Icon(Icons.delete_sweep_outlined,
                          color: kPrimary),
                      title: const Text('Hapus semua transaksi'),
                      subtitle: const Text('Mengosongkan data milik akun ini'),
                      onTap: () async {
                        final ok = await _confirm(
                          context,
                          'Hapus semua transaksi?',
                          'Semua transaksi akun ini akan dihapus dan tidak bisa dikembalikan.',
                          'Hapus',
                        );
                        if (ok) {
                          store.clearTransactions();
                          if (context.mounted) {
                            showMessage(context, 'Semua transaksi dihapus.');
                          }
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
                            'Pencatatan keuangan pribadi dengan parsing struk dan klasifikasi kategori TF-IDF + Naive Bayes. Seluruh data disimpan lokal di perangkat.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await _confirm(
                    context,
                    'Keluar dari akun?',
                    'Anda perlu login lagi untuk memakai SmartReceipt.',
                    'Logout',
                  );
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

import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_shell.dart';
import 'services/app_store.dart';

// Re-export model, service, dan helper agar tetap dapat diakses dari package:receipt/main.dart
export 'core/constants.dart';
export 'core/utils.dart';
export 'models/tx.dart';
export 'models/tx_item.dart';
export 'models/user_account.dart';
export 'services/app_store.dart';
export 'services/classifier.dart';
export 'services/receipt_parser.dart';

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: kTextDark,
            side: const BorderSide(color: kBorder),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
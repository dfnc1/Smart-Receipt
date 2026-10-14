import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/app_store.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/field_decoration.dart';
import 'register_screen.dart';

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
                const Text(
                  'Selamat datang kembali',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Kelola setiap struk dan pengeluaran dalam satu tempat yang rapi.',
                  style: TextStyle(color: kTextGrey),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _emailCtl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: fieldDecoration(
                    'Username/Email',
                    icon: Icons.mail_outline,
                    hint: 'nama@email.com',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Username/Email wajib diisi'
                      : null,
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
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
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
                      const Text(
                        'Belum punya akun? ',
                        style: TextStyle(color: kTextGrey),
                      ),
                      GestureDetector(
                        onTap: _openRegister,
                        child: const Text(
                          'Daftar di sini',
                          style: TextStyle(
                            color: kPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Data tersimpan hanya di perangkat ini.',
                    style: TextStyle(color: kTextGrey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

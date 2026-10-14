import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../services/app_store.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/field_decoration.dart';

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
  final _confirmPwCtl = TextEditingController();
  bool _hidePw = true;
  bool _hideConfirmPw = true;
  String? _error;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _pwCtl.dispose();
    _confirmPwCtl.dispose();
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
                const Text(
                  'Buat akun baru',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: kTextDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mulai catat pengeluaran tanpa repot mengetik ulang struk.',
                  style: TextStyle(color: kTextGrey),
                ),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPwCtl,
                  obscureText: _hideConfirmPw,
                  decoration: fieldDecoration(
                    'Konfirmasi Password',
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(_hideConfirmPw
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined),
                      onPressed: () =>
                          setState(() => _hideConfirmPw = !_hideConfirmPw),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Konfirmasi password wajib diisi';
                    }
                    if (v != _pwCtl.text) {
                      return 'Password tidak cocok';
                    }
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: kError)),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _register,
                  child: const Text('Simpan Akun'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

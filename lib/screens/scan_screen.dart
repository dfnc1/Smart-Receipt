import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../services/receipt_parser.dart';
import '../widgets/field_decoration.dart';
import 'preview_screen.dart';

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
      setState(() => _error =
          'Teks struk terlalu pendek atau tidak jelas. Silakan ulangi.');
      return;
    }
    setState(() => _error = null);
    _openPreview(ReceiptParser.parse(text), text);
  }

  void _openPreview(ParsedReceipt parsed, String raw) {
    Navigator.of(context)
        .push<bool>(MaterialPageRoute(
      builder: (_) => PreviewScreen(parsed: parsed, rawText: raw),
    ))
        .then((saved) {
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
            const Text(
              'Sumber struk',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: kTextDark,
              ),
            ),
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
            const Text(
              'Atau gunakan teks struk',
              style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pilih contoh, atau ketik/tempel teks hasil OCR struk.',
              style: TextStyle(color: kTextGrey, fontSize: 12),
            ),
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
                      hint:
                          'Baris pertama = nama toko\nContoh: Roti Tawar 15.000')
                  .copyWith(errorText: _error),
            ),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _process, child: const Text('Proses Struk')),
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

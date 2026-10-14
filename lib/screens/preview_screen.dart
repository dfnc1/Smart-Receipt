import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../models/tx.dart';
import '../models/tx_item.dart';
import '../services/app_store.dart';
import '../services/receipt_parser.dart';
import '../widgets/app_card.dart';
import '../widgets/category_picker_field.dart';
import '../widgets/field_decoration.dart';

const _uuid = Uuid();

class _ItemDraft {
  final TextEditingController name;
  final TextEditingController price;
  String? category;
  final double? probability;
  final String? origCategory; // kategori awal dari model
  final String origName;
  final double? origPrice;

  _ItemDraft.fromParsed(ParsedItem i)
      : name = TextEditingController(text: i.name),
        price = TextEditingController(
            text: i.price == null ? '' : plainNumber(i.price!)),
        category = i.category,
        probability = i.probability,
        origCategory = i.category,
        origName = i.name,
        origPrice = i.price;

  _ItemDraft.empty()
      : name = TextEditingController(),
        price = TextEditingController(),
        category = null,
        probability = null,
        origCategory = null,
        origName = '',
        origPrice = null;

  double? get priceValue => parseAmount(price.text);

  /// Probabilitas hanya tampil jika kategori masih hasil prediksi model.
  bool get showProbability =>
      probability != null && category != null && category == origCategory;

  bool get edited =>
      name.text.trim() != origName ||
      priceValue != origPrice ||
      category != origCategory;

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class PreviewScreen extends StatefulWidget {
  final ParsedReceipt parsed;
  final String rawText;
  final Tx? editTx; // null = mode tambah baru, non-null = mode edit

  const PreviewScreen({
    super.key,
    required this.parsed,
    required this.rawText,
    this.editTx,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchantCtl;
  late final TextEditingController _dateCtl;
  late final TextEditingController _totalCtl;
  late final List<_ItemDraft> _items;
  DateTime? _date;
  double _lastSum = 0;
  bool _submitted = false;

  bool get _isEditMode => widget.editTx != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final tx = widget.editTx!;
      _merchantCtl = TextEditingController(text: tx.merchant);
      _date = tx.date;
      _dateCtl = TextEditingController(text: fmtDate(tx.date));
      _totalCtl = TextEditingController(text: plainNumber(tx.total));
      _items = tx.items
          .map((i) => _ItemDraft.fromParsed(
              ParsedItem(i.name, i.price, i.category, i.probability)))
          .toList();
    } else {
      final p = widget.parsed;
      _merchantCtl = TextEditingController(text: p.merchant ?? '');
      _date = p.date;
      _dateCtl =
          TextEditingController(text: _date == null ? '' : fmtDate(_date!));
      _totalCtl =
          TextEditingController(text: p.total == null ? '' : plainNumber(p.total!));
      _items = p.items.map(_ItemDraft.fromParsed).toList();
    }
    _lastSum = _itemsSum;
  }

  @override
  void dispose() {
    _merchantCtl.dispose();
    _dateCtl.dispose();
    _totalCtl.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  /// Jumlah harga semua barang (dihitung ulang setiap perubahan).
  double get _itemsSum =>
      _items.fold<double>(0, (s, i) => s + (i.priceValue ?? 0));

  void _onPriceChanged() {
    final newSum = _itemsSum;
    final total = parseAmount(_totalCtl.text);
    // Jika total sebelumnya sama dengan jumlah barang, ikut diperbarui.
    if (total == null || total == _lastSum) {
      _totalCtl.text = plainNumber(newSum);
    }
    _lastSum = newSum;
    setState(() {});
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateCtl.text = fmtDate(picked);
      });
    }
  }

  String _dominantCategory() {
    final totals = <String, double>{};
    for (final i in _items) {
      final c = i.category ?? 'Lainnya';
      totals[c] = (totals[c] ?? 0) + (i.priceValue ?? 0);
    }
    if (totals.isEmpty) return 'Lainnya';
    return totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  bool _isManualEdit(double total) {
    final p = widget.parsed;
    return _merchantCtl.text.trim() != (p.merchant ?? '') ||
        _date != p.date ||
        total != p.total ||
        _items.length != p.items.length ||
        _items.any((i) => i.edited);
  }

  void _save() {
    setState(() => _submitted = true);
    final formOk = _formKey.currentState!.validate();

    if (_items.isEmpty) {
      showMessage(context, 'Tambahkan minimal satu barang.', error: true);
      return;
    }
    if (!formOk || _items.any((i) => i.category == null)) {
      showMessage(context, 'Periksa kembali data yang belum lengkap.',
          error: true);
      return;
    }
    if (_date == null) {
      showMessage(context, 'Tanggal transaksi wajib diisi.', error: true);
      return;
    }

    final total = parseAmount(_totalCtl.text)!;
    final newTx = Tx(
      id: _isEditMode ? widget.editTx!.id : _uuid.v4(),
      merchant: _merchantCtl.text.trim(),
      date: _date!,
      total: total,
      category: _dominantCategory(),
      manualEdit: _isManualEdit(total),
      items: _items
          .map((i) => TxItem(i.name.text.trim(), i.priceValue!, i.category!,
              i.showProbability ? i.probability : null))
          .toList(),
    );

    if (_isEditMode) {
      store.updateTransaction(newTx);
      showMessage(context, 'Transaksi berhasil diperbarui.');
    } else {
      store.addTransaction(newTx);
      showMessage(context, 'Transaksi berhasil disimpan.');
    }
    Navigator.of(context).pop(true);
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pencatatan?'),
        content: const Text('Data struk ini tidak akan disimpan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Lanjut Edit')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Batalkan')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final total = parseAmount(_totalCtl.text);
    final sum = _itemsSum;
    final mismatch =
        _items.isNotEmpty && total != null && (total - sum).abs() > 0.5;
    final p = widget.parsed;
    final nothingRead =
        p.merchant == null && p.date == null && p.total == null && p.items.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Transaksi' : 'Pratinjau & Validasi Data'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (nothingRead)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                      'Tidak ada data yang terbaca otomatis. Silakan isi manual.',
                      style: TextStyle(color: kTextGrey)),
                ),
              const Text('Data transaksi',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, color: kTextDark)),
              const Text('Periksa kembali hasil pemindaian sebelum disimpan.',
                  style: TextStyle(color: kTextGrey, fontSize: 12)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _merchantCtl,
                textCapitalization: TextCapitalization.words,
                decoration: fieldDecoration('Nama Merchant',
                    icon: Icons.storefront_outlined),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama merchant wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _dateCtl,
                readOnly: true,
                onTap: _pickDate,
                decoration: fieldDecoration('Tanggal Transaksi',
                    icon: Icons.calendar_today_outlined,
                    hint: 'Ketuk untuk memilih tanggal'),
                validator: (v) =>
                    _date == null ? 'Tanggal transaksi wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _totalCtl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                ],
                onChanged: (_) => setState(() {}),
                decoration: fieldDecoration('Total Nominal', prefix: 'Rp '),
                validator: (v) {
                  final n = parseAmount(v ?? '');
                  if (n == null) return 'Total nominal wajib diisi';
                  if (n <= 0) return 'Total harus lebih dari 0';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Daftar barang',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: kTextDark)),
                  Text('Jumlah item: ${rupiah(sum)}',
                      style: const TextStyle(color: kTextGrey, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              if (mismatch)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E0),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            'Jumlah harga barang (${rupiah(sum)}) berbeda dengan total (${rupiah(total)}).',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () {
                          _totalCtl.text = plainNumber(sum);
                          _lastSum = sum;
                          setState(() {});
                        },
                        child: const Text('Samakan'),
                      ),
                    ],
                  ),
                ),
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                      'Belum ada barang. Tambahkan barang secara manual.',
                      style: TextStyle(color: kTextGrey)),
                ),
              for (var i = 0; i < _items.length; i++) _buildItemCard(i),
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _items.add(_ItemDraft.empty())),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Barang'),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                          onPressed: _cancel, child: const Text('Batal'))),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                        onPressed: _save,
                        child: const Text('Simpan Transaksi')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.name,
                    decoration: fieldDecoration('Nama barang'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nama barang wajib diisi'
                        : null,
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus barang',
                  icon: const Icon(Icons.delete_outline, color: kError),
                  onPressed: () {
                    setState(() => _items.removeAt(index).dispose());
                    _onPriceChanged();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: TextFormField(
                    controller: item.price,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                    ],
                    onChanged: (_) => _onPriceChanged(),
                    decoration: fieldDecoration('Harga', prefix: 'Rp '),
                    validator: (v) {
                      final n = parseAmount(v ?? '');
                      if (n == null) return 'Harga wajib diisi';
                      if (n < 0) return 'Harga tidak valid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 6,
                  child: CategoryPickerField(
                    value: item.category,
                    errorText: (_submitted && item.category == null)
                        ? 'Pilih kategori'
                        : null,
                    onChanged: (c) => setState(() => item.category = c),
                  ),
                ),
              ],
            ),
            if (item.showProbability)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      'Naive Bayes: ${(item.probability! * 100).toStringAsFixed(1)}%',
                      style:
                          const TextStyle(color: kPrimaryDark, fontSize: 12)),
                ),
              )
            else if (item.origCategory == null)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                      'Kategori belum dikenali, silakan pilih manual.',
                      style: TextStyle(color: kTextGrey, fontSize: 12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

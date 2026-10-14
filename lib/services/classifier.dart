import 'dart:math' as math;

/// Data latih contoh (kecil). Tambah kata di sini agar model makin pintar.
const Map<String, List<String>> kTrainingData = {
  'Konsumsi': [
    'roti tawar', 'roti coklat', 'air mineral', 'susu uht', 'susu', 'kopi',
    'teh botol', 'nasi goreng', 'ayam goreng', 'mie instan', 'indomie',
    'biskuit', 'snack keripik', 'coklat', 'telur', 'gula pasir', 'es jeruk',
    'jus alpukat', 'burger', 'pizza', 'makan siang', 'minuman', 'permen',
    'beras', 'minyak goreng', 'yogurt', 'keju', 'sosis',
  ],
  'Transportasi': [
    'pertalite', 'pertamax', 'solar', 'bensin', 'bbm', 'parkir motor',
    'parkir mobil', 'parkir', 'tol', 'ojek online', 'grab', 'gojek',
    'tiket kereta', 'tiket bus', 'angkot', 'oli mesin', 'servis motor',
    'travel', 'taksi',
  ],
  'Kesehatan': [
    'paracetamol', 'obat batuk', 'obat flu', 'vitamin', 'masker medis',
    'antiseptik', 'betadine', 'plester', 'sirup obat', 'tablet', 'kapsul',
    'salep', 'minyak kayu putih', 'hand sanitizer', 'termometer',
    'antibiotik', 'obat maag',
  ],
  'Belanja': [
    'sabun mandi', 'shampoo', 'deterjen', 'tisu', 'kaos', 'baju', 'sepatu',
    'tas', 'pulpen', 'buku tulis', 'sandal', 'pasta gigi', 'handuk',
    'lampu', 'baterai', 'sikat gigi', 'pembersih lantai', 'celana',
  ],
  'Lainnya': [
    'donasi', 'biaya admin', 'pulsa', 'token listrik', 'pajak', 'denda',
    'iuran', 'zakat', 'infaq', 'biaya layanan', 'materai',
  ],
};

class ClassResult {
  final String? category;
  final double? probability;
  const ClassResult(this.category, this.probability);
}

class NaiveBayesClassifier {
  final Map<String, double> _idf = {};
  final Map<String, Map<String, double>> _classWeights = {};
  final Map<String, double> _classTotal = {};
  final Map<String, int> _classDocs = {};
  int _docCount = 0;

  /// Preprocessing: huruf kecil, buang angka/simbol, token minimal 2 huruf.
  static List<String> tokenize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((t) => t.length >= 2)
      .toList();

  /// Pelatihan: hitung IDF, lalu akumulasi bobot TF-IDF per kelas.
  void train(Map<String, List<String>> data) {
    final docs = <MapEntry<String, List<String>>>[];
    final df = <String, int>{};

    data.forEach((label, texts) {
      for (final t in texts) {
        final tokens = tokenize(t);
        if (tokens.isEmpty) continue;
        docs.add(MapEntry(label, tokens));
        for (final term in tokens.toSet()) {
          df[term] = (df[term] ?? 0) + 1;
        }
      }
    });

    _docCount = docs.length;
    // IDF = ln((1+N)/(1+df)) + 1
    df.forEach((term, d) {
      _idf[term] = math.log((1 + _docCount) / (1 + d)) + 1;
    });

    for (final doc in docs) {
      final counts = <String, int>{};
      for (final t in doc.value) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
      final weights = _classWeights.putIfAbsent(doc.key, () => {});
      counts.forEach((term, c) {
        final w = (c / doc.value.length) * _idf[term]!; // TF x IDF
        weights[term] = (weights[term] ?? 0) + w;
        _classTotal[doc.key] = (_classTotal[doc.key] ?? 0) + w;
      });
      _classDocs[doc.key] = (_classDocs[doc.key] ?? 0) + 1;
    }
  }

  /// Prediksi kategori. Mengembalikan null jika kata tidak dikenal atau
  /// probabilitas terlalu rendah (tidak menebak asal).
  ClassResult predict(String text) {
    final known = tokenize(text).where(_idf.containsKey).toList();
    if (known.isEmpty || _docCount == 0) return const ClassResult(null, null);

    final counts = <String, int>{};
    for (final t in known) {
      counts[t] = (counts[t] ?? 0) + 1;
    }

    final vocab = _idf.length;
    final scores = <String, double>{};
    _classWeights.forEach((label, weights) {
      var score = math.log(_classDocs[label]! / _docCount); // prior
      counts.forEach((term, c) {
        final x = (c / known.length) * _idf[term]!;
        // Likelihood dengan Laplace smoothing
        score += x * math.log(((weights[term] ?? 0) + 1) / (_classTotal[label]! + vocab));
      });
      scores[label] = score;
    });

    // Softmax -> probabilitas
    final maxScore = scores.values.reduce(math.max);
    final exps = scores.map((k, v) => MapEntry(k, math.exp(v - maxScore)));
    final sum = exps.values.fold<double>(0, (a, b) => a + b);
    final best = exps.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final prob = best.value / sum;

    if (prob < 0.4) return const ClassResult(null, null);
    return ClassResult(best.key, prob);
  }
}

/// Satu instance model untuk seluruh aplikasi (dilatih saat aplikasi dibuka).
final NaiveBayesClassifier classifier = NaiveBayesClassifier()..train(kTrainingData);

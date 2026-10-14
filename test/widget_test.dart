// Widget tests untuk SmartReceipt
//
// Jalankan dengan: flutter test

import 'package:flutter_test/flutter_test.dart';

import 'package:receipt/main.dart';

void main() {
  // Inisialisasi classifier sebelum test
  setUpAll(() {
    classifier.train(kTrainingData);
  });

  group('NaiveBayesClassifier', () {
    test('mengklasifikasikan makanan ke Konsumsi', () {
      final result = classifier.predict('roti tawar');
      expect(result.category, equals('Konsumsi'));
    });

    test('mengklasifikasikan bensin ke Transportasi', () {
      final result = classifier.predict('pertalite');
      expect(result.category, equals('Transportasi'));
    });

    test('mengklasifikasikan obat ke Kesehatan', () {
      final result = classifier.predict('paracetamol');
      expect(result.category, equals('Kesehatan'));
    });

    test('mengembalikan null untuk kata tidak dikenal', () {
      final result = classifier.predict('xyzabcunknownword123');
      expect(result.category, isNull);
    });
  });

  group('ReceiptParser', () {
    test('mem-parsing merchant dari baris pertama berisi huruf', () {
      const text = 'INDOMARET\n12/10/2024\nRoti Tawar 15000\nTOTAL 15000';
      final result = ReceiptParser.parse(text);
      expect(result.merchant, equals('INDOMARET'));
    });

    test('mem-parsing total dari baris yang mengandung TOTAL', () {
      const text = 'INDOMARET\n12/10/2024\nRoti Tawar 15000\nTOTAL 15000';
      final result = ReceiptParser.parse(text);
      expect(result.total, equals(15000));
    });

    test('mem-parsing tanggal dengan format dd/mm/yyyy', () {
      const text = 'TOKO\n14/10/2024\nBarang 5000\nTOTAL 5000';
      final result = ReceiptParser.parse(text);
      expect(result.date, isNotNull);
      expect(result.date!.day, equals(14));
      expect(result.date!.month, equals(10));
      expect(result.date!.year, equals(2024));
    });

    test('mem-parsing item barang dengan benar', () {
      const text = 'TOKO\n14/10/2024\nRoti Tawar 15000\nTOTAL 15000';
      final result = ReceiptParser.parse(text);
      expect(result.items, isNotEmpty);
      expect(result.items.first.name, equals('Roti Tawar'));
      expect(result.items.first.price, equals(15000));
    });
  });

  group('hashPassword', () {
    test('hash yang sama untuk input yang sama', () {
      final h1 = hashPassword('password123', 'test@email.com');
      final h2 = hashPassword('password123', 'test@email.com');
      expect(h1, equals(h2));
    });

    test('hash berbeda untuk password berbeda', () {
      final h1 = hashPassword('password123', 'test@email.com');
      final h2 = hashPassword('password456', 'test@email.com');
      expect(h1, isNot(equals(h2)));
    });

    test('hash berbeda untuk email berbeda', () {
      final h1 = hashPassword('password123', 'user1@email.com');
      final h2 = hashPassword('password123', 'user2@email.com');
      expect(h1, isNot(equals(h2)));
    });

    test('menghasilkan string SHA-256 (64 karakter hex)', () {
      final h = hashPassword('test', 'test@email.com');
      expect(h.length, equals(64));
    });
  });

  group('parseAmount', () {
    test('mem-parsing angka biasa', () {
      expect(parseAmount('15000'), equals(15000));
    });

    test('mem-parsing angka dengan titik ribuan', () {
      expect(parseAmount('15.000'), equals(15000));
    });

    test('mem-parsing angka dengan prefix Rp', () {
      expect(parseAmount('Rp 15.000'), equals(15000));
    });

    test('mengembalikan null untuk input kosong', () {
      expect(parseAmount(''), isNull);
    });
  });
}

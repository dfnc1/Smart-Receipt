# 🧾 SmartReceipt

Aplikasi mobile untuk mencatat dan mengelola struk belanja secara mandiri (offline), dibangun dengan **Flutter**.

---

## ✨ Fitur Utama

- **Otentikasi Lokal:** Registrasi dan login tersimpan di perangkat menggunakan `shared_preferences` dengan hashing password SHA-256 via package `crypto`.
- **Smart Parsing Struk (Regex):** Otomatis mengekstrak nama merchant/toko, tanggal transaksi, total belanja, dan daftar barang.
- **Klasifikasi Kategori Otomatis:** Menggunakan algoritma **TF-IDF + Multinomial Naive Bayes** yang diimplementasikan langsung dalam Dart.
- **Pratinjau & Validasi Data:** Pengguna dapat meninjau, mengoreksi, menambah, mengedit, atau menghapus barang sebelum dan sesudah disimpan.
- **Edit & Hapus Transaksi:** Transaksi yang sudah tersimpan dapat diedit kembali atau dihapus.
- **Pencarian & Filter:** Filter berdasarkan kategori dan pencarian nama merchant/barang di halaman Riwayat.
- **Dashboard Ringkasan:** Menampilkan total pengeluaran bulanan dan grafik pengeluaran per kategori.

---

## 📦 Dependencies

- `shared_preferences` — Penyimpanan sesi dan data transaksi lokal
- `crypto` — Hashing password yang aman (SHA-256)
- `uuid` — Pembuatan ID transaksi unik (UUID v4)
- `cupertino_icons` — Icon pendukung

---

## 🚀 Cara Menjalankan

```bash
# 1. Unduh dependencies
flutter pub get

# 2. Jalankan unit/widget test
flutter test

# 3. Jalankan aplikasi
flutter run
```

---

> Proyek mata kuliah Mobile Teori — Semester 5

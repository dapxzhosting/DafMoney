# DafMoney - Tahap 1-7

Tahap 1-2: fondasi + autentikasi. Tahap 3-6: dashboard, transaksi, kategori, anggaran, laporan.
Tidak ada dependensi baru dibanding Tahap 2.

## Cara pakai
1. Salin isi zip ini ke proyek (timpa lib/ dan firestore.rules). lib/firebase_options.dart tetap milik Anda.
2. flutter pub get
3. Deploy aturan keamanan BARU (wajib, aturan lama menolak koleksi data):
   firebase deploy --only firestore:rules --project <id-proyek>
4. flutter run

Tidak perlu membuat index Firestore.

## Catatan
- Saldo total dihitung realtime dari semua transaksi (tanpa index).
- Ekspor laporan: tombol unduh di Laporan menyalin CSV ke clipboard (tanpa paket tambahan).
- Kategori bawaan dibuat otomatis saat pertama kali masuk.
- Kategori yang masih dipakai transaksi tidak bisa dihapus.
- Satu anggaran per kategori per bulan.

## Checklist pengujian
- [ ] Masuk -> 12 kategori bawaan muncul (Pengaturan > Kelola kategori)
- [ ] Tambah pengeluaran & pemasukan -> saldo, ringkasan, grafik di Beranda berubah
- [ ] Ubah dan hapus transaksi (geser ke kiri atau tombol hapus di form)
- [ ] Cari dan filter di tab Transaksi; pindah bulan
- [ ] Buat anggaran -> progres naik saat menambah pengeluaran kategori itu
- [ ] Laporan: ganti periode (termasuk Kustom), toggle rincian, salin CSV
- [ ] Ganti tema terang/gelap di Pengaturan

## Tahap 7 - Pengaturan
Profil (ubah nama), saldo awal, kelola kategori, tema, ubah kata sandi, salin semua transaksi (CSV),
hapus semua transaksi, keluar, hapus akun, tentang aplikasi.
WAJIB publish ulang firestore.rules (ada perubahan untuk saldo awal dan hapus akun).

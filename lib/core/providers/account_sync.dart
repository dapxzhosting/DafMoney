import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/transactions/data/transaction_repository.dart'
    show writeSafe;
import 'firebase_providers.dart';

/// Data dokumen akun (`users/{uid}`) yang SUDAH termuat, atau null bila belum
/// dimuat / belum ada.
///
/// `ref.listen` hanya terpanggil saat nilai BERUBAH. Kalau stream dokumen akun
/// sudah memuat data sebelum sebuah provider dibuat (mis. tantangan yang baru
/// dibuat saat Beranda dibuka), listener tidak pernah terpanggil untuk nilai
/// itu dan pengaturan akun tidak ikut pulih. Provider harus memanggil fungsi
/// ini di `build()` untuk mengambil nilai yang sudah ada.
Map<String, dynamic>? loadedUserData(Ref ref, String uid) =>
    ref.read(userDocStreamProvider(uid)).valueOrNull?.data();

/// Menyimpan pengaturan ke dokumen akun (gabung, tidak menimpa field lain).
/// Best-effort: gagal (offline / ditolak aturan) tidak boleh merusak UI, nilai
/// lokal tetap tersimpan di perangkat.
Future<void> syncToAccount(
  FirebaseFirestore db,
  String uid,
  Map<String, Object?> data,
) async {
  try {
    await writeSafe(
      () => db.collection('users').doc(uid).set(data, SetOptions(merge: true)),
    );
  } catch (e) {
    debugPrint('syncToAccount gagal: $e');
  }
}

/// True bila snapshot ini sudah dipastikan dari server dan tidak ada
/// penulisan lokal yang menunggu terkirim.
bool isSettledServerSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) =>
    !snap.metadata.isFromCache && !snap.metadata.hasPendingWrites;

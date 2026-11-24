import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/error/app_exception.dart';

class BackupPreview {
  const BackupPreview({required this.counts, required this.exportedAt});

  final Map<String, int> counts;
  final DateTime? exportedAt;

  int get total => counts.values.fold(0, (a, b) => a + b);
}

class BackupResult {
  const BackupResult({
    required this.added,
    required this.skipped,
    required this.invalid,
  });

  final int added;
  final int skipped;
  final int invalid;
}

class BackupService {
  BackupService(this._db);

  final FirebaseFirestore _db;

  static const _format = 'dafmoney-backup';
  static const _version = 1;
  static const _maxMoney = 100000000000;

  static const collections = [
    'categories',
    'wallets',
    'transactions',
    'budgets',
    'recurring',
    'transfers',
    'goals',
    'debts',
  ];

  static const labels = {
    'categories': 'kategori',
    'wallets': 'dompet',
    'transactions': 'transaksi',
    'budgets': 'anggaran',
    'recurring': 'transaksi berulang',
    'transfers': 'transfer',
    'goals': 'target tabungan',
    'debts': 'utang & piutang',
  };

  Object? _encode(Object? v) {
    if (v is Timestamp) return {'@t': v.millisecondsSinceEpoch};
    if (v is Map) {
      return {for (final e in v.entries) e.key.toString(): _encode(e.value)};
    }
    if (v is List) return [for (final e in v) _encode(e)];
    return v;
  }

  Future<Uint8List> export(String uid) async {
    final user = _db.collection('users').doc(uid);
    final data = <String, Object?>{};
    for (final name in collections) {
      final snap = await user.collection(name).get();
      data[name] = [
        for (final d in snap.docs) {'id': d.id, 'fields': _encode(d.data())},
      ];
    }
    final out = {
      'format': _format,
      'version': _version,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'data': data,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(out)));
  }

  Map<String, dynamic> _parse(Uint8List bytes) {
    Object? raw;
    try {
      raw = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const AppException('Berkas backup tidak valid.');
    }
    if (raw is! Map || raw['format'] != _format || raw['data'] is! Map) {
      throw const AppException('Berkas ini bukan backup DafMoney.');
    }
    final version = raw['version'];
    if (version is! int || version > _version) {
      throw const AppException(
        'Versi backup tidak didukung. Perbarui aplikasi dulu.',
      );
    }
    return Map<String, dynamic>.from(raw);
  }

  BackupPreview preview(Uint8List bytes) {
    final root = _parse(bytes);
    final data = root['data'] as Map;
    final counts = <String, int>{};
    for (final name in collections) {
      final list = data[name];
      if (list is List && list.isNotEmpty) counts[name] = list.length;
    }
    return BackupPreview(
      counts: counts,
      exportedAt: DateTime.tryParse('${root['exportedAt'] ?? ''}')?.toLocal(),
    );
  }

  Future<BackupResult> restore(
    String uid,
    Uint8List bytes, {
    void Function(int done, int total)? onProgress,
  }) async {
    final root = _parse(bytes);
    final data = root['data'] as Map;
    final user = _db.collection('users').doc(uid);
    final pending = <({DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> fields})>[];
    var skipped = 0;
    var invalid = 0;

    for (final name in collections) {
      final list = data[name];
      if (list is! List || list.isEmpty) continue;
      final col = user.collection(name);
      final existing = {for (final d in (await col.get()).docs) d.id};
      final seen = <String>{};
      for (final item in list) {
        if (item is! Map) {
          invalid++;
          continue;
        }
        final id = item['id'];
        final fields = item['fields'];
        if (id is! String ||
            id.isEmpty ||
            id.length > 100 ||
            id.contains('/') ||
            fields is! Map) {
          invalid++;
          continue;
        }
        if (existing.contains(id) || !seen.add(id)) {
          skipped++;
          continue;
        }
        final clean = _sanitize(name, id, Map<String, dynamic>.from(fields));
        if (clean == null) {
          invalid++;
          continue;
        }
        pending.add((ref: col.doc(id), fields: clean));
      }
    }

    var done = 0;
    for (var i = 0; i < pending.length; i += 400) {
      final chunk = pending.sublist(i, math.min(i + 400, pending.length));
      final batch = _db.batch();
      for (final p in chunk) {
        batch.set(p.ref, p.fields);
      }
      await batch.commit();
      done += chunk.length;
      onProgress?.call(done, pending.length);
    }
    return BackupResult(added: done, skipped: skipped, invalid: invalid);
  }

  int? _int(Object? v) {
    if (v is int) return v;
    if (v is num && v == v.truncateToDouble()) return v.toInt();
    return null;
  }

  int? _money(Object? v, {int min = 1, int? max}) {
    final n = _int(v);
    if (n == null || n < min || n > (max ?? _maxMoney)) return null;
    return n;
  }

  String? _text(Object? v, int max, {bool allowEmpty = false}) {
    if (v is! String) return null;
    if (!allowEmpty && v.isEmpty) return null;
    return v.length > max ? v.substring(0, max) : v;
  }

  String? _ref(Object? v) {
    if (v is! String || v.isEmpty || v.length > 60) return null;
    return v;
  }

  String? _oneOf(Object? v, List<String> allowed) =>
      v is String && allowed.contains(v) ? v : null;

  Timestamp? _ts(Object? v) {
    if (v is Map && v['@t'] is int) {
      return Timestamp.fromMillisecondsSinceEpoch(v['@t'] as int);
    }
    return null;
  }

  Map<String, dynamic>? _sanitize(
    String name,
    String id,
    Map<String, dynamic> f,
  ) {
    switch (name) {
      case 'categories':
        return _category(f);
      case 'wallets':
        return _wallet(f);
      case 'transactions':
        return _transaction(f);
      case 'budgets':
        return _budget(id, f);
      case 'recurring':
        return _recurring(f);
      case 'transfers':
        return _transfer(f);
      case 'goals':
        return _goal(f);
      case 'debts':
        return _debt(f);
    }
    return null;
  }

  Map<String, dynamic>? _category(Map<String, dynamic> f) {
    final name = _text(f['name'], 40);
    final type = _oneOf(f['type'], const ['income', 'expense']);
    final icon = _text(f['icon'], 30, allowEmpty: true);
    final color = _int(f['color']);
    if (name == null || type == null || icon == null || color == null) {
      return null;
    }
    return {
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic>? _wallet(Map<String, dynamic> f) {
    final name = _text(f['name'], 40);
    final icon = _text(f['icon'], 30, allowEmpty: true);
    final color = _int(f['color']);
    final initial = _money(f['initialBalance'] ?? 0, min: 0);
    if (name == null || icon == null || color == null || initial == null) {
      return null;
    }
    return {
      'name': name,
      'icon': icon,
      'color': color,
      'initialBalance': initial,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic>? _transaction(Map<String, dynamic> f) {
    final type = _oneOf(f['type'], const ['income', 'expense']);
    final amount = _money(f['amount']);
    final categoryId = _ref(f['categoryId']);
    final note = _text(f['note'] ?? '', 200, allowEmpty: true);
    final date = _ts(f['date']);
    if (type == null ||
        amount == null ||
        categoryId == null ||
        note == null ||
        date == null) {
      return null;
    }
    final walletId = _ref(f['walletId']);
    final recurringId = _ref(f['recurringId']);
    return {
      'type': type,
      'amount': amount,
      'categoryId': categoryId,
      'note': note,
      'date': date,
      'createdAt': FieldValue.serverTimestamp(),
      if (walletId != null) 'walletId': walletId,
      if (recurringId != null) 'recurringId': recurringId,
    };
  }

  Map<String, dynamic>? _budget(String id, Map<String, dynamic> f) {
    final categoryId = _ref(f['categoryId']);
    final amount = _money(f['amount']);
    final month = f['month'];
    if (categoryId == null ||
        amount == null ||
        month is! String ||
        !RegExp(r'^[0-9]{4}-[0-9]{2}$').hasMatch(month) ||
        id != '${month}_$categoryId') {
      return null;
    }
    return {
      'categoryId': categoryId,
      'amount': amount,
      'month': month,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic>? _recurring(Map<String, dynamic> f) {
    final type = _oneOf(f['type'], const ['income', 'expense']);
    final amount = _money(f['amount']);
    final categoryId = _ref(f['categoryId']);
    final note = _text(f['note'] ?? '', 200, allowEmpty: true);
    final frequency = _oneOf(
      f['frequency'],
      const ['daily', 'weekly', 'monthly', 'yearly'],
    );
    final startDate = _ts(f['startDate']);
    final nextDate = _ts(f['nextDate']);
    final anchor = _int(f['anchorDay']);
    final active = f['active'];
    if (type == null ||
        amount == null ||
        categoryId == null ||
        note == null ||
        frequency == null ||
        startDate == null ||
        nextDate == null ||
        anchor == null ||
        anchor < 1 ||
        anchor > 31 ||
        active is! bool) {
      return null;
    }
    final walletId = _ref(f['walletId']);
    return {
      'type': type,
      'amount': amount,
      'categoryId': categoryId,
      'note': note,
      'frequency': frequency,
      'startDate': startDate,
      'nextDate': nextDate,
      'anchorDay': anchor,
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
      if (walletId != null) 'walletId': walletId,
    };
  }

  Map<String, dynamic>? _transfer(Map<String, dynamic> f) {
    final from = _ref(f['fromWalletId']);
    final to = _ref(f['toWalletId']);
    final amount = _money(f['amount']);
    final note = _text(f['note'] ?? '', 200, allowEmpty: true);
    final date = _ts(f['date']);
    if (from == null ||
        to == null ||
        from == to ||
        amount == null ||
        note == null ||
        date == null) {
      return null;
    }
    return {
      'fromWalletId': from,
      'toWalletId': to,
      'amount': amount,
      'note': note,
      'date': date,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic>? _goal(Map<String, dynamic> f) {
    final name = _text(f['name'], 40);
    final icon = _text(f['icon'], 30, allowEmpty: true);
    final color = _int(f['color']);
    final target = _money(f['target']);
    final saved = _money(f['saved'] ?? 0, min: 0);
    if (name == null ||
        icon == null ||
        color == null ||
        target == null ||
        saved == null) {
      return null;
    }
    final rawDeadline = f['deadline'];
    final deadline = _ts(rawDeadline);
    if (rawDeadline != null && deadline == null) return null;
    return {
      'name': name,
      'icon': icon,
      'color': color,
      'target': target,
      'saved': saved,
      'createdAt': FieldValue.serverTimestamp(),
      if (deadline != null) 'deadline': deadline,
    };
  }

  Map<String, dynamic>? _debt(Map<String, dynamic> f) {
    final person = _text(f['person'], 60);
    final kind = _oneOf(f['kind'], const ['owe', 'lend']);
    final amount = _money(f['amount']);
    final paid = _money(f['paid'] ?? 0, min: 0);
    final note = _text(f['note'] ?? '', 200, allowEmpty: true);
    final date = _ts(f['date']);
    if (person == null ||
        kind == null ||
        amount == null ||
        paid == null ||
        paid > amount ||
        note == null ||
        date == null) {
      return null;
    }
    final rawDue = f['dueDate'];
    final dueDate = _ts(rawDue);
    if (rawDue != null && dueDate == null) return null;
    return {
      'person': person,
      'kind': kind,
      'amount': amount,
      'paid': paid,
      'note': note,
      'date': date,
      'createdAt': FieldValue.serverTimestamp(),
      if (dueDate != null) 'dueDate': dueDate,
    };
  }
}

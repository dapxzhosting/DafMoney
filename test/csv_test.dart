import 'package:daf_money/core/models/entry_type.dart';
import 'package:daf_money/core/utils/csv_codec.dart';
import 'package:daf_money/features/data_io/data/import_service.dart';
import 'package:daf_money/features/data_io/domain/csv_transactions.dart';
import 'package:daf_money/features/transactions/domain/money_transaction.dart';
import 'package:daf_money/features/categories/domain/category.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CsvCodec', () {
    test('kutip, koma, dan baris baru di dalam sel', () {
      final rows = CsvCodec.parse('a,b\r\n"x, y","say ""hi""\nline2"\r\n');
      expect(rows, [
        ['a', 'b'],
        ['x, y', 'say "hi"\nline2'],
      ]);
    });

    test('deteksi titik koma dan BOM', () {
      final rows = CsvCodec.parse('\uFEFFTanggal;Jumlah\n2026-01-01;5000\n');
      expect(rows.first, ['Tanggal', 'Jumlah']);
      expect(rows[1], ['2026-01-01', '5000']);
    });

    test('encode lalu parse kembali menghasilkan data yang sama', () {
      final src = [
        ['a', 'b,c', 'd"e', 'f\ng'],
      ];
      expect(CsvCodec.parse(CsvCodec.encode(src)), src);
    });
  });

  group('parseCsvAmount', () {
    test('berbagai format', () {
      expect(parseCsvAmount('15000'), 15000);
      expect(parseCsvAmount('1.500.000'), 1500000);
      expect(parseCsvAmount('Rp 1.500.000'), 1500000);
      expect(parseCsvAmount('1,500,000'), 1500000);
      expect(parseCsvAmount('1500000.00'), 1500000);
      expect(parseCsvAmount('1.500.000,50'), 1500001);
      expect(parseCsvAmount('-25000'), 25000);
    });

    test('awalan Rp./IDR, akhiran ,- dan spasi NBSP', () {
      expect(parseCsvAmount('Rp. 50.000'), 50000);
      expect(parseCsvAmount('Rp.50.000'), 50000);
      expect(parseCsvAmount('RP 1.500.000,00'), 1500000);
      expect(parseCsvAmount('Rp 50.000,-'), 50000);
      expect(parseCsvAmount('50.000,-'), 50000);
      expect(parseCsvAmount('IDR 50.000'), 50000);
      expect(parseCsvAmount('Rp\u00A050.000'), 50000);
      expect(parseCsvAmount('-Rp 25.000'), 25000);
      expect(parseCsvAmount('Rp'), isNull);
    });

    test('menolak nol, kosong, dan teks', () {
      expect(parseCsvAmount('0'), isNull);
      expect(parseCsvAmount(''), isNull);
      expect(parseCsvAmount('abc'), isNull);
    });
  });

  group('parseCsvDate', () {
    test('format yang didukung', () {
      expect(parseCsvDate('2026-03-05'), DateTime(2026, 3, 5));
      expect(parseCsvDate('05/03/2026'), DateTime(2026, 3, 5));
      expect(parseCsvDate('2026-03-05 10:30:00'), DateTime(2026, 3, 5));
    });

    test('menolak tanggal yang tidak ada', () {
      expect(parseCsvDate('2026-02-31'), isNull);
      expect(parseCsvDate('kemarin'), isNull);
    });
  });

  group('parseTransactionsCsv', () {
    const csv =
        'Tanggal,Jenis,Kategori,Dompet,Jumlah,Catatan\n'
        '2026-01-05,Pengeluaran,Makanan,Tunai,25000,"Makan siang, kantor"\n'
        '2026-01-06,Pemasukan,Gaji,,5000000,\n'
        '2026-13-01,Pengeluaran,Belanja,,1000,\n'
        '2026-01-07,Lainnya,Belanja,,1000,\n';

    test('baris valid dan baris bermasalah dipisah', () {
      final p = parseTransactionsCsv(csv);
      print('ERRORS: ${p.errors}');
      print('ROWS: ${p.rows.length}');
      expect(p.rows.length, 2);
      expect(p.errors.length, 2);
      expect(p.rows.first.note, 'Makan siang, kantor');
      expect(p.rows.first.walletName, 'Tunai');
      expect(p.rows[1].type, EntryType.income);
      expect(p.rows[1].walletName, isNull);
    });

    test('kolom wajib hilang menghasilkan pesan jelas', () {
      final p = parseTransactionsCsv('Foo,Bar\n1,2\n');
      expect(p.rows, isEmpty);
      expect(p.errors.single, contains('Kolom wajib'));
    });

    test('format ekspor lama tanpa kolom Dompet tetap bisa diimpor', () {
      final p = parseTransactionsCsv(
        'Tanggal,Jenis,Kategori,Jumlah,Catatan\n2026-01-05,Pengeluaran,Makanan,25000,bakso\n',
      );
      expect(p.rows.single.amount, 25000);
      expect(p.rows.single.walletName, isNull);
    });
  });

  group('planImport', () {
    final cat = const Category(
      id: 'c1',
      name: 'Makanan',
      type: EntryType.expense,
      iconKey: 'restaurant',
      colorValue: 0xFFF97316,
    );

    ImportRow row(String note) => ImportRow(
      date: DateTime(2026, 1, 5),
      type: EntryType.expense,
      categoryName: 'Makanan',
      walletName: null,
      amount: 25000,
      note: note,
    );

    test('transaksi yang sudah ada dilewati, kembar yang sah tetap masuk', () {
      final existing = [
        MoneyTransaction(
          id: 't1',
          type: EntryType.expense,
          amount: 25000,
          categoryId: 'c1',
          note: 'bakso',
          date: DateTime(2026, 1, 5),
          createdAt: DateTime(2026, 1, 5),
        ),
      ];
      final plan = planImport(
        rows: [row('bakso'), row('bakso'), row('kopi')],
        existing: existing,
        categories: {'c1': cat},
        wallets: const [],
      );
      expect(plan.duplicates, 1);
      expect(plan.toImport.length, 2);
      expect(plan.newCategories, isEmpty);
    });

    test('kategori dan dompet baru terdeteksi', () {
      final plan = planImport(
        rows: [
          ImportRow(
            date: DateTime(2026, 1, 5),
            type: EntryType.expense,
            categoryName: 'Hobi',
            walletName: 'DANA',
            amount: 1000,
            note: '',
          ),
        ],
        existing: const [],
        categories: {'c1': cat},
        wallets: const [],
      );
      expect(plan.newCategories, {'expense|hobi'});
      expect(plan.newWallets, {'dana'});
    });
  });

  group('sanitasi formula CSV (L1)', () {
    test('sel berawalan rumus diberi apostrof, angka tidak berubah', () {
      final out = CsvCodec.encode([
        ['=1+1', '-5 teh', '@cmd', 'aman', 25000, null],
      ]);
      expect(out, "'=1+1,'-5 teh,'@cmd,aman,25000,\r\n");
    });

    test('unsanitizeCell membalikkan sanitizeCell', () {
      for (final v in [
        '=1+1',
        '+62',
        '-x',
        '@a',
        'biasa',
        "'kutip",
        '',
        "'=a",
        "''=a",
        "'",
      ]) {
        expect(CsvCodec.unsanitizeCell(CsvCodec.sanitizeCell(v)), v);
      }
    });
  });
}

import 'package:daf_money/core/models/entry_type.dart';
import 'package:daf_money/core/services/quick_entry_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  sharedTests();
  test('membaca nominal dengan akhiran', () {
    expect(parseQuickEntry('makan siang 25rb')!.amount, 25000);
    expect(parseQuickEntry('gaji 5jt')!.amount, 5000000);
    expect(parseQuickEntry('bensin 1,5jt')!.amount, 1500000);
    expect(parseQuickEntry('parkir 3k')!.amount, 3000);
  });

  test('membaca nominal polos dan berpemisah', () {
    expect(parseQuickEntry('kopi 15.000')!.amount, 15000);
    expect(parseQuickEntry('25000 parkir')!.amount, 25000);
    expect(parseQuickEntry('beli 2 galon 30000')!.amount, 30000);
    expect(parseQuickEntry('Rp 12.500 bakso')!.amount, 12500);
  });

  test('catatan bersih dan null bila tanpa nominal', () {
    expect(parseQuickEntry('makan siang 25rb')!.note, 'Makan siang');
    expect(parseQuickEntry('25rb')!.note, 'Transaksi cepat');
    expect(parseQuickEntry('makan siang'), isNull);
    expect(parseQuickEntry('  '), isNull);
    expect(parseQuickEntry('Magnum 1'), isNull);
    expect(parseQuickEntry('Magnum 1 8rb')!.amount, 8000);
    expect(parseQuickEntry('Magnum 1 8rb')!.note, 'Magnum 1');
  });

  test('menebak kategori', () {
    expect(guessCategoryName('Kopi susu', EntryType.expense),
        'makanan & minuman');
    expect(guessCategoryName('Parkir', EntryType.expense), 'transportasi');
    expect(guessCategoryName('Gaji bulanan', EntryType.income), 'gaji');
    expect(guessCategoryName('xyz', EntryType.expense), isNull);
  });
}

void sharedTests() {
  test('meringkas teks yang dibagikan', () {
    expect(
      summarizeSharedText('Transfer berhasil Rp 150.000 ke Budi'),
      'Transfer berhasil ke Budi 150000',
    );
    expect(summarizeSharedText('Rp 25.000,00'), 'Transaksi 25000');
    expect(guessSharedType('Dana masuk Rp 50.000'), EntryType.income);
    expect(guessSharedType('Pembayaran berhasil'), EntryType.expense);
  });
}

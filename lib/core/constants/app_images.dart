/// Lokasi ilustrasi bawaan aplikasi (folder `assets/illustrations/`).
abstract class AppImages {
  static const _dir = 'assets/illustrations';

  /// Tangan memegang kantong uang (hijau tosca).
  static const moneyBag = '$_dir/money_bag.webp';

  /// Tablet dengan grafik batang naik (biru).
  static const growthTablet = '$_dir/growth_tablet.webp';

  /// Perempuan membawa tablet di depan grafik dan kalkulator.
  static const womanChart = '$_dir/woman_chart.webp';

  /// Pria dengan kopi dan dasbor (hijau, senada warna merek).
  static const manDashboard = '$_dir/man_dashboard.webp';

  /// Perempuan menghitung koin di meja kerja.
  static const womanDesk = '$_dir/woman_desk.webp';

  /// Papan catatan dengan koin dicoret (belum ada anggaran).
  static const budgetEmpty = '$_dir/budget_empty.webp';

  /// Dompet biru dengan uang dan koin (belum ada dompet).
  static const walletEmpty = '$_dir/wallet_empty.webp';

  /// Celengan babi dengan tanda plus (target tabungan, tantangan).
  static const goalEmpty = '$_dir/goal_empty.webp';

  /// Struk dengan kaca pembesar dan tanda silang (belum ada transaksi).
  static const transactionEmpty = '$_dir/transaction_empty.webp';

  /// Dokumen merah dengan jam dan panah turun (utang).
  static const debtEmpty = '$_dir/debt_empty.webp';

  /// Dokumen hijau dengan panah masuk (piutang).
  static const receivableEmpty = '$_dir/receivable_empty.webp';

  /// Semua aset; dipakai tes untuk memastikan berkasnya ada.
  static const all = <String>[
    moneyBag,
    growthTablet,
    womanChart,
    manDashboard,
    womanDesk,
    budgetEmpty,
    walletEmpty,
    goalEmpty,
    transactionEmpty,
    debtEmpty,
    receivableEmpty,
  ];
}

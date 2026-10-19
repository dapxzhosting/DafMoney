class UserProfile {
  const UserProfile({
    required this.name,
    required this.email,
    required this.initialBalance,
  });

  final String name;
  final String email;

  /// Saldo yang dimiliki sebelum mulai mencatat; ditambahkan ke total saldo.
  final int initialBalance;
}

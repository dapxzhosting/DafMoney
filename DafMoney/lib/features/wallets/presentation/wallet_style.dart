import 'package:flutter/material.dart';

import '../../categories/presentation/category_style.dart';
import '../domain/wallet.dart';

abstract class WalletIcons {
  /// Subset ikon dari [CategoryIcons] yang cocok untuk dompet.
  static const List<String> keys = [
    'payments',
    'bank',
    'savings',
    'phone',
    'bag',
    'cart',
    'work',
    'gift',
    'trending',
    'home',
  ];

  static const String defaultKey = 'payments';
}

extension WalletStyle on Wallet {
  IconData get icon => CategoryIcons.byKey(iconKey);
  Color get color => Color(colorValue);
}

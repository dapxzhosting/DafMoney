import 'package:flutter/material.dart';

import '../domain/category.dart';

abstract class CategoryIcons {
  static const Map<String, IconData> all = {
    'restaurant': Icons.restaurant_rounded,
    'cafe': Icons.local_cafe_rounded,
    'car': Icons.directions_car_rounded,
    'bus': Icons.directions_bus_rounded,
    'bag': Icons.shopping_bag_rounded,
    'cart': Icons.shopping_cart_rounded,
    'receipt': Icons.receipt_long_rounded,
    'bolt': Icons.bolt_rounded,
    'home': Icons.home_rounded,
    'movie': Icons.movie_rounded,
    'game': Icons.sports_esports_rounded,
    'heart': Icons.favorite_rounded,
    'medical': Icons.medical_services_rounded,
    'school': Icons.school_rounded,
    'flight': Icons.flight_rounded,
    'pets': Icons.pets_rounded,
    'fitness': Icons.fitness_center_rounded,
    'phone': Icons.phone_android_rounded,
    'gift': Icons.card_giftcard_rounded,
    'payments': Icons.payments_rounded,
    'trending': Icons.trending_up_rounded,
    'savings': Icons.savings_rounded,
    'work': Icons.work_rounded,
    'build': Icons.build_rounded,
    'kids': Icons.child_care_rounded,
    'clothes': Icons.checkroom_rounded,
    'wifi': Icons.wifi_rounded,
    'gas': Icons.local_gas_station_rounded,
    'bank': Icons.account_balance_rounded,
    'more': Icons.more_horiz_rounded,
  };

  static IconData byKey(String key) => all[key] ?? Icons.category_rounded;
}

abstract class CategoryPalette {
  static const List<int> colors = [
    0xFFEF4444, 0xFFF97316, 0xFFF59E0B, 0xFF84CC16, 0xFF22C55E,
    0xFF14B8A6, 0xFF06B6D4, 0xFF3B82F6, 0xFF6366F1, 0xFF8B5CF6,
    0xFFD946EF, 0xFFEC4899, 0xFF78716C,
  ];
}

extension CategoryStyle on Category {
  IconData get icon => CategoryIcons.byKey(iconKey);
  Color get color => Color(colorValue);
}

class CategoryLook {
  const CategoryLook(this.name, this.icon, this.color);

  final String name;
  final IconData icon;
  final Color color;
}

CategoryLook resolveCategory(Map<String, Category> map, String id) {
  final c = map[id];
  if (c == null) {
    return const CategoryLook(
        'Tanpa kategori', Icons.help_outline_rounded, Color(0xFF9CA3AF));
  }
  return CategoryLook(c.name, c.icon, c.color);
}

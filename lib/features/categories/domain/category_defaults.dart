import '../../../core/models/entry_type.dart';

typedef CategoryDraft = ({String name, EntryType type, String icon, int color});

const defaultCategories = <CategoryDraft>[
  (name: 'Makanan & Minuman', type: EntryType.expense, icon: 'restaurant', color: 0xFFF97316),
  (name: 'Transportasi', type: EntryType.expense, icon: 'car', color: 0xFF3B82F6),
  (name: 'Belanja', type: EntryType.expense, icon: 'bag', color: 0xFFEC4899),
  (name: 'Tagihan', type: EntryType.expense, icon: 'receipt', color: 0xFFEF4444),
  (name: 'Hiburan', type: EntryType.expense, icon: 'movie', color: 0xFF8B5CF6),
  (name: 'Kesehatan', type: EntryType.expense, icon: 'medical', color: 0xFF14B8A6),
  (name: 'Pendidikan', type: EntryType.expense, icon: 'school', color: 0xFF6366F1),
  (name: 'Lainnya', type: EntryType.expense, icon: 'more', color: 0xFF78716C),
  (name: 'Gaji', type: EntryType.income, icon: 'payments', color: 0xFF22C55E),
  (name: 'Bonus', type: EntryType.income, icon: 'gift', color: 0xFFF59E0B),
  (name: 'Investasi', type: EntryType.income, icon: 'trending', color: 0xFF06B6D4),
  (name: 'Lainnya', type: EntryType.income, icon: 'savings', color: 0xFF84CC16),
];

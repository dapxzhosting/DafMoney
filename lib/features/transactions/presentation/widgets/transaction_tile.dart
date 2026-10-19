import 'package:flutter/material.dart';

import '../../../../core/models/entry_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../categories/domain/category.dart';
import '../../../categories/presentation/category_style.dart';
import '../../domain/money_transaction.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.categories,
    required this.onTap,
    this.showDate = false,
  });

  final MoneyTransaction transaction;
  final Map<String, Category> categories;
  final VoidCallback onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fin = context.finance;
    final look = resolveCategory(categories, transaction.categoryId);
    final isIncome = transaction.type == EntryType.income;
    final amountColor = isIncome ? fin.income : fin.expense;

    final subtitle = transaction.note.isNotEmpty
        ? transaction.note
        : (showDate ? Fmt.dateShort(transaction.date) : transaction.type.label);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CategoryAvatar(icon: look.icon, color: look.color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(look.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${isIncome ? '+' : '-'}${Fmt.rupiah(transaction.amount)}',
                style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800, color: amountColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

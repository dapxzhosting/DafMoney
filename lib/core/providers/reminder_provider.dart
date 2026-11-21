import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../services/notification_service.dart';
import '../utils/date_utils.dart';
import 'session_providers.dart';
import 'shared_prefs_provider.dart';

class ReminderState {
  const ReminderState({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  ReminderState copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderState(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}

class ReminderNotifier extends Notifier<ReminderState> {
  @override
  ReminderState build() {
    final prefs = ref.read(sharedPrefsProvider);
    return ReminderState(
      enabled: prefs.getBool(AppConstants.reminderEnabledKey) ?? true,
      hour: prefs.getInt(AppConstants.reminderHourKey) ?? 20,
      minute: prefs.getInt(AppConstants.reminderMinuteKey) ?? 0,
    );
  }

  bool get _loggedToday {
    final raw = ref
        .read(sharedPrefsProvider)
        .getString(AppConstants.reminderLastLoggedKey);
    return raw == monthKey(DateTime.now()) + _day(DateTime.now());
  }

  static String _day(DateTime d) => '-${d.day.toString().padLeft(2, '0')}';

  Future<void> sync() async {
    try {
      final signedIn = ref.read(uidProvider) != null;
      if (!state.enabled || !signedIn) {
        await NotificationService.cancelDailyReminder();
        return;
      }
      await NotificationService.scheduleDailyReminder(
        hour: state.hour,
        minute: state.minute,
        skipToday: _loggedToday,
      );
    } catch (_) {}
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    await ref
        .read(sharedPrefsProvider)
        .setBool(AppConstants.reminderEnabledKey, value);
    await sync();
  }

  Future<void> setTime(TimeOfDay t) async {
    state = state.copyWith(hour: t.hour, minute: t.minute);
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setInt(AppConstants.reminderHourKey, t.hour);
    await prefs.setInt(AppConstants.reminderMinuteKey, t.minute);
    await sync();
  }

  Future<void> onTransactionLogged() async {
    final now = DateTime.now();
    await ref
        .read(sharedPrefsProvider)
        .setString(
          AppConstants.reminderLastLoggedKey,
          monthKey(now) + _day(now),
        );
    await sync();
  }

  Future<void> sendTest() async {
    try {
      await NotificationService.showTestReminder();
    } catch (_) {}
  }
}

final reminderProvider = NotifierProvider<ReminderNotifier, ReminderState>(
  ReminderNotifier.new,
);

class BudgetAlertsNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPrefsProvider).getBool(AppConstants.budgetAlertsKey) ??
      true;

  Future<void> set(bool value) async {
    state = value;
    await ref
        .read(sharedPrefsProvider)
        .setBool(AppConstants.budgetAlertsKey, value);
  }
}

final budgetAlertsEnabledProvider =
    NotifierProvider<BudgetAlertsNotifier, bool>(BudgetAlertsNotifier.new);

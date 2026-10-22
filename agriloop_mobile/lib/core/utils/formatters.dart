import 'package:intl/intl.dart';

/// Shared display helpers so the same value never formats two different ways
/// across screens.
class Fmt {
  const Fmt._();

  static final NumberFormat _int = NumberFormat.decimalPattern('en_MY');
  static final NumberFormat _rm = NumberFormat.currency(
    locale: 'en_MY',
    symbol: 'RM ',
    decimalDigits: 2,
  );
  static final DateFormat _date = DateFormat('d MMM yyyy');
  static final DateFormat _dateTime = DateFormat('d MMM, h:mm a');
  static final DateFormat _time = DateFormat('h:mm a');

  static String points(int value) => _int.format(value);

  static String rm(double value) => _rm.format(value);

  static String rmCompact(double value) =>
      value == value.roundToDouble() ? 'RM ${value.round()}' : _rm.format(value);

  static String kg(double value, {int decimals = 2}) =>
      '${value.toStringAsFixed(decimals)} kg';

  static String date(DateTime value) => _date.format(value);

  static String dateTime(DateTime value) => _dateTime.format(value);

  static String time(DateTime value) => _time.format(value);

  /// "3 hours ago", "in 2 days".
  static String relative(DateTime value, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(value);
    final future = !diff.isNegative;
    final abs = diff.abs();

    String unit;
    if (abs.inMinutes < 1) {
      return future ? 'in a moment' : 'just now';
    } else if (abs.inMinutes < 60) {
      unit = 'minute${abs.inMinutes == 1 ? '' : 's'}';
    } else if (abs.inHours < 24) {
      unit = 'hour${abs.inHours == 1 ? '' : 's'}';
    } else if (abs.inDays < 30) {
      unit = 'day${abs.inDays == 1 ? '' : 's'}';
    } else {
      unit = 'month${(abs.inDays / 30).floor() == 1 ? '' : 's'}';
    }

    final count = abs.inMinutes < 60
        ? abs.inMinutes
        : abs.inHours < 24
            ? abs.inHours
            : abs.inDays < 30
                ? abs.inDays
                : (abs.inDays / 30).floor();

    final text = '$count $unit';
    return future ? 'in $text' : '$text ago';
  }

  /// Days remaining until expiry, clamped at zero.
  static int daysUntil(DateTime expiry, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = expiry.difference(reference).inDays;
    return diff < 0 ? 0 : diff;
  }
}

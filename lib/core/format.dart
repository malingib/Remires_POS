import 'package:intl/intl.dart';

/// Money is stored as integer minor units (1 KES = 100) to avoid float drift.
class Money {
  static const String currency = 'KES';
  static final NumberFormat _fmt = NumberFormat('#,##0.00');

  static String format(int minor) {
    final sign = minor < 0 ? '-' : '';
    return '$sign$currency ${_fmt.format(minor.abs() / 100)}';
  }

  /// Parses "1,250.50" into 125050. Returns null when the text is not a number.
  /// Uses integer arithmetic on the decimal parts to avoid binary-float drift
  /// (e.g. 19.99 * 100). Up to 2 decimal places are kept; extra digits are
  /// rounded. Optional leading +/- is allowed; surrounding spaces and commas
  /// are ignored.
  static int? parse(String input) {
    var cleaned = input.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    var negative = false;
    if (cleaned.startsWith('-') || cleaned.startsWith('+')) {
      negative = cleaned.startsWith('-');
      cleaned = cleaned.substring(1).trim();
      if (cleaned.isEmpty) return null;
    }
    final parts = cleaned.split('.');
    if (parts.length > 2) return null;
    final whole = parts[0].isEmpty ? '0' : parts[0];
    var frac = parts.length == 2 ? parts[1].trim() : '';
    if (!RegExp(r'^\d+$').hasMatch(whole)) return null;
    if (frac.isNotEmpty && !RegExp(r'^\d+$').hasMatch(frac)) return null;
    if (frac.length > 2) {
      // Round to 2 dp using the third digit.
      final third = int.parse(frac[2]);
      frac = frac.substring(0, 2);
      var cents = int.parse(whole) * 100 + int.parse(frac.padRight(2, '0'));
      if (third >= 5) cents += 1;
      return negative ? -cents : cents;
    }
    final cents =
        int.parse(whole) * 100 + int.parse(frac.padRight(2, '0'));
    return negative ? -cents : cents;
  }
}

class Fmt {
  static String qty(double q) {
    if (!q.isFinite) return '-';
    if (q == q.roundToDouble()) return q.toStringAsFixed(0);
    // Keep up to 3 decimals, trimming trailing zeros (1.500 -> 1.5).
    final s = q.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
    return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
  }

  static String date(DateTime d) => DateFormat('d MMM yyyy').format(d);
}

/// Business dates are whole local calendar days ("2026-10-01"), not
/// timestamps. All helpers normalize to local time first so a UTC midnight
/// does not shift the day when formatted.
String ymd(DateTime d) {
  final l = d.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

DateTime dateOnly(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

import 'package:intl/intl.dart';

class Formatter {
  static String currency(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  static String date(String isoDate) {
    final dt = DateTime.parse(isoDate);
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  static String invoice() {
    final now = DateTime.now();
    return 'INV${DateFormat('yyyyMMddHHmmss').format(now)}';
  }
}

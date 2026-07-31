import 'package:intl/intl.dart';

class AppFormatters {
  static final NumberFormat money = NumberFormat.currency(symbol: '€ ');
  static final DateFormat date = DateFormat.yMMMd();
  static final DateFormat dateTime = DateFormat.yMMMd().add_jm();

  static String moneyValue(double? amount) {
    if (amount == null) {
      return 'No amount';
    }
    return money.format(amount);
  }
}


import 'package:intl/intl.dart';

final _pkrFormat = NumberFormat.currency(
  locale: 'en_PK',
  symbol: 'Rs ',
  decimalDigits: 0,
);

String formatPkr(double amount) => _pkrFormat.format(amount);

const String pkrPrefix = 'Rs ';

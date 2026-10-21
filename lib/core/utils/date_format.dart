import 'package:intl/intl.dart';

/// "18 oct 2026". Requiere `initializeDateFormatting('es')` al iniciar la app.
String formatShortDate(DateTime date) {
  return DateFormat('d MMM y', 'es').format(date.toLocal());
}

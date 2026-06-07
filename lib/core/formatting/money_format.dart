/// Валюта Таджикистана — сомони (не «сум»).
const String currencyLabel = 'сомони';

String formatSomoni(double v) {
  if (v == v.roundToDouble()) {
    return '${v.toStringAsFixed(0)} $currencyLabel';
  }
  return '${v.toStringAsFixed(2)} $currencyLabel';
}

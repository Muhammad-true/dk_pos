String formatSomoni(double v) {
  if (v == v.roundToDouble()) {
    return '${v.toStringAsFixed(0)} с.';
  }
  return '${v.toStringAsFixed(2)} с.';
}

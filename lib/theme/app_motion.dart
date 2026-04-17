import 'package:flutter/material.dart';

/// Короткие анимации без постоянных тикеров.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 260);
  static const Curve tabSwitch = Curves.easeOutCubic;
}

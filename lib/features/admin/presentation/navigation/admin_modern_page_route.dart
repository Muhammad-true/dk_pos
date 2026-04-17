import 'package:flutter/material.dart';

/// Полноэкранный переход для подстраниц админки: лёгкий сдвиг + fade.
class AdminModernPageRoute<T> extends PageRouteBuilder<T> {
  AdminModernPageRoute({required Widget page})
      : super(
          opaque: true,
          barrierDismissible: false,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            final slide = Tween<Offset>(
              begin: const Offset(0.07, 0),
              end: Offset.zero,
            ).animate(curved);
            return SlideTransition(
              position: slide,
              child: FadeTransition(
                opacity: curved,
                child: child,
              ),
            );
          },
        );
}

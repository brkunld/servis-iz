import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Sağdan kayarak açılan sayfa (iOS benzeri). Giriş → Kayıt geçişinde
/// kullanılır; geri dönüşte ters yöne kayar.
CustomTransitionPage<void> slideFromRightPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final tween = Tween(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeInOut));

      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

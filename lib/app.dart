import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobil_proje/core/router/app_router.dart';
import 'package:mobil_proje/features/auth/data/auth_repository.dart';
import 'package:mobil_proje/features/auth/data/session_providers.dart';
import 'package:mobil_proje/features/auth/domain/session.dart';

class ServisIzApp extends ConsumerWidget {
  const ServisIzApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Oturum geçersizse (rol yok ya da okunamadı) kullanıcı çıkışa
    // zorlanır; mesaj giriş ekranında gösterilir.
    ref.listen<AsyncValue<Session>>(sessionProvider, (_, next) {
      if (next case AsyncData(value: InvalidSession(:final problem))) {
        ref.read(loginMessageProvider.notifier).show(problem.message);
        ref.read(authRepositoryProvider).signOut();
      }
    });

    return MaterialApp.router(
      title: 'Servisİz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF1F5FF),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

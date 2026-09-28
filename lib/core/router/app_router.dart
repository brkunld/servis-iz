import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobil_proje/core/router/app_routes.dart';
import 'package:mobil_proje/core/router/auth_redirect.dart';
import 'package:mobil_proje/core/router/page_transitions.dart';
import 'package:mobil_proje/features/auth/data/session_providers.dart';
import 'package:mobil_proje/features/auth/presentation/login_screen.dart';
import 'package:mobil_proje/features/auth/presentation/register_screen.dart';
import 'package:mobil_proje/features/auth/presentation/verify_email_screen.dart';
import 'package:mobil_proje/features/chat/presentation/chat_screen.dart';
import 'package:mobil_proje/features/company/presentation/add_technician_screen.dart';
import 'package:mobil_proje/features/company/presentation/company_dashboard_screen.dart';
import 'package:mobil_proje/features/company/presentation/edit_technician_screen.dart';
import 'package:mobil_proje/features/requests/presentation/customer_requests_screen.dart';
import 'package:mobil_proje/features/requests/presentation/map_picker_screen.dart';
import 'package:mobil_proje/features/requests/presentation/new_request_screen.dart';
import 'package:mobil_proje/features/technicians/presentation/technician_task_screen.dart';
import 'package:mobil_proje/features/tracking/presentation/tracking_map_screen.dart';

/// Uygulamanın yönlendiricisi (go_router).
///
/// Oturum her değiştiğinde (`sessionProvider`) router uyarılır ve
/// [authRedirect] yeniden çalışır: giriş yapan kullanıcı rolünün ana
/// ekranına, çıkış yapan giriş ekranına kendiliğinden gider. Ekranlar bu
/// yüzden "girişten sonra nereye gideyim" diye düşünmez.
final routerProvider = Provider<GoRouter>((ref) {
  // go_router'ın dinleyebileceği basit bir "değişti" sinyali.
  final sessionChanged = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => sessionChanged.value++);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: sessionChanged,
    redirect: (context, state) =>
        authRedirect(ref.read(sessionProvider).valueOrNull, state.uri.path),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
        routes: [
          GoRoute(
            path: 'register',
            pageBuilder: (context, state) => slideFromRightPage(
              key: state.pageKey,
              child: const RegisterScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => const VerifyEmailScreen(),
      ),

      // Müşteri
      GoRoute(
        path: AppRoutes.customer,
        builder: (context, state) => const CustomerRequestsScreen(),
        routes: [
          GoRoute(
            path: 'new-request',
            builder: (context, state) => const NewRequestScreen(),
            routes: [
              GoRoute(
                path: 'pick-location',
                builder: (context, state) => const MapPickerScreen(),
              ),
            ],
          ),
        ],
      ),

      // Teknisyen
      GoRoute(
        path: AppRoutes.technician,
        builder: (context, state) => const TechnicianTaskScreen(),
      ),

      // Şirket
      GoRoute(
        path: AppRoutes.company,
        builder: (context, state) => const CompanyDashboardScreen(),
        routes: [
          GoRoute(
            path: 'technicians/new',
            builder: (context, state) => const AddTechnicianScreen(),
          ),
          GoRoute(
            path: 'technicians/:id/edit',
            builder: (context, state) =>
                EditTechnicianScreen(technicianId: state.pathParameters['id']!),
          ),
        ],
      ),

      // Ortak ekranlar
      GoRoute(
        path: '${AppRoutes.chatBase}/:requestId',
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return ChatScreen(
            requestId: state.pathParameters['requestId']!,
            customerId: query['customer'] ?? '',
            technicianId: query['technician'] ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.mapBase,
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return TrackingMapScreen(
            viewer:
                MapViewer.values.asNameMap()[query['viewer']] ??
                MapViewer.customer,
            technicianId: query['technician'],
            customerId: query['customer'],
            customerLat: double.tryParse(query['lat'] ?? ''),
            customerLng: double.tryParse(query['lng'] ?? ''),
          );
        },
      ),
    ],
  );

  ref.onDispose(() {
    sessionChanged.dispose();
    router.dispose();
  });
  return router;
});

/// Oturum ilk kez yüklenirken gösterilir.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

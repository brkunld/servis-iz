import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobil_proje/screens/edit_technician_screen.dart';
import 'utils/firebase_options.dart';
import 'utils/user_role.dart';
import 'screens/login_screen.dart';
import 'screens/customer_request_screen.dart';
import 'screens/company_dashboard.dart';
import 'screens/technician_task_screen.dart';
import 'screens/register_screen.dart';
import 'screens/add_technician_screen.dart';
import 'screens/new_request_screen.dart';
import 'screens/verify_email_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: TechServiceApp()));
}

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges(); 
});

class TechServiceApp extends ConsumerWidget {
  const TechServiceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Servisİz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF1F5FF),
      ),

      home: authState.when(
        data: (user) {
          if (user == null) {
            return const LoginScreen();
          }

          return FutureBuilder<UserRole?>(
            future: findUserRole(user.uid),
            builder: (context, snap) {

              if (snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snap.hasError) {
                debugPrint("Rol okuma hatası: ${snap.error}");

                FirebaseAuth.instance.signOut();

                return const LoginScreen(
                  showMessage:
                      "Bir hata oluştu. Lütfen tekrar giriş yapın.",
                );
              }

              final role = snap.data;

              // Oturumdan atmadan doğrulama ekranı gösterilir; böylece kayıt
              // sırasında müşteri belgesinin yazılması yarıda kesilmez.
              if (needsEmailVerification(user, role)) {
                return const VerifyEmailScreen();
              }

              if (role == null) {
                debugPrint("Kullanıcı rolü bulunamadı: UID => ${user.uid}");

                FirebaseAuth.instance.signOut();

                return const LoginScreen(
                  showMessage:
                      "Hesabınız bir role bağlı değil. Lütfen tekrar giriş yapın.",
                );
              }

              switch (role) {
                case UserRole.company:
                  return const CompanyDashboard();
                case UserRole.technician:
                  return const TechnicianTaskScreen();
                case UserRole.customer:
                  return const CustomerRequestMenu();
              }
            },
          );
        },

        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),

        error: (e, stack) => const Scaffold(
          body: Center(child: Text('Bir hata oluştu')),
        ),
      ),

      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/customer': (context) => const CustomerRequestMenu(),
        '/company': (context) => const CompanyDashboard(),
        '/technician': (context) => const TechnicianTaskScreen(),
        '/add_technician': (context) => const AddTechnicianScreen(),
        '/newRequest': (context) => const NewRequestScreen(),
        '/edit_technician': (context) => const EditTechnicianScreen(),
      },
    );
  }
}

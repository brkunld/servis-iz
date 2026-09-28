import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobil_proje/screens/edit_technician_screen.dart';
import 'utils/firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/customer_request_screen.dart';
import 'screens/company_dashboard.dart';
import 'screens/technician_task_screen.dart';
import 'screens/register_screen.dart';
import 'screens/add_technician_screen.dart';
import 'screens/new_request_screen.dart';

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

  Future<String?> _getUserRole(String uid) async {
    final db = FirebaseFirestore.instance;

    final technician = await db.collection('technicians').doc(uid).get();
    if (technician.exists) return 'technician';

    final company = await db.collection('companies').doc(uid).get();
    if (company.exists) return 'company';

    final customer = await db.collection('customers').doc(uid).get();
    if (customer.exists) return 'customer';

    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Technical Service App',
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

          return FutureBuilder<String?>(
            future: _getUserRole(user.uid),
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

              if (role == null) {
                debugPrint("Kullanıcı rolü bulunamadı: UID => ${user.uid}");

                FirebaseAuth.instance.signOut();

                return const LoginScreen(
                  showMessage:
                      "Hesabınız bir role bağlı değil. Lütfen tekrar giriş yapın.",
                );
              }

              if (role == 'company') return const CompanyDashboard();
              if (role == 'technician') return const TechnicianTaskScreen();
              return const CustomerRequestMenu();
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

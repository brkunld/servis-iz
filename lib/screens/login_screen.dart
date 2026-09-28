import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:mobil_proje/screens/company_dashboard.dart';
import 'package:mobil_proje/screens/customer_request_screen.dart';
import 'package:mobil_proje/screens/technician_task_screen.dart';
import 'package:mobil_proje/screens/register_screen.dart';
import 'package:mobil_proje/screens/verify_email_screen.dart';
import 'package:mobil_proje/utils/background.dart';
import 'package:mobil_proje/utils/route.dart';
import 'package:mobil_proje/utils/user_role.dart';

class LoginScreen extends StatefulWidget {
  final String? showMessage;

  const LoginScreen({super.key, this.showMessage});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;

  final TextEditingController inputController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.showMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(widget.showMessage!)));
      });
    }
  }

  @override
  void dispose() {
    inputController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _forgotPasswordDialog() {
    final TextEditingController resetController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Şifre Sıfırlama"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: TextField(
          controller: resetController,
          decoration: const InputDecoration(
            labelText: "E-posta",
            prefixIcon: Icon(Icons.email),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetPassword(resetController.text.trim());
            },
            child: const Text("Gönder"),
          ),
        ],
      ),
    );
  }

  Future<void> _resetPassword(String email) async {
    if (email.isEmpty) {
      return _show("Lütfen e-posta gir.");
    }

    if (!email.contains("@")) {
      return _show("Lütfen geçerli bir e-posta gir.");
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _show("Şifre sıfırlama maili gönderildi: $email");
    } catch (e) {
      _show("Hata: $e");
    }
  }

  Future<void> _login() async {
    final email = inputController.text.trim();
    final pass = passwordController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      return _show("Lütfen e-posta ve şifre gir.");
    }

    if (!email.contains("@")) {
      return _show("Lütfen geçerli bir e-posta gir.");
    }

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final user = cred.user!;
      final role = await findUserRole(user.uid, retries: 0);

      if (needsEmailVerification(user, role)) {
        return _navigate(const VerifyEmailScreen());
      }

      switch (role) {
        case UserRole.customer:
          return _navigate(const CustomerRequestMenu());
        case UserRole.technician:
          return _navigate(const TechnicianTaskScreen());
        case UserRole.company:
          return _navigate(const CompanyDashboard());
        case null:
          await FirebaseAuth.instance.signOut();
          return _show("Kullanıcı bulunamadı.");
      }
    } catch (e) {
      _show("Giriş hatası: $e");
    }
  }

  void _navigate(Widget page) {
    if (!mounted) return;
    Navigator.pushReplacement(context, iosPageRoute(page));
  }

  void _show(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AppBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      "Teknik Servis Girişi",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    TextField(
                      controller: inputController,
                      decoration: InputDecoration(
                        labelText: "E-posta",
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Şifre",
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Giriş Yap",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            iosPageRoute(const RegisterScreen()),
                          );
                        },
                        child: const Text("Kayıt Ol"),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: _forgotPasswordDialog,
                      child: const Text(
                        "Şifremi Unuttum?",
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

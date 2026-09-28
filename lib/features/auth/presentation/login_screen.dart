import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobil_proje/core/router/app_routes.dart';
import 'package:mobil_proje/core/widgets/app_background.dart';
import 'package:mobil_proje/features/auth/data/auth_repository.dart';
import 'package:mobil_proje/features/auth/data/session_providers.dart';

/// Giriş ekranı. Giriş başarılı olunca buradan başka ekrana gidilmez:
/// oturum değişir, yönlendirici (router) kullanıcıyı rolünün ana ekranına
/// kendisi götürür.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _obscurePassword = true;

  final TextEditingController inputController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Oturum geçersiz olduğu için kapatıldıysa (rol yok, okuma hatası)
    // mesaj burada bir kez gösterilir.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPendingMessage());
  }

  void _showPendingMessage() {
    if (!mounted) return;
    final message = ref.read(loginMessageProvider);
    if (message == null) return;
    ref.read(loginMessageProvider.notifier).clear();
    _show(message);
  }

  @override
  void dispose() {
    inputController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _forgotPasswordDialog() {
    final TextEditingController resetController = TextEditingController();
    showDialog<void>(
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
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
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
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: pass);
      // Yönlendirme router'da: sessionProvider değişince ana ekrana gidilir.
    } catch (e) {
      _show("Giriş hatası: $e");
    }
  }

  void _show(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(loginMessageProvider, (_, message) {
      // Bir sonraki karede göster (provider bildirimi sırasında değiştirmemek için).
      if (message != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _showPendingMessage(),
        );
      }
    });

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
                        onPressed: () => context.push(AppRoutes.register),
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

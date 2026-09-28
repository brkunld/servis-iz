import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobil_proje/screens/customer_request_screen.dart';
import 'package:mobil_proje/utils/background.dart';
import 'package:mobil_proje/utils/route.dart';

/// E-postasını doğrulamamış müşteriye gösterilir. Firestore kuralları da
/// doğrulanmamış müşterinin talep açmasına izin vermez.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _checking = false;

  Future<void> _checkVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _checking = true);
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed != null && refreshed.emailVerified) {
        // Kuralların yeni doğrulama durumunu görmesi için token yenilenir.
        await refreshed.getIdToken(true);
        if (!mounted) return;
        await Navigator.pushReplacement(
          context,
          iosPageRoute(const CustomerRequestMenu()),
        );
        return;
      }
      _show("E-posta henüz doğrulanmamış.");
    } catch (e) {
      _show("Kontrol edilemedi: $e");
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      _show("Doğrulama e-postası tekrar gönderildi.");
    } catch (e) {
      _show("Gönderilemedi: $e");
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    await Navigator.pushNamedAndRemoveUntil(
      context,
      "/login",
      (route) => false,
    );
  }

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? "";

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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mark_email_unread,
                      size: 56,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "E-postanı doğrula",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "$email adresine bir doğrulama bağlantısı gönderdik. "
                      "Bağlantıya tıkladıktan sonra aşağıdaki butona bas.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _checking ? null : _checkVerified,
                        child: _checking
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Doğruladım"),
                      ),
                    ),
                    TextButton(
                      onPressed: _resend,
                      child: const Text("E-postayı tekrar gönder"),
                    ),
                    TextButton(
                      onPressed: _logout,
                      child: const Text("Çıkış yap"),
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

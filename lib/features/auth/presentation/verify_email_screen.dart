import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobil_proje/core/widgets/app_background.dart';
import 'package:mobil_proje/features/auth/data/auth_repository.dart';
import 'package:mobil_proje/features/auth/data/session_providers.dart';

/// E-postasını doğrulamamış müşteriye gösterilir. Firestore kuralları da
/// doğrulanmamış müşterinin talep açmasına izin vermez.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _checking = false;

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    try {
      final verified = await ref
          .read(authRepositoryProvider)
          .reloadAndCheckVerified();
      if (verified) {
        // Oturum yeniden hesaplanır; router müşteri ekranına geçer.
        ref.invalidate(sessionProvider);
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
      await ref.read(authRepositoryProvider).resendVerificationEmail();
      _show("Doğrulama e-postası tekrar gönderildi.");
    } catch (e) {
      _show("Gönderilemedi: $e");
    }
  }

  Future<void> _logout() => ref.read(authRepositoryProvider).signOut();

  void _show(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authRepositoryProvider).currentUser?.email ?? "";

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

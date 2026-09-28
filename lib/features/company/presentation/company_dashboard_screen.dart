import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobil_proje/core/router/app_routes.dart';
import 'package:mobil_proje/core/widgets/app_background.dart';
import 'package:mobil_proje/features/auth/data/auth_repository.dart';
import 'package:mobil_proje/features/company/presentation/widgets/choose_technician_sheet.dart';
import 'package:mobil_proje/features/company/presentation/widgets/customer_requests_sheet.dart';
import 'package:mobil_proje/features/company/presentation/widgets/customers_tab.dart';
import 'package:mobil_proje/features/company/presentation/widgets/technician_sheets.dart';
import 'package:mobil_proje/features/company/presentation/widgets/technicians_tab.dart';
import 'package:mobil_proje/features/company/presentation/widgets/view_mode_toggle.dart';
import 'package:mobil_proje/features/requests/data/request_repository.dart';
import 'package:mobil_proje/features/technicians/data/technician_repository.dart';
import 'package:mobil_proje/features/technicians/domain/technician.dart';

/// Şirket paneli. Eskiden 2.067 satırlık tek dosyaydı; artık yalnız iskeleti
/// (başlık, sekme seçimi, butonlar) tutar. Listeler ve alt sayfalar
/// `widgets/` altındadır:
///
/// - [CustomersTab] + `showCustomerRequestsSheet` + `showChooseTechnicianSheet`
/// - [TechniciansTab] + `showTechnicianDetailsSheet` +
///   `showInactiveTechniciansSheet`
class CompanyDashboardScreen extends ConsumerStatefulWidget {
  const CompanyDashboardScreen({super.key});

  @override
  ConsumerState<CompanyDashboardScreen> createState() =>
      _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState
    extends ConsumerState<CompanyDashboardScreen> {
  DashboardView _currentView = DashboardView.customers;

  /// Görevdeki teknisyen devre dışı bırakılamaz; değilse onay sorulur.
  Future<void> _confirmDisableTechnician(Technician tech) async {
    final name = tech.name ?? "Teknisyen";
    final hasOpenTask = await ref
        .read(requestRepositoryProvider)
        .hasOpenTask(tech.id);

    if (!mounted) return;

    if (hasOpenTask) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white),
              SizedBox(width: 8),
              Text("Bu teknisyen aktif görevde. Devre dışı yapılamaz!"),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("$name devre dışı yapılsın mı?"),
        content: const Text(
          "Bu teknisyen silinmeyecek ancak sistemde görev alamayacak.",
        ),
        actions: [
          TextButton(
            child: const Text("İptal"),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("Devre Dışı Yap"),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref
                    .read(technicianRepositoryProvider)
                    .setActive(tech.id, active: false);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("$name devre dışı hale getirildi."),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Hata: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showingTechnicians = _currentView == DashboardView.technicians;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          "Firma Yönetim Paneli",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600, Colors.blue.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () => ref.read(authRepositoryProvider).signOut(),
              icon: const Icon(Icons.logout_rounded),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppBackground(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ViewModeToggle(
                  current: _currentView,
                  onChanged: (view) => setState(() => _currentView = view),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: showingTechnicians
                      ? TechniciansTab(
                          onShowDetails: (tech) =>
                              showTechnicianDetailsSheet(context, tech),
                          onDisable: _confirmDisableTechnician,
                        )
                      : CustomersTab(
                          onShowRequests: (customer) =>
                              showCustomerRequestsSheet(
                                context,
                                customer: customer,
                                onAssign: (request) =>
                                    showChooseTechnicianSheet(
                                      context,
                                      requestId: request.id,
                                    ),
                              ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: showingTechnicians
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: "passiveTechs",
                  backgroundColor: Colors.blueGrey.shade600,
                  elevation: 4,
                  onPressed: () => showInactiveTechniciansSheet(context),
                  child: const Icon(Icons.visibility, color: Colors.white),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  heroTag: "addTech",
                  backgroundColor: Colors.green.shade600,
                  elevation: 4,
                  onPressed: () => context.push(AppRoutes.addTechnician),
                  child: const Icon(
                    Icons.person_add,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ],
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

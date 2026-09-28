import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobil_proje/features/customers/data/customer_repository.dart';
import 'package:mobil_proje/features/customers/domain/customer.dart';
import 'package:mobil_proje/features/requests/data/request_providers.dart';
import 'package:mobil_proje/features/requests/domain/request_stats.dart';
import 'package:mobil_proje/features/company/presentation/widgets/status_chip.dart';

/// Şirket panelinin "Müşteriler" sekmesi: her müşteri ve talep sayıları.
class CustomersTab extends ConsumerWidget {
  const CustomersTab({super.key, required this.onShowRequests});

  /// Müşterinin taleplerini gösteren alt sayfayı açar.
  final void Function(Customer customer) onShowRequests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);
    // Sayılar tek bir "tüm talepler" akışından hesaplanır (eskiden her
    // müşteri kartı ayrı bir Firestore dinleyicisi açıyordu).
    final stats =
        ref.watch(requestStatsByCustomerProvider).valueOrNull ?? const {};

    final customers = customersAsync.valueOrNull;
    if (customers == null) {
      if (customersAsync.hasError) {
        return Center(
          child: Text(
            "Müşteriler yüklenemedi: ${customersAsync.error}",
            style: const TextStyle(color: Colors.white),
          ),
        );
      }
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }

    if (customers.isEmpty) return const _EmptyCustomers();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: customers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final customer = customers[index];
        return CustomerCard(
          customer: customer,
          stats: stats[customer.id] ?? const RequestStats(),
          onShowRequests: () => onShowRequests(customer),
        );
      },
    );
  }
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.people_outline,
              size: 72,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "Henüz müşteri yok",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Kayıtlı müşteri bulunmuyor",
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek müşteri kartı: ad, iletişim, talep sayıları.
class CustomerCard extends StatelessWidget {
  const CustomerCard({
    super.key,
    required this.customer,
    required this.stats,
    required this.onShowRequests,
  });

  final Customer customer;
  final RequestStats stats;
  final VoidCallback onShowRequests;

  @override
  Widget build(BuildContext context) {
    final name = customer.name ?? "Müşteri";
    final email = customer.email ?? "";
    final phone = customer.phone ?? "";
    final total = stats.total;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onShowRequests,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.blue.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (email.isNotEmpty)
                            _ContactRow(
                              icon: Icons.email_outlined,
                              text: email,
                              expand: true,
                            ),
                          if (phone.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: _ContactRow(
                                icon: Icons.phone_outlined,
                                text: phone,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: total > 0
                            ? Colors.blue.shade600
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "$total",
                        style: TextStyle(
                          color: total > 0
                              ? Colors.white
                              : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                if (total > 0) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: StatCountChip(
                          label: "Bekliyor",
                          count: stats.pending,
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCountChip(
                          label: "Devam",
                          count: stats.inProgress,
                          color: Colors.purple,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatCountChip(
                          label: "Tamamlandı",
                          count: stats.completed,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onShowRequests,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.assignment_outlined, size: 20),
                    label: Text(
                      total > 0 ? "İstekleri Gör ($total)" : "İstekleri Gör",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.text,
    this.expand = false,
  });

  final IconData icon;
  final String text;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
      overflow: expand ? TextOverflow.ellipsis : null,
    );
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 6),
        if (expand) Expanded(child: label) else label,
      ],
    );
  }
}

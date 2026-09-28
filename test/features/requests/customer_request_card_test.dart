import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobil_proje/features/requests/domain/request_status.dart';
import 'package:mobil_proje/features/requests/domain/service_request.dart';
import 'package:mobil_proje/features/requests/presentation/widgets/customer_request_card.dart';
import 'package:mobil_proje/features/technicians/data/technician_providers.dart';
import 'package:mobil_proje/features/technicians/domain/technician.dart';

/// Kartın hangi düğmeleri gösterdiğine durum makinesi karar verir. Bu testler
/// Firebase olmadan çalışır: teknisyen verisi provider override ile sahte
/// verilir.
void main() {
  Future<void> pumpCard(WidgetTester tester, ServiceRequest request) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          technicianProvider.overrideWith(
            (ref, id) async => Technician(id: id, name: 'Ahmet Usta'),
          ),
          technicianPhotoProvider.overrideWith((ref, id) async => null),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CustomerRequestCard(
                request: request,
                isExpanded: true,
                selectedStars: 0,
                commentController: controller,
                onToggle: () {},
                onStarSelected: (_) {},
                onChat: () {},
                onOpenMap: () {},
                onDelete: () {},
                onRate: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('bekleyen talep silinebilir, puanlanamaz', (tester) async {
    await pumpCard(
      tester,
      const ServiceRequest(
        id: 'r1',
        customerId: 'c1',
        status: RequestStatus.pending,
        issue: 'Kombi',
      ),
    );

    expect(find.text('Bekliyor'), findsOneWidget);
    expect(find.text('Talebi Sil'), findsOneWidget);
    expect(find.text('Hizmeti Değerlendir'), findsNothing);
    expect(find.text('Atanan Teknisyen'), findsNothing);
  });

  testWidgets('tamamlanan talep puanlanabilir, silinemez', (tester) async {
    await pumpCard(
      tester,
      const ServiceRequest(
        id: 'r2',
        customerId: 'c1',
        technicianId: 't1',
        status: RequestStatus.completed,
      ),
    );

    expect(find.text('Hizmeti Değerlendir'), findsOneWidget);
    expect(find.text('Talebi Sil'), findsNothing);
    expect(find.text('Ahmet Usta'), findsOneWidget);
    // Harita yalnız devam eden işte gösterilir.
    expect(find.text('Haritada Gör'), findsNothing);
  });

  testWidgets('puanlanmış talepte değerlendirme formu yok', (tester) async {
    await pumpCard(
      tester,
      const ServiceRequest(
        id: 'r3',
        customerId: 'c1',
        technicianId: 't1',
        status: RequestStatus.completed,
        rated: true,
      ),
    );

    expect(find.text('Hizmeti Değerlendir'), findsNothing);
  });
}

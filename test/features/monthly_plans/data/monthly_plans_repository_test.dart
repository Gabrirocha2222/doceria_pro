import 'package:doceria_pro/core/database/app_database.dart';
import 'package:doceria_pro/core/money/money.dart';
import 'package:doceria_pro/features/monthly_plans/data/monthly_plans_repository.dart';
import 'package:doceria_pro/features/monthly_plans/domain/monthly_plan.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  late AppDatabase database;
  late MonthlyPlansRepository repository;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = MonthlyPlansRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'saves a monthly plan with template items and builds monthly history locally',
    () async {
      final savedId = await repository.saveMonthlyPlan(
        MonthlyPlanUpsertInput(
          clientId: 'client-001',
          clientNameSnapshot: 'Helena',
          title: 'Mesversário da Helena',
          templateProductId: 'product-plan-001',
          templateProductNameSnapshot: 'Plano mensal premium',
          startDate: DateTime(2026, 1, 31),
          numberOfMonths: 4,
          contractedQuantity: 3,
          notes: 'Confirmar topo dois dias antes.',
          items: [
            MonthlyPlanItemInput(
              linkedProductId: 'product-bolo',
              itemNameSnapshot: 'Mini bolo do mês',
              flavorSnapshot: 'Brigadeiro',
              variationSnapshot: '15 cm',
              unitPrice: Money.fromCents(12000),
              quantity: 1,
              notes: 'Topo com vela',
            ),
            MonthlyPlanItemInput(
              linkedProductId: null,
              itemNameSnapshot: 'Docinhos extras',
              flavorSnapshot: null,
              variationSnapshot: '20 unidades',
              unitPrice: Money.fromCents(2500),
              quantity: 2,
              notes: null,
            ),
          ],
        ),
      );

      final monthlyPlan = await repository.getMonthlyPlan(savedId);

      expect(monthlyPlan, isNotNull);
      expect(monthlyPlan!.id, savedId);
      expect(monthlyPlan.clientNameSnapshot, 'Helena');
      expect(monthlyPlan.displayTemplateProductName, 'Plano mensal premium');
      expect(monthlyPlan.numberOfMonths, 4);
      expect(monthlyPlan.contractedQuantity, 3);
      expect(monthlyPlan.items, hasLength(2));
      expect(monthlyPlan.estimatedItemCount, 3);
      expect(monthlyPlan.estimatedMonthlyTotal.cents, 17000);
      expect(monthlyPlan.remainingBalance, 3);
      expect(monthlyPlan.availableToGenerateCount, 3);
      expect(
        monthlyPlan.sortedHistory.map((occurrence) => occurrence.scheduledDate),
        [
          DateTime(2026, 1, 31),
          DateTime(2026, 2, 28),
          DateTime(2026, 3, 31),
          DateTime(2026, 4, 30),
        ],
      );
      expect(
        monthlyPlan.sortedHistory.every(
          (occurrence) =>
              occurrence.status == MonthlyPlanOccurrenceStatus.planned,
        ),
        isTrue,
      );
    },
  );
}

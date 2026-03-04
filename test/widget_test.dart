import 'package:flutter_test/flutter_test.dart';
import 'package:fulfillment_master/main.dart';

void main() {
  testWidgets('App initialization test', (WidgetTester tester) async {
    await tester.pumpWidget(const FulfillmentApp());
    expect(find.byType(FulfillmentApp), findsOneWidget);
  });
}

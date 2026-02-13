import 'package:flutter_test/flutter_test.dart';
import 'package:eldercare_ai/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ElderCareApp());
    expect(find.text('ElderCare AI'), findsOneWidget);
  });
}

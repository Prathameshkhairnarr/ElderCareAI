import 'package:flutter_test/flutter_test.dart';
import 'package:eldercare_ai/main.dart';
import 'package:eldercare_ai/screens/login_screen.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(ElderCareApp(homeWidget: const LoginScreen()));
    expect(find.text('ElderCare AI'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:app_medicina/main.dart';

void main() {
  testWidgets('Login screen shows MediConnect branding', (WidgetTester tester) async {
    await tester.pumpWidget(const MediConnectApp());

    expect(find.text('MediConnect'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsNWidgets(2));
    expect(find.textContaining('specialist'), findsOneWidget);
  });
}

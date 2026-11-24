import 'package:flutter_test/flutter_test.dart';

import 'package:lumina/main.dart';

import 'ayuda_supabase.dart';

void main() {
  setUpAll(iniciarSupabaseDePrueba);

  testWidgets('La app abre en la pantalla de inicio de sesión',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LuminaApp());

    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
  });
}

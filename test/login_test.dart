import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumina/main.dart';

Future<void> _llenarYEnviar(
    WidgetTester tester, String correo, String clave) async {
  final campos = find.byType(TextField);
  await tester.enterText(campos.at(0), correo);
  await tester.enterText(campos.at(1), clave);
  await tester.pump();
  final boton = find.widgetWithText(FilledButton, 'Iniciar sesión');
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('El login no avanza con un correo inválido',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LuminaApp());
    await _llenarYEnviar(tester, 'ana', 'clave1234');

    expect(find.textContaining('Revisa el correo'), findsOneWidget);
    expect(find.text('Bienvenido'), findsOneWidget);
  });

  testWidgets('El login no avanza con una contraseña de menos de 8',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LuminaApp());
    await _llenarYEnviar(tester, 'ana@correo.com', '1234');

    expect(find.textContaining('al menos 8 caracteres'), findsOneWidget);
    expect(find.text('Bienvenido'), findsOneWidget);
  });

  testWidgets('El login avanza con datos válidos', (WidgetTester tester) async {
    await tester.pumpWidget(const LuminaApp());
    await _llenarYEnviar(tester, 'ana@correo.com', 'clave1234');

    expect(find.text('Bienvenido'), findsNothing);
  });
}

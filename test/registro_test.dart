import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumina/main.dart';

import 'ayuda_supabase.dart';

void main() {
  setUpAll(iniciarSupabaseDePrueba);

  testWidgets('El login muestra los botones de Google y Correo',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LuminaApp());

    expect(find.bySemanticsLabel('Iniciar sesión con Google'), findsOneWidget);
    expect(find.bySemanticsLabel('Iniciar sesión con tu correo Outlook'),
        findsOneWidget);
  });

  testWidgets('Desde el login se llega al registro y se puede volver',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LuminaApp());

    await tester.ensureVisible(find.text('Regístrate'));
    await tester.tap(find.text('Regístrate'));
    await tester.pumpAndSettle();

    expect(find.text('Crear cuenta'), findsWidgets);
    expect(find.bySemanticsLabel('Registrarte con Google'), findsOneWidget);

    await tester.ensureVisible(find.text('Inicia sesión'));
    await tester.tap(find.text('Inicia sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido'), findsOneWidget);
  });

  testWidgets('El registro avisa si las contraseñas no coinciden',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LuminaApp());
    await tester.ensureVisible(find.text('Regístrate'));
    await tester.tap(find.text('Regístrate'));
    await tester.pumpAndSettle();

    final campos = find.byType(TextField);
    await tester.enterText(campos.at(0), 'Ana');
    await tester.enterText(campos.at(1), 'ana@correo.com');
    await tester.enterText(campos.at(2), 'clave1234');
    await tester.enterText(campos.at(3), 'otraclave');
    await tester.pump();

    final boton = find.widgetWithText(FilledButton, 'Crear cuenta');
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pump();

    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
  });
}

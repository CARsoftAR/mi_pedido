import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pizzeria/main.dart';

void main() {
  testWidgets('MiPedidoApp construye MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const MiPedidoApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:incil_camp_app/app.dart';
import 'package:incil_camp_app/config/flavor.dart';

void main() {
  testWidgets('IncilApp boots into the bootstrap placeholder', (tester) async {
    await tester.pumpWidget(const IncilApp(flavor: Flavor.dev));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text(Flavor.dev.displayName), findsOneWidget);
  });
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/widgets/secure_keyboard.dart';

Future<SecureTextController> pumpKeyboard(
  WidgetTester tester, {
  bool shuffle = false,
  String lang = 'fr',
  Random? random,
}) async {
  final controller = SecureTextController();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SecureKeyboard(
            controller: controller,
            languageCode: lang,
            shuffle: shuffle,
            spaceLabel: 'space',
            random: random,
          ),
        ),
      ),
    ),
  );
  return controller;
}

Future<void> press(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  testWidgets('types letters, space, shift, accents and deletes', (
    tester,
  ) async {
    final c = await pumpKeyboard(tester);
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    await press(tester, 'Z'); // shifted label
    await press(tester, 'e'); // shift is one-shot
    await press(tester, 'space');
    await press(tester, 'éà');
    await press(tester, 'ç');
    await press(tester, 'ABC');
    await press(tester, 'a');
    expect(c.value, 'Ze ça');

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(c.value, 'Ze ç');
  });

  testWidgets('backspace removes whole emoji / grapheme', (tester) async {
    final c = await pumpKeyboard(tester)
      ..value = 'ok 👍🏽';
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(c.value, 'ok ');
  });

  testWidgets('numbers page', (tester) async {
    final c = await pumpKeyboard(tester);
    await press(tester, '?123');
    await press(tester, '4');
    await press(tester, '2');
    expect(c.value, '42');
  });

  testWidgets('shuffled layout still types the tapped character', (
    tester,
  ) async {
    final c = await pumpKeyboard(tester, shuffle: true, random: Random(7));
    await press(tester, 'k');
    await press(tester, 'o');
    expect(c.value, 'ko');
    // Not the standard AZERTY order on the first row.
    final a = tester.getTopLeft(find.text('a')).dx;
    final z = tester.getTopLeft(find.text('z')).dx;
    final y = tester.getTopLeft(find.text('a')).dy;
    final zy = tester.getTopLeft(find.text('z')).dy;
    expect(a < z && y == zy && (z - a) < 45, isFalse);
  });

  testWidgets('invisible to accessibility services', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpKeyboard(tester);
    expect(find.bySemanticsLabel(RegExp(r'^[a-z]$')), findsNothing);
    expect(find.bySemanticsLabel('space'), findsNothing);
    semantics.dispose();
  });

  testWidgets('never opens a platform text input connection', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.textInput,
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
    await pumpKeyboard(tester);
    await press(tester, 'a');
    await press(tester, 'b');
    expect(calls.where((m) => m.startsWith('TextInput.set')), isEmpty);
  });
}

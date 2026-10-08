import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/widgets/pin_pad.dart';

Future<List<String>> pumpPad(WidgetTester tester) async {
  final submitted = <String>[];
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        // Like the lock screen: the pad sits in a scroll view.
        body: SingleChildScrollView(
          child: PinEntry(
            title: 'PIN',
            minLength: 4,
            onSubmit: (pin) async {
              submitted.add(pin);
              return null;
            },
          ),
        ),
      ),
    ),
  );
  return submitted;
}

Future<void> submit(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('overlapping fingers: every digit counts', (tester) async {
    final submitted = await pumpPad(tester);
    // Second thumb lands before the first lifts, twice.
    final one = await tester.startGesture(tester.getCenter(find.text('1')));
    final two = await tester.startGesture(tester.getCenter(find.text('2')));
    await one.up();
    final three = await tester.startGesture(tester.getCenter(find.text('3')));
    await two.up();
    await three.up();
    await tester.tap(find.text('4'));
    await tester.pump();
    await submit(tester);
    expect(submitted, ['1234']);
  });

  testWidgets('a press that slides a little still counts', (tester) async {
    final submitted = await pumpPad(tester);
    for (final d in ['5', '6', '7', '8']) {
      final g = await tester.startGesture(tester.getCenter(find.text(d)));
      // Past the tap slop: a tap would have lost to the scroll view.
      await g.moveBy(const Offset(0, 24));
      await g.up();
    }
    await tester.pump();
    await submit(tester);
    expect(submitted, ['5678']);
  });

  testWidgets('the same digit fast, and backspace', (tester) async {
    final submitted = await pumpPad(tester);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('9'));
    }
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    await submit(tester);
    expect(submitted, ['9999']);
  });
}

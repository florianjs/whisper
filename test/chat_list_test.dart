import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper/l10n/app_localizations.dart';
import 'package:whisper/widgets/chat_list.dart';

Future<void> pumpList(
  WidgetTester tester, {
  VoidCallback? onUnpin,
  String? firstUnread,
  bool pinned = true,
}) async {
  // Index 0 is the newest; 150 is far up, never built at first.
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ChatList(
          itemCount: 200,
          idAt: (i) => 'm$i',
          // Varying heights, like messages.
          itemBuilder: (context, i) =>
              SizedBox(height: 40.0 + (i % 5) * 18, child: Text('message $i')),
          firstUnreadId: firstUnread,
          pinned: pinned
              ? PinnedInfo(id: 'm150', preview: 'message 150', onUnpin: onUnpin)
              : null,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('banner jumps to the pinned message; arrow comes back', (
    tester,
  ) async {
    await pumpList(tester);
    expect(find.text('Pinned message'), findsOneWidget);
    final pinnedRow = find.descendant(
      of: find.byType(ListView),
      matching: find.text('message 150'),
    );
    expect(pinnedRow.hitTestable(), findsNothing);
    expect(find.byTooltip('Latest messages').hitTestable(), findsNothing);

    await tester.tap(find.text('Pinned message'));
    await tester.pumpAndSettle();
    expect(pinnedRow.hitTestable(), findsOneWidget);

    await tester.tap(find.byTooltip('Latest messages'));
    await tester.pumpAndSettle();
    expect(find.text('message 0').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Latest messages').hitTestable(), findsNothing);
  });

  testWidgets('unpin only when allowed', (tester) async {
    await pumpList(tester);
    expect(find.byTooltip('Unpin'), findsNothing);
    var unpinned = false;
    await pumpList(tester, onUnpin: () => unpinned = true);
    await tester.tap(find.byTooltip('Unpin'));
    expect(unpinned, isTrue);
  });

  testWidgets('opens on the new messages divider when it is far up', (
    tester,
  ) async {
    await pumpList(tester, firstUnread: 'm120', pinned: false);
    await tester.pumpAndSettle();
    expect(find.text('New messages').hitTestable(), findsOneWidget);
    expect(find.text('message 120').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Latest messages').hitTestable(), findsOneWidget);
  });

  testWidgets('a few new messages: stays at the bottom', (tester) async {
    await pumpList(tester, firstUnread: 'm2', pinned: false);
    await tester.pumpAndSettle();
    expect(find.text('New messages').hitTestable(), findsOneWidget);
    expect(find.text('message 0').hitTestable(), findsOneWidget);
  });
}

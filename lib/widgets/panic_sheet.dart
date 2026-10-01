import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/account_wiper.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';
import 'hold_to_confirm.dart';
import 'ui.dart';

Future<void> showPanicSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    scrollable: true,
    builder: (_) => const PanicSheet(),
  );
}

class PanicSheet extends StatelessWidget {
  const PanicSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shield_outlined, color: c.danger, size: 34),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.panicTitle,
            textAlign: TextAlign.center,
            style: context.text.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            l.panicBody,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: c.muted),
          ),
          const SizedBox(height: 24),
          HoldToConfirm(
            label: l.panicHold,
            holdingLabel: l.panicHolding,
            onConfirmed: () async {
              final wiper = context.read<AccountWiper>();
              Navigator.of(context).pop();
              // Identity reset redirects to welcome; failures of individual
              // steps are swallowed so the wipe always goes as far as it can.
              await wiper.panic();
            },
          ),
        ],
      ),
    );
  }
}

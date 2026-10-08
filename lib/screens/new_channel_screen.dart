import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/channel_store.dart';
import '../data/relay_service.dart';
import '../l10n/app_localizations.dart';
import '../logic/channel.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/ui.dart';

class NewChannelScreen extends StatefulWidget {
  const NewChannelScreen({super.key});

  @override
  State<NewChannelScreen> createState() => _NewChannelScreenState();
}

class _NewChannelScreenState extends State<NewChannelScreen> {
  final _name = TextEditingController();
  final _about = TextEditingController();
  bool _public = true;
  bool _fullHistory = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    final pk = await context.read<ChannelStore>().create(
      name: _name.text,
      about: _about.text,
      public: _public,
      fullHistory: _fullHistory,
      relays: context.read<RelayService>().relays.keys.toList(),
    );
    if (!mounted) return;
    if (pk == null) {
      setState(() => _busy = false);
      return;
    }
    context.pushReplacement('/channel/$pk');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.c;
    return Scaffold(
      appBar: AppBar(title: Text(l.newChannel)),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Center(
                    child: IconBadge(
                      icon: Icons.campaign_rounded,
                      size: 72,
                      circle: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.newChannelSubtitle,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium?.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _name,
                    autofocus: true,
                    maxLength: Channel.maxName,
                    textCapitalization: TextCapitalization.sentences,
                    enableIMEPersonalizedLearning: false,
                    style: context.text.bodyLarge,
                    decoration: InputDecoration(hintText: l.channelName),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _about,
                    maxLength: Channel.maxAbout,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    enableIMEPersonalizedLearning: false,
                    style: context.text.bodyMedium,
                    decoration: InputDecoration(hintText: l.channelAbout),
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<bool>(
                    groupValue: _public,
                    onChanged: (v) => setState(() => _public = v ?? true),
                    child: Column(
                      children: [
                        ChannelOption(
                          value: true,
                          selected: _public,
                          icon: Icons.public_rounded,
                          title: l.channelPublic,
                          body: l.channelPublicBody,
                          onTap: () => setState(() => _public = true),
                        ),
                        const SizedBox(height: 10),
                        ChannelOption(
                          value: false,
                          selected: !_public,
                          icon: Icons.lock_rounded,
                          title: l.channelPrivate,
                          body: l.channelPrivateBody,
                          onTap: () => setState(() => _public = false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      l.channelHistory,
                      style: context.text.titleSmall?.copyWith(color: c.muted),
                    ),
                  ),
                  ChannelHistoryChoice(
                    fullHistory: _fullHistory,
                    onChanged: (v) => setState(() => _fullHistory = v),
                  ),
                  const SizedBox(height: 16),
                  NoticeCard(text: l.channelAdminNote, icon: Icons.key_rounded),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AppButton(
                label: l.channelCreate,
                expand: true,
                loading: _busy,
                onPressed: !_busy && _name.text.trim().isNotEmpty
                    ? _create
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full history / from when they follow, as two [ChannelOption]s.
class ChannelHistoryChoice extends StatelessWidget {
  const ChannelHistoryChoice({
    super.key,
    required this.fullHistory,
    required this.onChanged,
  });

  final bool fullHistory;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return RadioGroup<bool>(
      groupValue: fullHistory,
      onChanged: (v) => onChanged(v ?? true),
      child: Column(
        children: [
          ChannelOption(
            value: true,
            selected: fullHistory,
            icon: Icons.history_rounded,
            title: l.channelHistoryAll,
            body: l.channelHistoryAllBody,
            onTap: () => onChanged(true),
          ),
          const SizedBox(height: 10),
          ChannelOption(
            value: false,
            selected: !fullHistory,
            icon: Icons.update_rounded,
            title: l.channelHistoryJoin,
            body: l.channelHistoryJoinBody,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

/// Selectable card for a channel setting, with its radio.
class ChannelOption extends StatelessWidget {
  const ChannelOption({
    super.key,
    required this.value,
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final bool value;
  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: selected ? c.accentSoft : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: selected ? c.accent.withValues(alpha: 0.5) : c.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
          child: Row(
            children: [
              IconBadge(icon: icon, color: selected ? c.accent : c.muted),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: context.text.bodySmall?.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              Radio<bool>(value: value),
            ],
          ),
        ),
      ),
    );
  }
}

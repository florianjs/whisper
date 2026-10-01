import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/group_store.dart';
import '../data/message_store.dart';
import '../l10n/app_localizations.dart';
import '../logic/group.dart';
import '../theme/tokens.dart';
import '../widgets/app_button.dart';
import '../widgets/avatar.dart';
import '../widgets/ui.dart';

/// Creates a group, or adds members to [groupId] when given. Only accepted
/// contacts can be picked: inviting a stranger would hand them the member
/// list.
class NewGroupScreen extends StatefulWidget {
  const NewGroupScreen({super.key, this.groupId});

  final String? groupId;

  @override
  State<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends State<NewGroupScreen> {
  final _name = TextEditingController();
  final _picked = <String>{};
  bool _busy = false;

  bool get _adding => widget.groupId != null;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final groups = context.read<GroupStore>();
    if (_adding) {
      await groups.addMembers(widget.groupId!, _picked);
      if (mounted) context.pop();
      return;
    }
    final id = await groups.create(_name.text, _picked);
    if (!mounted) return;
    if (id == null) {
      setState(() => _busy = false);
      return;
    }
    context.pushReplacement('/group/$id');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final messages = context.watch<MessageStore>();
    final existing =
        context
            .watch<GroupStore>()
            .group(widget.groupId ?? '')
            ?.state
            .members ??
        const <String>{};
    final contacts = [
      for (final c in messages.conversations)
        if (!existing.contains(c.peer)) c.peer,
    ];
    // Me + already there + picked.
    final room =
        GroupState.maxMembers -
        (_adding ? existing.length : 1) -
        _picked.length;
    final ok =
        !_busy &&
        _picked.isNotEmpty &&
        (_adding || _name.text.trim().isNotEmpty);

    final c = context.c;
    return Scaffold(
      appBar: AppBar(title: Text(_adding ? l.groupAddMembers : l.newGroup)),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_adding)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: TextField(
                  controller: _name,
                  autofocus: true,
                  maxLength: 60,
                  textCapitalization: TextCapitalization.sentences,
                  enableIMEPersonalizedLearning: false,
                  style: context.text.bodyLarge,
                  decoration: InputDecoration(
                    hintText: l.groupName,
                    prefixIcon: Icon(Icons.groups_rounded, color: c.faint),
                  ),
                ),
              ),
            AnimatedSize(
              duration: AppMotion.normal,
              curve: AppMotion.curve,
              child: _picked.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : SizedBox(
                      height: 64,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        children: [
                          for (final peer in _picked)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _picked.remove(peer)),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Avatar(pubkey: peer, size: 44),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: c.surface2,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: c.bg,
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: c.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            SectionLabel(l.groupPickMembers(GroupState.maxMembers)),
            Expanded(
              child: contacts.isEmpty
                  ? EmptyState(
                      icon: Icons.person_search_rounded,
                      title: l.groupNoContacts,
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        for (final peer in contacts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: CheckboxListTile(
                              value: _picked.contains(peer),
                              onChanged: _picked.contains(peer) || room > 0
                                  ? (v) => setState(
                                      () => v == true
                                          ? _picked.add(peer)
                                          : _picked.remove(peer),
                                    )
                                  : null,
                              selected: _picked.contains(peer),
                              selectedTileColor: c.accentSoft,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg,
                                ),
                              ),
                              secondary: Avatar(pubkey: peer, size: 44),
                              title: Text(
                                messages.displayName(peer),
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleMedium,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: AppButton(
                label: _adding ? l.groupAddMembers : l.groupCreate,
                expand: true,
                loading: _busy,
                onPressed: ok ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

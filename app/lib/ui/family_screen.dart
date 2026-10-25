// 家庭同步页:登录 / 注册 → 验证邮箱 → 创建家庭或接受邀请 → 邀请家人、看成员、退出。
// 家庭成员权限完全相同:谁都能邀请、撤回邀请、读写全部数据;只能把自己移出家庭。

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cloud/account.dart';
import '../cloud/cloud_session.dart';
import '../cloud/family_service.dart';
import '../cloud/family_sync.dart';
import '../l10n/strings.dart';
import '../platform/export.dart';
import '../store/app_state.dart';
import 'widgets.dart';

void openFamilyScreen(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyScreen()));

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  @override
  void initState() {
    super.initState();
    // 第一次打开才初始化 Firebase(没开同步的人不会连 Google)
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<CloudSession>().start());
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = context.watch<CloudSession>();
    final body = switch (cs.phase) {
      CloudPhase.notConfigured => _Padded(children: [_InfoCard(icon: Icons.cloud_off_outlined, text: s.famNotConfigured)]),
      CloudPhase.idle => const Center(child: CircularProgressIndicator()),
      CloudPhase.signedOut => const _SignInView(),
      CloudPhase.unverified => const _VerifyView(),
      CloudPhase.noFamily => const _NoFamilyView(),
      CloudPhase.needsChoice => const _ChoiceView(),
      CloudPhase.inFamily => const _FamilyView(),
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(s.famTitle),
        bottom: cs.busy ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2)) : null,
      ),
      body: AbsorbPointer(absorbing: cs.busy, child: body),
    );
  }
}

/// 操作结果:失败时按错误类型给提示
void _reportError(BuildContext context, CloudSession cs) {
  final s = S.read(context);
  final e = cs.lastError;
  if (e == null) return;
  final msg = e is AccountException ? s.famAccountError(e.code) : '${s.famError}: $e';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

class _Padded extends StatelessWidget {
  final List<Widget> children;
  const _Padded({required this.children});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: children);
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoCard({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          ]),
        ),
      );
}

/// 删除账号(Google Play 要求应用内可删除):输入密码确认
Future<void> confirmDeleteAccount(BuildContext context) async {
  final s = S.read(context);
  final cs = context.read<CloudSession>();
  final pw = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(s.famDelete),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(s.famDeleteBody),
        const SizedBox(height: 12),
        TextField(controller: pw, obscureText: true, autofocus: true, decoration: InputDecoration(labelText: s.famPassword)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
          onPressed: () => Navigator.pop(c, true),
          child: Text(s.famDeleteBtn),
        ),
      ],
    ),
  );
  final password = pw.text;
  pw.dispose();
  if (ok != true || !context.mounted) return;
  if (await cs.deleteAccount(password)) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.famDeleted)));
  } else if (context.mounted) {
    _reportError(context, cs);
  }
}

class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton();
  @override
  Widget build(BuildContext context) => TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
        onPressed: () => confirmDeleteAccount(context),
        icon: const Icon(Icons.person_remove_outlined, size: 18),
        label: Text(S.of(context).famDelete),
      );
}

// ---------- 登录 / 注册 ----------

class _SignInView extends StatefulWidget {
  const _SignInView();
  @override
  State<_SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<_SignInView> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool show = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  bool _check() {
    final s = S.read(context);
    if (!looksLikeEmail(email.text)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.famBadEmail)));
      return false;
    }
    if (password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.famAccountError(AccountError.weakPassword))));
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = context.read<CloudSession>();
    return _Padded(children: [
      _InfoCard(icon: Icons.family_restroom, text: s.famIntro),
      const SizedBox(height: 16),
      TextField(
        controller: email,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        autofillHints: const [AutofillHints.email],
        decoration: InputDecoration(labelText: s.famEmail, prefixIcon: const Icon(Icons.alternate_email)),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: password,
        obscureText: !show,
        autofillHints: const [AutofillHints.password],
        decoration: InputDecoration(
          labelText: s.famPassword,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(icon: Icon(show ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => show = !show)),
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () async {
          if (!_check()) return;
          if (!await cs.signIn(email.text, password.text) && context.mounted) _reportError(context, cs);
        },
        child: Text(s.famSignIn),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () async {
          if (!_check()) return;
          if (!await cs.signUp(email.text, password.text) && context.mounted) _reportError(context, cs);
        },
        child: Text(s.famSignUp),
      ),
      TextButton(
        onPressed: () async {
          if (!looksLikeEmail(email.text)) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.famBadEmail)));
            return;
          }
          final ok = await cs.resetPassword(email.text);
          if (!context.mounted) return;
          if (ok) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.famResetSent)));
          } else {
            _reportError(context, cs);
          }
        },
        child: Text(s.famForgot),
      ),
    ]);
  }
}

// ---------- 验证邮箱 ----------

class _VerifyView extends StatelessWidget {
  const _VerifyView();
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = context.read<CloudSession>();
    return _Padded(children: [
      Text(s.famVerifyTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      _InfoCard(icon: Icons.mark_email_unread_outlined, text: s.famVerifyBody(cs.user?.email ?? '')),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () async {
          final ok = await cs.refreshVerification();
          if (!context.mounted) return;
          if (cs.lastError != null) {
            _reportError(context, cs);
          } else if (!ok) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.famNotVerifiedYet)));
          }
        },
        child: Text(s.famIVerified),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () async {
          final ok = await cs.resendVerification();
          if (!context.mounted) return;
          if (ok) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.famVerifySent)));
          } else {
            _reportError(context, cs);
          }
        },
        child: Text(s.famResend),
      ),
      TextButton(onPressed: cs.signOut, child: Text(s.famSignOut)),
    ]);
  }
}

// ---------- 不在家庭里:接受邀请或创建 ----------

/// 本机已有数据时问「合并」还是「只用家庭的」;没有数据直接用家庭的
Future<bool?> askKeepLocal(BuildContext context) async {
  final s = S.read(context);
  final st = context.read<AppState>();
  if (st.syncRecords().isEmpty || st.demoLoaded) return false;
  return showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(s.famLocalTitle),
      content: Text(s.famLocalBody),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(s.cancel)),
        OutlinedButton(onPressed: () => Navigator.pop(c, false), child: Text(s.famUseFamily)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.famMerge)),
      ],
    ),
  );
}

class _NoFamilyView extends StatelessWidget {
  const _NoFamilyView();
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = context.watch<CloudSession>();
    return _Padded(children: [
      Text(s.famSignedInAs(cs.user?.email ?? ''), style: Theme.of(context).textTheme.bodySmall),
      SectionTitle(s.famInvites, trailing: TextButton.icon(onPressed: cs.refreshInvites, icon: const Icon(Icons.refresh, size: 18), label: Text(s.famRefresh))),
      if (cs.invites.isEmpty)
        _InfoCard(icon: Icons.mail_outline, text: s.famNoInvites)
      else
        for (final inv in cs.invites)
          Card(
            child: ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: Text(s.famInviteFrom(inv.ownerLabel)),
              trailing: FilledButton(
                onPressed: () async {
                  final keep = await askKeepLocal(context);
                  if (keep == null || !context.mounted) return;
                  if (!await cs.joinFamily(inv.id, keepLocal: keep) && context.mounted) _reportError(context, cs);
                },
                child: Text(s.famJoin),
              ),
            ),
          ),
      SectionTitle(s.famNoFamily),
      _InfoCard(icon: Icons.family_restroom, text: s.famCreateDesc),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: () async {
          if (!await cs.createFamily() && context.mounted) _reportError(context, cs);
        },
        icon: const Icon(Icons.add_home_outlined),
        label: Text(s.famCreate),
      ),
      const SizedBox(height: 24),
      TextButton(onPressed: cs.signOut, child: Text(s.famSignOut)),
      const _DeleteAccountButton(),
    ]);
  }
}

/// 已在家庭里、这台设备是第一次接上且本机已有数据
class _ChoiceView extends StatelessWidget {
  const _ChoiceView();
  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = context.read<CloudSession>();
    return _Padded(children: [
      Text(s.famLocalTitle, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      _InfoCard(icon: Icons.merge_type, text: s.famLocalBody),
      const SizedBox(height: 16),
      FilledButton(onPressed: () => cs.attachThisDevice(keepLocal: true), child: Text(s.famMerge)),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: () => cs.attachThisDevice(keepLocal: false), child: Text(s.famUseFamily)),
      const SizedBox(height: 24),
      TextButton(onPressed: cs.signOut, child: Text(s.famSignOut)),
    ]);
  }
}

// ---------- 在家庭里 ----------

class _FamilyView extends StatefulWidget {
  const _FamilyView();
  @override
  State<_FamilyView> createState() => _FamilyViewState();
}

class _FamilyViewState extends State<_FamilyView> {
  final invite = TextEditingController();

  @override
  void dispose() {
    invite.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final s = S.read(context);
    final cs = context.read<CloudSession>();
    final email = normEmail(invite.text);
    if (!looksLikeEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.famBadEmail)));
      return;
    }
    final f = cs.family;
    if (f != null && (f.memberEmails.values.contains(email) || f.inviteEmails.contains(email))) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.famAlreadyIn)));
      return;
    }
    if (!await cs.invite(email)) {
      if (mounted) _reportError(context, cs);
      return;
    }
    invite.clear();
    if (mounted) await _sendInvite(email);
  }

  /// 学校通没有自己的发信服务器:邀请从家长自己的邮箱 / 微信发出
  Future<void> _sendInvite(String email) async {
    final s = S.read(context);
    final msg = s.famInviteMessage(email);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.famInvitedTitle(email)),
        content: Text(s.famInvitedBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(s.done)),
          OutlinedButton.icon(
            onPressed: () => shareOrCopy(c, msg, subject: s.famInviteSubject),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: Text(s.famShareInvite),
          ),
          FilledButton.icon(
            onPressed: () => openUrl(Uri(scheme: 'mailto', path: email, queryParameters: {'subject': s.famInviteSubject, 'body': msg}).toString()),
            icon: const Icon(Icons.email_outlined, size: 18),
            label: Text(s.famSendEmail),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cs = context.watch<CloudSession>();
    final f = cs.family;
    final me = cs.user?.uid;
    final status = cs.sync?.status.value ?? SyncStatus.connecting;
    final (IconData icon, String label, Color color) = switch (status) {
      SyncStatus.synced => (Icons.cloud_done_outlined, s.famSynced, const Color(0xFF2DA36A)),
      SyncStatus.pending => (Icons.cloud_upload_outlined, s.famPendingWrites, const Color(0xFF2E6BE6)),
      SyncStatus.offline => (Icons.cloud_off_outlined, s.famOffline, const Color(0xFFE09A1B)),
      SyncStatus.connecting => (Icons.cloud_sync_outlined, s.famConnecting, const Color(0xFF6B7A99)),
      SyncStatus.error => (Icons.error_outline, '${s.famError}: ${cs.sync?.lastError ?? ''}', const Color(0xFFE6563F)),
    };
    return _Padded(children: [
      Card(
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          subtitle: Text(s.famSignedInAs(cs.user?.email ?? '')),
        ),
      ),
      SectionTitle(s.famMembers),
      Card(
        child: Column(children: [
          for (final uid in f?.memberUids ?? const <String>[])
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(f!.memberEmails[uid] ?? uid),
              trailing: uid == me ? Chip(label: Text(s.famMe), visualDensity: VisualDensity.compact) : null,
            ),
        ]),
      ),
      if ((f?.inviteEmails ?? const []).isNotEmpty) ...[
        SectionTitle(s.famPending),
        Card(
          child: Column(children: [
            for (final e in f!.inviteEmails)
              ListTile(
                leading: const Icon(Icons.schedule_send_outlined),
                title: Text(e),
                onTap: () => _sendInvite(e),
                trailing: IconButton(
                  tooltip: s.famCancelInvite,
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    if (!await cs.cancelInvite(e) && context.mounted) _reportError(context, cs);
                  },
                ),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: TextField(
            controller: invite,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: InputDecoration(labelText: s.famInviteHint, prefixIcon: const Icon(Icons.person_add_alt)),
            onSubmitted: (_) => _invite(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: _invite, child: Text(s.famInviteBtn)),
      ]),
      const SizedBox(height: 24),
      _InfoCard(icon: Icons.info_outline, text: s.famIntro),
      const SizedBox(height: 16),
      OverflowBar(alignment: MainAxisAlignment.spaceBetween, spacing: 8, children: [
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          onPressed: () async {
            if (await confirmDialog(context, s.famLeaveConfirm) && !await cs.leaveFamily() && context.mounted) _reportError(context, cs);
          },
          icon: const Icon(Icons.logout),
          label: Text(s.famLeave),
        ),
        TextButton(
          onPressed: () async {
            if (await confirmDialog(context, s.famSignOutConfirm)) await cs.signOut();
          },
          child: Text(s.famSignOut),
        ),
      ]),
      const SizedBox(height: 8),
      const Align(alignment: Alignment.centerLeft, child: _DeleteAccountButton()),
    ]);
  }
}

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'bits.dart';
import 'buttons.dart';
import 'pop.dart';
import 'tappable.dart';

/// Top-bar button: "Backend offline" / "Sign in" / the logged-in user's name.
class AccountButton extends StatelessWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 700;

        if (!app.backendOnline) {
          return Tooltip(
            message: 'Backend is not running. Start it with: uvicorn app.main:app --reload\nTap to try again.',
            child: IconButton(
              onPressed: () async {
                await app.refreshAll();
                if (!context.mounted) return;
                toast(
                  context,
                  app.backendOnline ? 'Connected to the backend' : 'Backend still offline (demo mode)',
                  color: app.backendOnline ? AppColors.bull : AppColors.warn,
                  icon: app.backendOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                );
              },
              icon: const Icon(Icons.cloud_off_rounded, color: AppColors.warn),
            ),
          );
        }

        final user = app.user;
        if (user == null) {
          return AppButton(
            label: wide ? 'Sign in' : 'Login',
            icon: Icons.login_rounded,
            compact: true,
            onTap: () => showAuth(context),
          );
        }

        return Tappable(
          onTap: () => _showAccount(context),
          semanticLabel: 'Account',
          builder: (context, s) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.fromLTRB(5, 5, 12, 5),
            decoration: BoxDecoration(
              color: s.hover ? AppColors.panelHi : AppColors.panel,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: s.focus ? AppColors.text : AppColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppColors.brass,
                  child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                      style: AppText.body(12.5, color: AppColors.ink, w: FontWeight.w700)),
                ),
                if (wide) ...[
                  const SizedBox(width: 8),
                  Text(user.name.split(' ').first, style: AppText.body(13.5, w: FontWeight.w600)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAccount(BuildContext context) {
    final app = context.app;
    final user = app.user!;
    showPop<void>(
      context,
      maxWidth: 420,
      child: Builder(
        builder: (ctx) => PopCard(
          title: user.name,
          subtitle: user.email,
          icon: Icons.person_rounded,
          actions: [
            AppButton(
              label: 'Log out',
              icon: Icons.logout_rounded,
              kind: ButtonKind.ghost,
              color: AppColors.bear,
              onTap: () async {
                Navigator.of(ctx).pop();
                await app.logout();
                if (context.mounted) toast(context, 'Logged out');
              },
            ),
          ],
          child: Text(
            'Your portfolio, limits and alerts are saved on the CryptoSense server, and the server '
            'watches your alerts even when this page is closed.',
            style: AppText.body(14.5, color: AppColors.muted, height: 1.55),
          ),
        ),
      ),
    );
  }
}

Future<void> showAuth(BuildContext context) => showPop<void>(context, maxWidth: 460, child: const _AuthForm());

class _AuthForm extends StatefulWidget {
  const _AuthForm();

  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  String _mode = 'login';
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final app = context.app;
    final register = _mode == 'register';
    if ((register && _name.text.trim().length < 2) || !_email.text.contains('@') || _password.text.length < 6) {
      setState(() => _error = register
          ? 'Enter your name, a valid email and a password of at least 6 characters.'
          : 'Enter a valid email and your password (6+ characters).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (register) {
        await app.register(_name.text.trim(), _email.text.trim(), _password.text);
      } else {
        await app.login(_email.text.trim(), _password.text);
      }
      if (!mounted) return;
      toast(context, 'Welcome, ${app.user?.name ?? ''}! Your data is now saved on the server.');
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not reach the backend. Is uvicorn running?');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final register = _mode == 'register';
    return PopCard(
      title: register ? 'Create your account' : 'Welcome back',
      subtitle: 'Save your portfolio, limits and alerts on the server',
      icon: Icons.lock_person_rounded,
      actions: [
        AppButton(
          label: 'Cancel',
          kind: ButtonKind.ghost,
          color: AppColors.muted,
          onTap: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: _busy ? 'Please wait...' : (register ? 'Create account' : 'Sign in'),
          icon: register ? Icons.person_add_alt_1_rounded : Icons.login_rounded,
          onTap: _busy ? null : _submit,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentPills(
            options: const ['login', 'register'],
            labels: const {'login': 'Sign in', 'register': 'New account'},
            selected: _mode,
            onChanged: (m) => setState(() {
              _mode = m;
              _error = null;
            }),
          ),
          if (register) ...[
            const FieldLabel('Your name'),
            TextField(controller: _name, decoration: const InputDecoration(hintText: 'Muhammad Ali')),
          ],
          const FieldLabel('Email'),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'you@example.com'),
          ),
          const FieldLabel('Password'),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'At least 6 characters'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Text(_error!, style: AppText.body(13.5, color: AppColors.bear))
          else
            Text(
              'You can also keep using CryptoSense as a guest; guest data stays in this browser only.',
              style: AppText.body(13, color: AppColors.faint),
            ),
        ],
      ),
    );
  }
}
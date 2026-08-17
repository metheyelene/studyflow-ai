import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/glass/glass_button.dart';
import '../../shared/widgets/glass/glass_card.dart';
import '../../shared/widgets/glass/glass_input.dart';
import '../../shared/widgets/glass/glass_misc.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(authControllerProvider.notifier)
        .signIn(email: email, password: password);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
    // On success the router redirects to /home automatically.
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: GlassCard(
                tone: GlassTone.floating,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: g.primarySoft,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.auto_stories,
                        size: 26,
                        color: g.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Log in to continue studying.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: g.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    GlassInput(
                      controller: _email,
                      label: 'Email',
                      hintText: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.mail,
                    ),
                    const SizedBox(height: 12),
                    GlassInput(
                      controller: _password,
                      label: 'Password',
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.lock,
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: g.danger, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 16),
                    GlassButton(
                      label: _busy ? 'Logging in…' : 'Log in',
                      icon: Icons.login,
                      expand: true,
                      onPressed: _busy ? null : _submit,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => showGlassToast(
                              context,
                              'Password reset emails arrive soon on mobile.',
                            ),
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(color: g.textMuted, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'New to StudyFlow? ',
                          style: TextStyle(color: g.textMuted, fontSize: 13),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => context.go(AppRoutes.signup),
                          child: Text(
                            'Create an account',
                            style: TextStyle(
                              color: g.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

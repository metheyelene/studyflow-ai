import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? SwissColors.darkForeground : SwissColors.black;
    final mutedFg = isDark
        ? SwissColors.darkForeground.withValues(alpha: 0.5)
        : SwissColors.black.withValues(alpha: 0.5);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SwissSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    color: fg,
                    child: Icon(
                      Icons.auto_stories,
                      size: 26,
                      color: isDark ? SwissColors.darkBackground : SwissColors.white,
                    ),
                  ),
                  const SizedBox(height: SwissSpacing.xl),

                  // Title
                  Text(
                    'WELCOME BACK',
                    textAlign: TextAlign.center,
                    style: SwissTypography.section.copyWith(color: fg),
                  ),
                  const SizedBox(height: SwissSpacing.xs),
                  Text(
                    'Log in to continue studying.',
                    textAlign: TextAlign.center,
                    style: SwissTypography.body.copyWith(color: mutedFg),
                  ),
                  const SizedBox(height: SwissSpacing.xxl),

                  // Email
                  SwissInput(
                    controller: _email,
                    label: 'Email',
                    hintText: 'you@example.com',
                  ),
                  const SizedBox(height: SwissSpacing.md),

                  // Password
                  SwissInput(
                    controller: _password,
                    label: 'Password',
                    hintText: '••••••••',
                  ),

                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: SwissSpacing.md),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: SwissTypography.body.copyWith(
                        color: SwissColors.red,
                      ),
                    ),
                  ],
                  const SizedBox(height: SwissSpacing.xl),

                  // Submit
                  SwissButton(
                    label: _busy ? 'Logging in…' : 'Log in',
                    icon: Icons.login,
                    fullWidth: true,
                    onPressed: _busy ? null : _submit,
                  ),
                  const SizedBox(height: SwissSpacing.md),

                  // Forgot password
                  TextButton(
                    onPressed: _busy ? null : () {},
                    child: Text(
                      'Forgot password?',
                      style: SwissTypography.body.copyWith(color: mutedFg),
                    ),
                  ),
                  const SizedBox(height: SwissSpacing.sm),

                  // Sign up link
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'New to StudyFlow? ',
                        style: SwissTypography.body.copyWith(color: mutedFg),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => context.go(AppRoutes.signup),
                        child: Text(
                          'Create an account',
                          style: SwissTypography.bodyBold.copyWith(
                            color: fg,
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
    );
  }
}

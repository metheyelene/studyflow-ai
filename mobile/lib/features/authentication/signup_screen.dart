import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/swiss_tokens.dart';
import '../../shared/widgets/swiss/swiss_components.dart';
import 'auth_controller.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (name.isEmpty || email.isEmpty || password.length < 8) {
      setState(
        () => _error =
            'Use your name, a valid email, and a password of at least 8 characters.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await ref
        .read(authControllerProvider.notifier)
        .signUp(name: name, email: email, password: password);
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
                      color: isDark
                          ? SwissColors.darkBackground
                          : SwissColors.white,
                    ),
                  ),
                  const SizedBox(height: SwissSpacing.xl),

                  // Title
                  Text(
                    'CREATE YOUR ACCOUNT',
                    textAlign: TextAlign.center,
                    style: SwissTypography.section.copyWith(color: fg),
                  ),
                  const SizedBox(height: SwissSpacing.xs),
                  Text(
                    'Free to start — no card needed.',
                    textAlign: TextAlign.center,
                    style: SwissTypography.body.copyWith(color: mutedFg),
                  ),
                  const SizedBox(height: SwissSpacing.xxl),

                  // Name
                  SwissInput(
                    controller: _name,
                    label: 'Name',
                    hintText: 'Your name',
                  ),
                  const SizedBox(height: SwissSpacing.md),

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
                    hintText: 'At least 8 characters',
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
                    label: _busy ? 'Creating account…' : 'Create account',
                    icon: Icons.person_add_alt,
                    fullWidth: true,
                    onPressed: _busy ? null : _submit,
                  ),
                  const SizedBox(height: SwissSpacing.md),

                  // Login link
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: SwissTypography.body.copyWith(color: mutedFg),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => context.go(AppRoutes.login),
                        child: Text(
                          'Log in',
                          style: SwissTypography.bodyBold.copyWith(color: fg),
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

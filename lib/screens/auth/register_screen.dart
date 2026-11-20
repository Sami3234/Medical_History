import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/info_banner.dart';
import '../../utils/extensions.dart';
import '../../widgets/app_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirmPass = TextEditingController();
  bool _passwordChanged = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _confirmPass.dispose();
    super.dispose();
  }

  String _passwordStrength(String password) {
    if (password.isEmpty) return '';
    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    if (score <= 1) return 'Weak';
    if (score == 2) return 'Fair';
    if (score == 3) return 'Good';
    return 'Strong';
  }

  Color _passwordStrengthColor(String strength) {
    return switch (strength) {
      'Weak' => AppColors.error,
      'Fair' => AppColors.warning,
      'Good' => AppColors.info,
      'Strong' => AppColors.success,
      _ => AppColors.textLight,
    };
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.signUp(
      email: _email.text.trim(),
      password: _pass.text,
      fullName: _name.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      if (auth.emailConfirmationRequired) {
        if (mounted) {
          context.go(
            '${AppRoutes.verifyEmail}?email=${Uri.encodeComponent(_email.text.trim())}',
          );
        }
      } else {
        context.go(AppRoutes.ownerSetup);
      }
    } else {
      context.showSnack(auth.error ?? 'Registration failed', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                const AppLogo(size: 48, borderRadius: 14),
                const SizedBox(height: 18),
                Text(
                  'START YOUR HEALTH SPACE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Create account',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage everyone\'s care under one account.',
                  style: TextStyle(
                    fontSize: 14,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                // Full Name
                Text(
                  'Full name',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    hintText: 'Enter your full name',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: context.appTextSecondary,
                      size: 20,
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Please enter your name'
                      : null,
                ),
                const SizedBox(height: 18),
                // Email
                Text(
                  'Email address',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    prefixIcon: Icon(
                      Icons.mail_outline_rounded,
                      color: context.appTextSecondary,
                      size: 20,
                    ),
                  ),
                  validator: (v) => (v == null || !v.contains('@'))
                      ? 'Please enter valid email'
                      : null,
                ),
                const SizedBox(height: 18),
                // Password
                Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _pass,
                  onChanged: (_) => setState(() => _passwordChanged = true),
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter password',
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: context.appTextSecondary,
                      size: 20,
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                if (_passwordChanged && _pass.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: switch (_passwordStrength(_pass.text)) {
                            'Weak' => 0.25,
                            'Fair' => 0.5,
                            'Good' => 0.75,
                            'Strong' => 1,
                            _ => 0,
                          },
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(4),
                          color: _passwordStrengthColor(
                            _passwordStrength(_pass.text),
                          ),
                          backgroundColor: context.appSurfaceRaised,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _passwordStrength(_pass.text),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _passwordStrengthColor(
                            _passwordStrength(_pass.text),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                // Confirm Password
                Text(
                  'Confirm password',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmPass,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: 'Enter password again',
                    prefixIcon: Icon(
                      Icons.lock_outline_rounded,
                      color: context.appTextSecondary,
                      size: 20,
                    ),
                  ),
                  validator: (v) {
                    if (v != _pass.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Privacy Banner
                const InfoBanner(
                  icon: Icons.verified_user_outlined,
                  title: 'Privacy comes first',
                  subtitle: 'Only you can access your family health data.',
                ),
                const SizedBox(height: 24),
                // Create my account button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: auth.loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: auth.loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Create my account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: context.appTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

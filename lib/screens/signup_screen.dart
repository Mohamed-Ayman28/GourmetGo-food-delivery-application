import 'package:flutter/material.dart';
import '../widgets/auth_widget.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _agreeToTerms = false;
  String? _emailError;
  String? _passwordError;

  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeIn));
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  /// Validates email and password, returning true when both are valid.
  bool _validate() {
    String? emailErr;
    String? passErr;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      emailErr = 'Email is required.';
    } else if (!email.contains('@')) {
      emailErr = 'Please enter a valid email address.';
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      passErr = 'Password is required.';
    } else if (password.length < 8) {
      passErr = 'Password must be at least 8 characters.';
    }

    setState(() {
      _emailError = emailErr;
      _passwordError = passErr;
    });

    return emailErr == null && passErr == null;
  }

  void _onSignUp() {
    if (_validate()) {
      // TODO: proceed with sign up
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AuthHeader(variant: AuthHeaderVariant.inline),
                  const SizedBox(height: 28),

                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: const TextSpan(
                      text: 'Start your ',
                      style: TextStyle(fontSize: 14, color: Color(0xFF888888)),
                      children: [
                        TextSpan(
                          text: 'culinary journey',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF555555),
                          ),
                        ),
                        TextSpan(text: ' with us today.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Full Name field
                  const AuthFieldLabel('Full Name'),
                  const SizedBox(height: 8),
                  AuthInputField(
                    controller: _nameController,
                    hint: 'Enter your full name',
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 20),

                  const AuthFieldLabel('Email Address'),
                  const SizedBox(height: 8),
                  AuthInputField(
                    controller: _emailController,
                    hint: 'email@example.com',
                    prefixIcon: Icons.mail_outline,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _emailError,
                  ),
                  const SizedBox(height: 20),

                  const AuthFieldLabel('Password'),
                  const SizedBox(height: 8),
                  AuthPasswordField(
                    controller: _passwordController,
                    hint: 'Min. 8 characters',
                    showPrefixIcon: true,
                    errorText: _passwordError,
                  ),
                  const SizedBox(height: 20),

                  // Terms & Conditions checkbox
                  _TermsCheckbox(
                    value: _agreeToTerms,
                    onChanged: (v) => setState(() => _agreeToTerms = v),
                  ),
                  const SizedBox(height: 28),

                  AuthPrimaryButton(label: 'Sign Up', onTap: _onSignUp),
                  const SizedBox(height: 24),

                  const AuthDivider(label: 'or continue with'),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: AuthSocialButton(
                          label: 'Google',
                          icon: Icons.g_mobiledata,
                          iconColor: const Color(0xFFDB4437),
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: AuthSocialButton(
                          label: 'Apple',
                          icon: Icons.apple,
                          iconColor: Colors.black,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  AuthFooterLink(
                    prefixText: 'Already have an account? ',
                    actionText: 'Log in',
                    onTap: () => Navigator.of(context).pop(),
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

class _TermsCheckbox extends StatelessWidget {
  const _TermsCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? const Color(0xFFFF5722) : Colors.white,
              border: Border.all(
                color: value
                    ? const Color(0xFFFF5722)
                    : const Color(0xFFCCCCCC),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: value
                ? const Icon(Icons.check, color: Colors.white, size: 12)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: const TextSpan(
                text: 'I agree to the ',
                style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                children: [
                  TextSpan(
                    text: 'Terms of Service',
                    style: TextStyle(
                      color: Color(0xFFFF5722),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: Color(0xFFFF5722),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

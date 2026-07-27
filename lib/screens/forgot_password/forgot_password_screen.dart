import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gourmet_go/widgets/custom_snackbar.dart';
import 'package:gourmet_go/widgets/auth_widget.dart';
import 'otp_verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestOTP() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      CustomSnackBar.show(
        context,
        message: 'Please enter your email address.',
        type: SnackBarType.error,
      );
      return;
    }

    // Basic email validation
    if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email)) {
      CustomSnackBar.show(
        context,
        message: 'Please enter a valid email address.',
        type: SnackBarType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await FirebaseFunctions.instance.httpsCallable('requestPasswordReset').call({
        'email': email,
      });

      if (!mounted) return;

      if (result.data['success'] == true) {
        CustomSnackBar.show(
          context,
          message: 'OTP sent to $email. Please check your inbox.',
          type: SnackBarType.success,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(email: email),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: e.message ?? 'An error occurred.',
        type: SnackBarType.error,
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Network error. Please try again later.',
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F0),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Enter the email associated with your account and we\'ll send you a 6-digit OTP to reset your password.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF888888),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              
              AuthInputField(
                controller: _emailController,
                hint: 'Email Address',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 30),
              
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF5722)),
                )
              else
                AuthPrimaryButton(
                  label: 'Send OTP',
                  onTap: _requestOTP,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gourmet_go/widgets/custom_snackbar.dart';
import 'package:gourmet_go/widgets/auth_widget.dart';
import 'package:gourmet_go/screens/login_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  const OtpVerificationScreen({super.key, required this.email});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isResending = false;
  
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendOTP() async {
    if (_countdown > 0) return;
    
    setState(() => _isResending = true);
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('requestPasswordReset').call({
        'email': widget.email,
      });
      if (!mounted) return;
      if (result.data['success'] == true) {
        CustomSnackBar.show(
          context,
          message: 'A new OTP has been sent to your email.',
          type: SnackBarType.success,
        );
        _startCountdown();
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(context, message: e.message ?? 'An error occurred.', type: SnackBarType.error);
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(context, message: 'Network error. Please try again.', type: SnackBarType.error);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _verifyAndReset() async {
    final otp = _otpController.text.trim();
    final newPassword = _passwordController.text.trim();
    
    if (otp.isEmpty || otp.length < 6) {
      CustomSnackBar.show(context, message: 'Please enter a valid 6-digit OTP.', type: SnackBarType.error);
      return;
    }
    if (newPassword.length < 6) {
      CustomSnackBar.show(context, message: 'Password must be at least 6 characters.', type: SnackBarType.error);
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final result = await FirebaseFunctions.instance.httpsCallable('verifyOTPAndResetPassword').call({
        'email': widget.email,
        'otp': otp,
        'newPassword': newPassword,
      });

      if (!mounted) return;

      if (result.data['success'] == true) {
        CustomSnackBar.show(
          context,
          message: 'Password reset successful! You can now log in.',
          type: SnackBarType.success,
        );
        
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(context, message: e.message ?? 'Verification failed.', type: SnackBarType.error);
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(context, message: 'Network error. Please try again later.', type: SnackBarType.error);
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
                'Verify OTP',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the 6-digit code sent to ${widget.email} and create your new password.',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF888888),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              
              AuthInputField(
                controller: _otpController,
                hint: '6-digit OTP',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              
              AuthPasswordField(
                controller: _passwordController,
                hint: 'New Password',
              ),
              const SizedBox(height: 30),
              
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Color(0xFFFF5722)))
              else
                AuthPrimaryButton(
                  label: 'Reset Password',
                  onTap: _verifyAndReset,
                ),
                
              const SizedBox(height: 24),
              Center(
                child: _isResending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5722)),
                      )
                    : TextButton(
                        onPressed: _countdown == 0 ? _resendOTP : null,
                        child: Text(
                          _countdown > 0
                              ? 'Resend OTP in ${_countdown}s'
                              : 'Resend OTP',
                          style: TextStyle(
                            color: _countdown > 0 ? Colors.grey : const Color(0xFFFF5722),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

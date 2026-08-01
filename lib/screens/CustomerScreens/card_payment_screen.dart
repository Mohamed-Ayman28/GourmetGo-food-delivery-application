import 'package:flutter/material.dart';
import 'package:flutter_credit_card/flutter_credit_card.dart';
import 'package:gourmet_go/consts/appColors.dart';

/// A full-screen card payment entry page powered by [flutter_credit_card].
///
/// Presents an animated credit-card widget that flips to show the CVV on the
/// back when the CVV field is focused, plus a form with real-time validation.
///
/// Call:
/// ```dart
/// final confirmed = await Navigator.push<bool>(
///   context,
///   MaterialPageRoute(builder: (_) => CardPaymentScreen(totalAmount: 29.99)),
/// );
/// if (confirmed == true) { /* place order */ }
/// ```
class CardPaymentScreen extends StatefulWidget {
  /// Grand total to display on the Confirm button.
  final double totalAmount;

  const CardPaymentScreen({super.key, required this.totalAmount});

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  // ── Card state ──────────────────────────────────────────────────────────────
  String _cardNumber = '';
  String _expiryDate = '';
  String _cardHolderName = '';
  String _cvvCode = '';
  bool _isCvvFocused = false;
  bool _useGlassmorphism = false;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // ── Helper ──────────────────────────────────────────────────────────────────
  void _onCreditCardModelChange(CreditCardModel data) {
    setState(() {
      _cardNumber = data.cardNumber;
      _expiryDate = data.expiryDate;
      _cardHolderName = data.cardHolderName;
      _cvvCode = data.cvvCode;
      _isCvvFocused = data.isCvvFocused;
    });
  }

  void _onConfirm() {
    if (_formKey.currentState!.validate()) {
      // Return `true` to the caller so it can place the order
      Navigator.of(context).pop(true);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Apply a custom theme so the CreditCardForm input fields use our
      // brand colour for focused borders / labels / cursor.
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
            ),
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 1.8),
          ),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          floatingLabelStyle: const TextStyle(color: AppColors.primary),
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () => Navigator.pop(context, false),
          ),
          title: const Text(
            'Pay with Card',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          actions: [
            // Glassmorphism toggle
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Toggle glassmorphism',
                icon: Icon(
                  _useGlassmorphism
                      ? Icons.blur_on_rounded
                      : Icons.blur_off_rounded,
                  color: AppColors.primary,
                ),
                onPressed: () =>
                    setState(() => _useGlassmorphism = !_useGlassmorphism),
              ),
            ),
          ],
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              // ── Animated Credit Card ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: CreditCardWidget(
                  cardNumber: _cardNumber,
                  expiryDate: _expiryDate,
                  cardHolderName: _cardHolderName,
                  cvvCode: _cvvCode,
                  showBackView: _isCvvFocused,
                  cardBgColor: AppColors.primary,
                  isChipVisible: true,
                  isSwipeGestureEnabled: true,
                  obscureCardNumber: true,
                  obscureCardCvv: true,
                  enableFloatingCard: false,

                  glassmorphismConfig: _useGlassmorphism
                      ? Glassmorphism(
                          blurX: 10,
                          blurY: 10,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.25),
                              Colors.white.withValues(alpha: 0.08),
                            ],
                          ),
                        )
                      : null,
                  onCreditCardWidgetChange: (_) {},
                ),
              ),

              // ── Form ─────────────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        CreditCardForm(
                          formKey: _formKey,
                          cardNumber: _cardNumber,
                          expiryDate: _expiryDate,
                          cardHolderName: _cardHolderName,
                          cvvCode: _cvvCode,
                          isHolderNameVisible: true,
                          isCardNumberVisible: true,
                          isExpiryDateVisible: true,
                          enableCvv: true,
                          obscureCvv: true,
                          obscureNumber: false,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onCreditCardModelChange: _onCreditCardModelChange,
                          inputConfiguration: const InputConfiguration(
                            cardNumberDecoration: InputDecoration(
                              labelText: 'Card Number',
                              hintText: 'XXXX XXXX XXXX XXXX',
                              prefixIcon: Icon(Icons.credit_card_rounded),
                            ),
                            expiryDateDecoration: InputDecoration(
                              labelText: 'Expiry Date',
                              hintText: 'MM/YY',
                              prefixIcon: Icon(Icons.calendar_today_rounded),
                            ),
                            cvvCodeDecoration: InputDecoration(
                              labelText: 'CVV',
                              hintText: '•••',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                            cardHolderDecoration: InputDecoration(
                              labelText: 'Card Holder Name',
                              hintText: 'Full name on card',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                        ),
                        

                        const SizedBox(height: 16),

                        // ── Confirm Button ──────────────────────────────────
                        _ConfirmButton(
                          totalAmount: widget.totalAmount,
                          onPressed: _onConfirm,
                        ),

                        const SizedBox(height: 24),
                      ],
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

// ── Sub-widgets ──────────────────────────────────────────────────────────────



/// Primary confirm / pay button.
class _ConfirmButton extends StatelessWidget {
  final double totalAmount;
  final VoidCallback onPressed;

  const _ConfirmButton({
    required this.totalAmount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded, size: 18),
            const SizedBox(width: 10),
            Text(
              'Pay \$${totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

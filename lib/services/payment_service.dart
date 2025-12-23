import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class PaymentService {
  // Configure via --dart-define or environment variables when building
  // e.g., flutter run --dart-define=STRIPE_PUBLISHABLE_KEY=pk_test_xxx --dart-define=PAYMENT_INTENT_ENDPOINT=https://your-edge-function/create-payment-intent
  static const String _publishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String _paymentIntentEndpoint = String.fromEnvironment(
    'PAYMENT_INTENT_ENDPOINT',
    defaultValue: '',
  );

  static bool get isConfigured =>
      _publishableKey.isNotEmpty && _paymentIntentEndpoint.isNotEmpty;

  static Future<void> init() async {
    if (_publishableKey.isEmpty) {
      debugPrint('Stripe publishable key missing. Skipping Stripe init.');
      return;
    }
    Stripe.publishableKey = _publishableKey;
    await Stripe.instance.applySettings();
  }

  static Future<bool> startMembershipPayment({
    required BuildContext context,
    required String tierName,
    required int amountCents,
    required Map<String, dynamic> metadata,
  }) async {
    if (!isConfigured) {
      _showSnack(
        context,
        'Payments not configured. Set STRIPE_PUBLISHABLE_KEY and PAYMENT_INTENT_ENDPOINT.',
      );
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(_paymentIntentEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amountCents,
          'currency': 'gbp',
          'tier': tierName,
          'metadata': metadata,
        }),
      );

      if (response.statusCode != 200) {
        final body = response.body;
        debugPrint('Payment intent error: ${response.statusCode} $body');
        final snippet = body.length > 140 ? body.substring(0, 140) + '…' : body;
        _showSnack(
          context,
          'Payment config error (${response.statusCode}). ${snippet.isEmpty ? '' : snippet}',
        );
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final String? clientSecret =
          (data['paymentIntentClientSecret'] ??
                  data['clientSecret'] ??
                  data['paymentIntent'])
              as String?;

      if (clientSecret == null) {
        _showSnack(context, 'Payment config missing client secret.');
        return false;
      }

      final String? customerId =
          data['customerId'] as String? ?? data['customer'] as String?;
      final String? ephemeralKey = data['ephemeralKey'] as String?;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'RunRank',
          style: ThemeMode.dark,
          applePay: const PaymentSheetApplePay(merchantCountryCode: 'GB'),
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'GB',
            testEnv: true,
          ),
          customerId: customerId,
          customerEphemeralKeySecret: ephemeralKey,
          allowsDelayedPaymentMethods: false,
        ),
      );

      try {
        await Stripe.instance.presentPaymentSheet();
        return true;
      } on StripeException catch (se) {
        final msg =
            se.error.localizedMessage ?? se.error.message ?? 'Stripe error';
        debugPrint('Stripe exception: $msg');
        _showSnack(context, 'Payment failed: $msg');
        return false;
      }
    } catch (e) {
      debugPrint('Payment error: $e');
      _showSnack(context, 'Payment cancelled or failed: $e');
      return false;
    }
  }

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

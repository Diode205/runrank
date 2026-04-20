import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

enum PaymentFlow { club, platform }

class _PaymentFlowConfig {
  const _PaymentFlowConfig({
    required this.publishableKey,
    required this.paymentIntentEndpoint,
    required this.label,
  });

  final String publishableKey;
  final String paymentIntentEndpoint;
  final String label;

  bool get isConfigured =>
      publishableKey.isNotEmpty && paymentIntentEndpoint.isNotEmpty;
}

class PaymentService {
  // Configure via --dart-define or environment variables when building
  // Club payments default to the legacy STRIPE_PUBLISHABLE_KEY and
  // PAYMENT_INTENT_ENDPOINT values to preserve current behavior.
  // Platform/app-subscription payments can be configured separately.
  static const String _publishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String _paymentIntentEndpoint = String.fromEnvironment(
    'PAYMENT_INTENT_ENDPOINT',
    defaultValue: '',
  );

  static const String _clubPublishableKey = String.fromEnvironment(
    'CLUB_STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String _clubPaymentIntentEndpoint = String.fromEnvironment(
    'CLUB_PAYMENT_INTENT_ENDPOINT',
    defaultValue: '',
  );

  static const String _platformPublishableKey = String.fromEnvironment(
    'PLATFORM_STRIPE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static const String _platformPaymentIntentEndpoint = String.fromEnvironment(
    'PLATFORM_PAYMENT_INTENT_ENDPOINT',
    defaultValue: '',
  );

  static const String _applePayMerchantId = String.fromEnvironment(
    'STRIPE_APPLE_PAY_MERCHANT_ID',
    defaultValue: '',
  );

  static const bool _enableNrrMembershipPayments = bool.fromEnvironment(
    'ENABLE_NRR_MEMBERSHIP_PAYMENTS',
    defaultValue: false,
  );

  static const bool _enableNrrKitPayments = bool.fromEnvironment(
    'ENABLE_NRR_KIT_PAYMENTS',
    defaultValue: false,
  );

  static String? _activePublishableKey;

  static _PaymentFlowConfig _configFor(PaymentFlow flow) {
    switch (flow) {
      case PaymentFlow.club:
        return _PaymentFlowConfig(
          publishableKey: _clubPublishableKey.isNotEmpty
              ? _clubPublishableKey
              : _publishableKey,
          paymentIntentEndpoint: _clubPaymentIntentEndpoint.isNotEmpty
              ? _clubPaymentIntentEndpoint
              : _paymentIntentEndpoint,
          label: 'club',
        );
      case PaymentFlow.platform:
        return const _PaymentFlowConfig(
          publishableKey: _platformPublishableKey,
          paymentIntentEndpoint: _platformPaymentIntentEndpoint,
          label: 'platform',
        );
    }
  }

  static bool get isConfigured => _configFor(PaymentFlow.club).isConfigured;

  static bool get clubPaymentsConfigured =>
      _configFor(PaymentFlow.club).isConfigured;

  static bool get platformPaymentsConfigured =>
      _configFor(PaymentFlow.platform).isConfigured;

  static bool get applePayConfigured => _applePayMerchantId.isNotEmpty;

  static bool get nrrMembershipPaymentsEnabled => _enableNrrMembershipPayments;

  static bool get nrrKitPaymentsEnabled => _enableNrrKitPayments;

  static Future<void> init() async {
    final clubConfig = _configFor(PaymentFlow.club);

    if (clubConfig.publishableKey.isEmpty) {
      debugPrint('Stripe publishable key missing. Skipping Stripe init.');
    } else {
      Stripe.publishableKey = clubConfig.publishableKey;
      _activePublishableKey = clubConfig.publishableKey;
    }

    if (_applePayMerchantId.isNotEmpty) {
      Stripe.merchantIdentifier = _applePayMerchantId;
    }

    await Stripe.instance.applySettings();
  }

  static Future<void> _ensureStripeConfigured(PaymentFlow flow) async {
    final config = _configFor(flow);
    if (!config.isConfigured) {
      return;
    }

    if (_activePublishableKey == config.publishableKey) {
      return;
    }

    Stripe.publishableKey = config.publishableKey;
    if (_applePayMerchantId.isNotEmpty) {
      Stripe.merchantIdentifier = _applePayMerchantId;
    }
    await Stripe.instance.applySettings();
    _activePublishableKey = config.publishableKey;
  }

  static Future<bool> startPayment({
    required BuildContext context,
    required PaymentFlow flow,
    required String itemName,
    required int amountCents,
    required Map<String, dynamic> metadata,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final config = _configFor(flow);

    if (!config.isConfigured) {
      final missingMessage = flow == PaymentFlow.club
          ? 'Payments not configured. Set CLUB_STRIPE_PUBLISHABLE_KEY/CLUB_PAYMENT_INTENT_ENDPOINT or the legacy STRIPE_PUBLISHABLE_KEY/PAYMENT_INTENT_ENDPOINT values.'
          : 'Platform payments not configured. Set PLATFORM_STRIPE_PUBLISHABLE_KEY and PLATFORM_PAYMENT_INTENT_ENDPOINT.';
      messenger.showSnackBar(SnackBar(content: Text(missingMessage)));
      return false;
    }

    await _ensureStripeConfigured(flow);

    try {
      final response = await http.post(
        Uri.parse(config.paymentIntentEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amountCents,
          'currency': 'gbp',
          'itemName': itemName,
          'metadata': {...metadata, 'payment_flow': config.label},
        }),
      );

      if (response.statusCode != 200) {
        final body = response.body;
        debugPrint(
          'Payment intent error (${config.label}): ${response.statusCode} $body',
        );
        final snippet = body.length > 140 ? '${body.substring(0, 140)}…' : body;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Payment config error (${response.statusCode}). ${snippet.isEmpty ? '' : snippet}',
            ),
          ),
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
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Payment config missing client secret.'),
          ),
        );
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
          applePay: applePayConfigured
              ? const PaymentSheetApplePay(merchantCountryCode: 'GB')
              : null,
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
        debugPrint('Stripe exception (${config.label}): $msg');
        messenger.showSnackBar(SnackBar(content: Text('Payment failed: $msg')));
        return false;
      }
    } catch (e) {
      debugPrint('Payment error (${config.label}): $e');
      messenger.showSnackBar(
        SnackBar(content: Text('Payment cancelled or failed: $e')),
      );
      return false;
    }
  }

  static Future<bool> startMembershipPayment({
    required BuildContext context,
    required String tierName,
    required int amountCents,
    required Map<String, dynamic> metadata,
  }) async {
    return startPayment(
      context: context,
      flow: PaymentFlow.club,
      itemName: tierName,
      amountCents: amountCents,
      metadata: {'tier': tierName, ...metadata},
    );
  }
}

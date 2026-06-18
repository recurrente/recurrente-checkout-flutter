import 'package:flutter/material.dart';
import 'package:recurrente_checkout_flutter/recurrente_checkout_flutter.dart';

void main() {
  runApp(const CheckoutExampleApp());
}

/// Minimal app that renders a Recurrente checkout.
class CheckoutExampleApp extends StatelessWidget {
  /// Creates the example app.
  const CheckoutExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recurrente Checkout',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const CheckoutExampleScreen(),
    );
  }
}

/// Example screen that shows the checkout full screen.
class CheckoutExampleScreen extends StatelessWidget {
  /// Creates the example checkout screen.
  const CheckoutExampleScreen({super.key});

  static final _checkoutUrl = Uri.parse(
    'https://app.recurrente.com/s/recurrente-gym/prod_g4pnrrya',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: RecurrenteCheckout(
          url: _checkoutUrl,
          onSuccess: (message) {
            _showMessage(
              context,
              'Payment completed: ${message.checkoutId ?? 'success'}',
            );
          },
          onFailure: (message) {
            _showMessage(
              context,
              'Payment failed: ${message.error ?? message.notice ?? 'failed'}',
            );
          },
          onPaymentInProgress: (message) {
            _showMessage(
              context,
              'Payment in progress: ${message.checkoutId ?? 'pending'}',
            );
          },
        ),
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

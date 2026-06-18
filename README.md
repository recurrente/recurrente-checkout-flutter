# Recurrente Checkout Flutter

Flutter package for embedding Recurrente Checkout in Android, iOS, and macOS
apps through a WebView.

The package follows the same principle as `recurrente-checkout` for the web:
it stays thin. It appends `embed=true`, renders the checkout URL, listens for
Recurrente checkout browser events, and forwards those events to your Dart
callbacks.

## Installation

Add the package to your Flutter app:

```yaml
dependencies:
  recurrente_checkout_flutter:
    path: ../recurrente-checkout-flutter
```

When this package is published, replace the path dependency with the published
version constraint.

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:recurrente_checkout_flutter/recurrente_checkout_flutter.dart';

class CheckoutScreen extends StatelessWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RecurrenteCheckout(
          url: Uri.parse('https://app.recurrente.com/s/recurrente-gym/prod_g4pnrrya'),
          onSuccess: (message) {
            debugPrint('Payment completed: ${message.checkoutId}');
          },
          onFailure: (message) {
            debugPrint('Payment failed: ${message.error ?? message.notice}');
          },
          onPaymentInProgress: (message) {
            debugPrint('Payment in progress: ${message.checkoutId}');
          },
        ),
      ),
    );
  }
}
```

## Callbacks

The checkout page emits the same event names used by the JavaScript wrapper:

- `recurrente-plugin:payment-success`
- `recurrente-plugin:payment-failed`
- `recurrente-plugin:payment-in-progress`

Each callback receives a `RecurrenteCheckoutMessage` with:

- `origin`
- `type`
- `checkoutId`
- `error`
- `notice`
- `payload`

By default, messages are accepted only from `https://app.recurrente.com`.
For local checkout development, pass `development: true`, or provide a custom
`allowedOrigin`.

## Platform Notes

Android apps need internet access in the app manifest if the host app does not
already include it:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Recurrente checkout URLs should use HTTPS in production.

## Example

See `example/lib/main.dart` for a minimal full-screen checkout app.

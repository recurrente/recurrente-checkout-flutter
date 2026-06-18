import 'package:flutter_test/flutter_test.dart';
import 'package:recurrente_checkout_flutter/recurrente_checkout_flutter.dart';

void main() {
  group('RecurrenteCheckout.embeddedUri', () {
    test('adds embed=true to a checkout URL without query parameters', () {
      final uri = RecurrenteCheckout.embeddedUri(
        Uri.parse('https://app.recurrente.com/checkout-session/ch_1234'),
      );

      expect(
        uri.toString(),
        'https://app.recurrente.com/checkout-session/ch_1234?embed=true',
      );
    });

    test('preserves existing query parameters and fragments', () {
      final uri = RecurrenteCheckout.embeddedUri(
        Uri.parse(
          'https://app.recurrente.com/s/org/product?coupon=WELCOME#details',
        ),
      );

      expect(
        uri.toString(),
        'https://app.recurrente.com/s/org/product?coupon=WELCOME&embed=true#details',
      );
    });

    test('does not add embed=true twice', () {
      final uri = RecurrenteCheckout.embeddedUri(
        Uri.parse(
          'https://app.recurrente.com/checkout-session/ch_1234?embed=true',
        ),
      );

      expect(
        uri.toString(),
        'https://app.recurrente.com/checkout-session/ch_1234?embed=true',
      );
    });

    test('replaces a non-embedded checkout mode', () {
      final uri = RecurrenteCheckout.embeddedUri(
        Uri.parse(
          'https://app.recurrente.com/checkout-session/ch_1234?embed=false',
        ),
      );

      expect(
        uri.toString(),
        'https://app.recurrente.com/checkout-session/ch_1234?embed=true',
      );
    });
  });

  group('RecurrenteCheckoutMessage', () {
    test('exposes typed helpers over the raw payload', () {
      const message = RecurrenteCheckoutMessage(
        origin: RecurrenteCheckout.defaultAllowedOrigin,
        payload: <String, dynamic>{
          'type': RecurrenteCheckoutMessage.paymentSuccessType,
          'checkoutId': 'ch_1234',
        },
      );

      expect(message.type, RecurrenteCheckoutMessage.paymentSuccessType);
      expect(message.checkoutId, 'ch_1234');
      expect(message.isSuccess, isTrue);
      expect(message.isFailure, isFalse);
      expect(message.isPaymentInProgress, isFalse);
    });
  });
}

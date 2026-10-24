import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:recurrente_checkout_flutter/src/checkout_protocol.dart';

void main() {
  test('preserves duplicate query values and replaces embed', () {
    final uri = CheckoutProtocol.embeddedUri(
      Uri.parse(
        'https://app.recurrente.com/s/x/y?tag=a&tag=b&embed=false#form',
      ),
    );
    expect(uri.queryParametersAll['tag'], ['a', 'b']);
    expect(uri.queryParametersAll['embed'], ['true']);
    expect(uri.fragment, 'form');
  });
  test('rejects HTTP, lookalike hosts, credentials and nonstandard ports', () {
    for (final value in [
      'http://app.recurrente.com/s/x',
      'https://app.recurrente.com.evil.test/s/x',
      'https://user@app.recurrente.com/s/x',
      'https://app.recurrente.com:8443/s/x',
    ]) {
      expect(
        () => CheckoutProtocol.embeddedUri(Uri.parse(value)),
        throwsArgumentError,
      );
    }
  });
  test(
    'accepts current session only, malformed and incomplete events are ignored',
    () {
      final raw = jsonEncode({
        'session': 'current',
        'data': {
          'type': 'recurrente-plugin:payment-success',
          'checkoutId': 'ch_test',
        },
      });
      expect(CheckoutProtocol.decode(raw, 'current')?.isSuccess, true);
      expect(CheckoutProtocol.decode(raw, 'previous'), isNull);
      expect(CheckoutProtocol.decode('{', 'current'), isNull);
      expect(CheckoutProtocol.decode('null', 'current'), isNull);
      expect(
        CheckoutProtocol.decode(
          jsonEncode({
            'session': 'current',
            'data': {'type': 'recurrente-plugin:payment-success'},
          }),
          'current',
        ),
        isNull,
      );
      expect(
        CheckoutProtocol.decode(
          jsonEncode({
            'session': 'current',
            'data': {
              'type': 'recurrente-plugin:payment-failed',
              'notice': 'Retry',
            },
          }),
          'current',
        )?.isFailure,
        true,
      );
    },
  );
  test('return route must match scheme host path and configured query', () {
    final routes = [Uri.parse('myapp://checkout/result?flow=pay')];
    expect(
      CheckoutProtocol.matchesReturn(
        Uri.parse('myapp://checkout/result?flow=pay&checkout_id=ch_test'),
        routes,
      ),
      true,
    );
    expect(
      CheckoutProtocol.matchesReturn(
        Uri.parse('myapp://checkout/result-evil?flow=pay'),
        routes,
      ),
      false,
    );
    expect(
      CheckoutProtocol.matchesReturn(
        Uri.parse('myapp://checkout/result?flow=other'),
        routes,
      ),
      false,
    );
  });
  test('listener is installed before frame navigation', () {
    final html = CheckoutProtocol.html(
      Uri.parse('https://app.recurrente.com/s/x/y'),
      'session',
    );
    expect(html.contains('__RECURRENTE_CONFIG__'), false);
    expect(
      html.indexOf("addEventListener('message'"),
      lessThan(html.indexOf('frame.src =')),
    );
  });
}

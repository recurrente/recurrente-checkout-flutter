import 'dart:convert';
import 'dart:math';
import 'checkout_shell.dart';
import 'recurrente_checkout_message.dart';

/// Internal transport contract shared with the other mobile wrappers.
class CheckoutProtocol {
  /// Exact trusted checkout origin.
  static const origin = 'https://app.recurrente.com';

  /// Local shell base URL for same-site hosted content.
  static const shellOrigin = 'https://app.recurrente.com';

  /// Unpredictable identifier to reject messages from previous loads.
  static String session() {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  /// Requires the hosted HTTPS origin and preserves existing query values.
  static Uri embeddedUri(Uri url) {
    if (url.scheme != 'https' ||
        url.host != 'app.recurrente.com' ||
        url.port != 443 ||
        url.userInfo.isNotEmpty) {
      throw ArgumentError.value(
        url,
        'url',
        'Use an HTTPS checkout URL from app.recurrente.com',
      );
    }
    return url.replace(
      queryParameters: <String, dynamic>{
        ...url.queryParametersAll,
        'embed': 'true',
      },
    );
  }

  /// Embeds escaped configuration into the canonical shell.
  static String html(Uri url, String session) {
    final config = jsonEncode({
      'url': embeddedUri(url).toString(),
      'origin': origin,
      'session': session,
    }).replaceAll('<', r'\u003c');
    return checkoutShell.replaceAll('__RECURRENTE_CONFIG__', config);
  }

  /// Accepts only known events for the active session.
  static RecurrenteCheckoutMessage? decode(String raw, String session) {
    if (raw.length > 65536) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['session'] != session) {
        return null;
      }
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) return null;
      if (![
        RecurrenteCheckoutMessage.paymentSuccessType,
        RecurrenteCheckoutMessage.paymentFailedType,
        RecurrenteCheckoutMessage.paymentInProgressType,
      ].contains(data['type'])) {
        return null;
      }
      if (data['type'] != RecurrenteCheckoutMessage.paymentFailedType &&
          (data['checkoutId'] is! String ||
              (data['checkoutId'] as String).isEmpty)) {
        return null;
      }
      return RecurrenteCheckoutMessage(
        origin: origin,
        payload: Map.unmodifiable(data),
      );
    } on FormatException {
      return null;
    }
  }

  /// Matches a configured route, never a paid status.
  static bool matchesReturn(Uri actual, List<Uri> routes) {
    if (actual.userInfo.isNotEmpty) return false;
    return routes.any(
      (expected) =>
          actual.scheme == expected.scheme &&
          actual.host == expected.host &&
          actual.port == expected.port &&
          actual.path == expected.path &&
          expected.queryParametersAll.entries.every(
            (entry) => entry.value.every(
              (v) => actual.queryParametersAll[entry.key]?.contains(v) ?? false,
            ),
          ),
    );
  }
}

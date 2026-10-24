/// Message sent by the Recurrente checkout page.
class RecurrenteCheckoutMessage {
  /// Creates a checkout message from a browser message payload.
  const RecurrenteCheckoutMessage({
    required this.origin,
    required this.payload,
  });

  /// Browser origin that emitted the checkout event.
  final String origin;

  /// Raw checkout event payload.
  final Map<String, dynamic> payload;

  /// Event name emitted by Recurrente checkout.
  String? get type => payload['type']?.toString();

  /// Checkout id included by success and pending-payment events when present.
  String? get checkoutId => payload['checkoutId']?.toString();

  /// Error value included by failure events when present.
  String? get error => payload['error']?.toString();

  /// Notice value included by failure events when present.
  String? get notice => payload['notice']?.toString();

  /// Whether this payload represents a successful payment.
  bool get isSuccess => type == paymentSuccessType;

  /// Whether this payload represents a failed payment.
  bool get isFailure => type == paymentFailedType;

  /// Whether this payload represents a payment still being processed.
  bool get isPaymentInProgress => type == paymentInProgressType;

  /// Browser message type emitted after a successful payment.
  static const paymentSuccessType = 'recurrente-plugin:payment-success';

  /// Browser message type emitted after a failed payment.
  static const paymentFailedType = 'recurrente-plugin:payment-failed';

  /// Browser message type emitted when a bank-transfer payment is processing.
  static const paymentInProgressType = 'recurrente-plugin:payment-in-progress';
}

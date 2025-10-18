/// Client-side PII redaction service
/// Strips emails, phones, addresses, and card-like numbers before any network call
class RedactionService {
  /// Redact PII from text
  static String redact(String text) {
    String redacted = text;

    // Redact email addresses
    redacted = redacted.replaceAllMapped(
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
      (match) => '[EMAIL]',
    );

    // Redact phone numbers (various formats)
    redacted = redacted.replaceAllMapped(
      RegExp(
        r'\b(?:\+?1[-.\s]?)?'
        r'(?:\(?\d{3}\)?[-.\s]?)?'
        r'\d{3}[-.\s]?\d{4}\b',
      ),
      (match) => '[PHONE]',
    );

    // Redact credit card-like numbers (13-19 digits with optional spaces/hyphens)
    redacted = redacted.replaceAllMapped(
      RegExp(r'\b(?:\d{4}[-\s]?){3,4}\d{1,4}\b'),
      (match) {
        final cleaned = match.group(0)!.replaceAll(RegExp(r'[-\s]'), '');
        if (cleaned.length >= 13 && cleaned.length <= 19) {
          return '[CARD]';
        }
        return match.group(0)!;
      },
    );

    // Redact SSN-like patterns (XXX-XX-XXXX)
    redacted = redacted.replaceAllMapped(
      RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),
      (match) => '[SSN]',
    );

    // Redact street addresses (basic pattern)
    redacted = redacted.replaceAllMapped(
      RegExp(
        r'\b\d+\s+[A-Z][a-z]+(\s+[A-Z][a-z]+)*\s+(Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct|Circle|Cir)\b',
        caseSensitive: false,
      ),
      (match) => '[ADDRESS]',
    );

    // Redact ZIP codes (US format)
    redacted = redacted.replaceAllMapped(
      RegExp(r'\b\d{5}(?:-\d{4})?\b'),
      (match) => '[ZIP]',
    );

    return redacted;
  }

  /// Check if text contains potential PII
  static bool containsPII(String text) {
    return text != redact(text);
  }

  /// Get list of redacted items for logging/debugging
  static List<String> getRedactedTypes(String text) {
    final redacted = redact(text);
    final types = <String>[];

    if (redacted.contains('[EMAIL]')) types.add('email');
    if (redacted.contains('[PHONE]')) types.add('phone');
    if (redacted.contains('[CARD]')) types.add('card');
    if (redacted.contains('[SSN]')) types.add('ssn');
    if (redacted.contains('[ADDRESS]')) types.add('address');
    if (redacted.contains('[ZIP]')) types.add('zip');

    return types;
  }
}








import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppShare {
  static Future<void> share(String text) async {
    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeFull(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Share.share(text);
    }
  }

  /// Opens WhatsApp directly to the given phone number with pre-filled text.
  /// [phone] can be in any local format — will be normalized to 92XXXXXXXXXX.
  static Future<void> shareWithPhone(String phone, String text) async {
    final normalized = _normalizePakistaniPhone(phone);
    final uri = Uri.parse(
      'whatsapp://send?phone=$normalized&text=${Uri.encodeFull(text)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Share.share(text);
    }
  }

  static String _normalizePakistaniPhone(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (cleaned.startsWith('92')) return cleaned;
    if (cleaned.startsWith('0')) return '92${cleaned.substring(1)}';
    return '92$cleaned';
  }
}

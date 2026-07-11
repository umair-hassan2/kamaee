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
}

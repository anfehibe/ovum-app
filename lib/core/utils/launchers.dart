import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> shareText(String text) async {
  await SharePlus.instance.share(ShareParams(text: text));
}

Future<void> openUrl(String url) async {
  if (url.isEmpty) return;
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Future<void> openEmail(String email) async {
  if (email.isEmpty) return;
  await launchUrl(Uri(scheme: 'mailto', path: email));
}

Future<void> openPhone(String phone) async {
  if (phone.isEmpty) return;
  await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
}

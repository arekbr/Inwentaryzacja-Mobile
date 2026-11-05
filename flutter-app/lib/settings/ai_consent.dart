import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _kAiConsent = 'ai_consent_v1';
const _kPrivacyPolicyUrl =
    'https://arekbr.github.io/Inwentaryzacja-Mobile/privacy/';

class AiConsentNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAiConsent) ?? false;
  }

  Future<void> setGranted(bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAiConsent, granted);
    state = AsyncValue.data(granted);
  }
}

final aiConsentProvider =
    AsyncNotifierProvider<AiConsentNotifier, bool>(AiConsentNotifier.new);

Future<void> openPrivacyPolicy() async {
  await launchUrl(Uri.parse(_kPrivacyPolicyUrl));
}

/// Zwraca `true`, gdy wolno wysłać zdjęcie do rozpoznania. Bez zapisanej zgody pyta użytkownika.
Future<bool> ensureAiConsent(BuildContext context, WidgetRef ref) async {
  if (await ref.read(aiConsentProvider.future)) return true;
  if (!context.mounted) return false;

  final granted = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Zgoda na wysłanie zdjęcia'),
      content: const Text(
        'Żeby rozpoznać eksponat, aplikacja wyśle to zdjęcie na serwer podany '
        'w Ustawieniach, a serwer przekaże je firmie Anthropic, która obsługuje '
        'model AI Claude.\n\nBez zgody pozostałe funkcje działają normalnie. '
        'Zgodę możesz wycofać w Ustawieniach.',
      ),
      actions: [
        const CupertinoDialogAction(
          onPressed: openPrivacyPolicy,
          child: Text('Polityka prywatności'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Nie teraz'),
        ),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Zgadzam się'),
        ),
      ],
    ),
  );
  if (granted != true) return false;

  await ref.read(aiConsentProvider.notifier).setGranted(true);
  return true;
}

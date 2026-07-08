// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Incil';

  @override
  String get loadingMessage => 'Wird geladen…';

  @override
  String get webviewLoadingMessage => 'App-Inhalte werden geladen…';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get offlineTitle => 'Keine Verbindung';

  @override
  String get offlineMessage =>
      'Bitte überprüfe deine Internetverbindung und versuche es erneut.';

  @override
  String get emergencyDefaultTitle => 'Notfall';

  @override
  String get emergencyCallButton => 'Notfallnummer anrufen';

  @override
  String emergencyLastUpdated(String timestamp) {
    return 'Aktualisiert: $timestamp';
  }

  @override
  String get forceUpdateDefaultTitle => 'Update erforderlich';

  @override
  String get forceUpdateAction => 'Update öffnen';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingSkip => 'Überspringen';

  @override
  String get onboardingDone => 'Los geht\'s';
}

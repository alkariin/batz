// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'batz';

  @override
  String get navHome => 'Accueil';

  @override
  String get navTransactions => 'Transactions';

  @override
  String get navYear => 'Année';

  @override
  String get navWealth => 'Fortune';

  @override
  String get navMore => 'Plus';

  @override
  String get emptyPage => 'Rien ici pour l\'instant.';

  @override
  String get startupErrorTitle => 'batz ne peut pas démarrer';

  @override
  String get startupErrorBody => 'La base de données locale n\'a pas pu être ouverte. Détail technique :';

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Confirmer';

  @override
  String get serverTitle => 'Serveur';

  @override
  String get serverPaired => 'Associé au serveur';

  @override
  String get serverNotPaired => 'Non associé';

  @override
  String get serverPairingIntro =>
      'Sur le serveur, lancez « batz-web pairing-code » puis saisissez ici son adresse et le code affiché.';

  @override
  String get serverAddress => 'Adresse du serveur';

  @override
  String get serverCode => 'Code d\'association';

  @override
  String get serverDeviceName => 'Nom de cet appareil';

  @override
  String get serverPair => 'Associer';

  @override
  String serverAddressValue(String address) {
    return 'Adresse : $address';
  }

  @override
  String serverVersion(String version) {
    return 'Version du serveur : $version';
  }

  @override
  String get serverFingerprint => 'Empreinte du certificat (à comparer avec celle affichée par le serveur)';

  @override
  String serverIncompatible(String version) {
    return 'Cette version de l\'app est trop ancienne pour le serveur, qui demande au moins la version $version. Mettez l\'app à jour.';
  }

  @override
  String get serverDevices => 'Appareils associés';

  @override
  String serverThisDevice(String name) {
    return '$name (cet appareil)';
  }

  @override
  String serverDeviceSince(String date) {
    return 'Associé le $date';
  }

  @override
  String serverDeviceRevoked(String date) {
    return 'Révoqué le $date';
  }

  @override
  String get serverRevoke => 'Révoquer';

  @override
  String serverRevokeConfirm(String name) {
    return 'Révoquer « $name » ? Cet appareil ne pourra plus accéder au serveur.';
  }

  @override
  String get serverRefresh => 'Actualiser';

  @override
  String get serverUnpair => 'Dissocier cet appareil';

  @override
  String get serverUnpairConfirm => 'Dissocier cet appareil ? Sa clé sera révoquée sur le serveur.';

  @override
  String get serverForget => 'Oublier ce serveur sur cet appareil';

  @override
  String get serverErrorAddress => 'Adresse invalide. Exemple : 192.168.1.95:8443.';

  @override
  String get serverErrorUnreachable =>
      'Serveur injoignable. Vérifiez qu\'il est allumé et que vous êtes sur le réseau de la maison.';

  @override
  String get serverErrorCertificate =>
      'Le serveur présente un autre certificat que celui mémorisé lors de l\'association. Connexion refusée.';

  @override
  String get serverErrorCodeInvalid => 'Code d\'association incorrect.';

  @override
  String get serverErrorCodeExpired => 'Ce code a expiré. Demandez-en un nouveau au serveur.';

  @override
  String get serverErrorCodeUsed => 'Ce code a déjà été utilisé. Demandez-en un nouveau au serveur.';

  @override
  String get serverErrorName => 'Le nom de l\'appareil doit compter de 1 à 64 caractères.';

  @override
  String get serverErrorRevoked => 'Cet appareil a été révoqué. Oubliez ce serveur puis associez-le à nouveau.';

  @override
  String get serverErrorOther => 'Le serveur a répondu par une erreur inattendue.';
}

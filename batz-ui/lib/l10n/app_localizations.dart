import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('fr')];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'batz'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navTransactions.
  ///
  /// In fr, this message translates to:
  /// **'Transactions'**
  String get navTransactions;

  /// No description provided for @navYear.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get navYear;

  /// No description provided for @navWealth.
  ///
  /// In fr, this message translates to:
  /// **'Fortune'**
  String get navWealth;

  /// No description provided for @navMore.
  ///
  /// In fr, this message translates to:
  /// **'Plus'**
  String get navMore;

  /// Placeholder shown on pages that have no content yet.
  ///
  /// In fr, this message translates to:
  /// **'Rien ici pour l\'instant.'**
  String get emptyPage;

  /// No description provided for @startupErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'batz ne peut pas démarrer'**
  String get startupErrorTitle;

  /// No description provided for @startupErrorBody.
  ///
  /// In fr, this message translates to:
  /// **'La base de données locale n\'a pas pu être ouverte. Détail technique :'**
  String get startupErrorBody;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer'**
  String get confirm;

  /// No description provided for @serverTitle.
  ///
  /// In fr, this message translates to:
  /// **'Serveur'**
  String get serverTitle;

  /// No description provided for @serverPaired.
  ///
  /// In fr, this message translates to:
  /// **'Associé au serveur'**
  String get serverPaired;

  /// No description provided for @serverNotPaired.
  ///
  /// In fr, this message translates to:
  /// **'Non associé'**
  String get serverNotPaired;

  /// No description provided for @serverPairingIntro.
  ///
  /// In fr, this message translates to:
  /// **'Sur le serveur, lancez « batz-web pairing-code » puis saisissez ici son adresse et le code affiché.'**
  String get serverPairingIntro;

  /// No description provided for @serverAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse du serveur'**
  String get serverAddress;

  /// No description provided for @serverCode.
  ///
  /// In fr, this message translates to:
  /// **'Code d\'association'**
  String get serverCode;

  /// No description provided for @serverDeviceName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de cet appareil'**
  String get serverDeviceName;

  /// No description provided for @serverPair.
  ///
  /// In fr, this message translates to:
  /// **'Associer'**
  String get serverPair;

  /// No description provided for @serverAddressValue.
  ///
  /// In fr, this message translates to:
  /// **'Adresse : {address}'**
  String serverAddressValue(String address);

  /// No description provided for @serverVersion.
  ///
  /// In fr, this message translates to:
  /// **'Version du serveur : {version}'**
  String serverVersion(String version);

  /// No description provided for @serverFingerprint.
  ///
  /// In fr, this message translates to:
  /// **'Empreinte du certificat (à comparer avec celle affichée par le serveur)'**
  String get serverFingerprint;

  /// No description provided for @serverIncompatible.
  ///
  /// In fr, this message translates to:
  /// **'Cette version de l\'app est trop ancienne pour le serveur, qui demande au moins la version {version}. Mettez l\'app à jour.'**
  String serverIncompatible(String version);

  /// No description provided for @serverDevices.
  ///
  /// In fr, this message translates to:
  /// **'Appareils associés'**
  String get serverDevices;

  /// No description provided for @serverThisDevice.
  ///
  /// In fr, this message translates to:
  /// **'{name} (cet appareil)'**
  String serverThisDevice(String name);

  /// No description provided for @serverDeviceSince.
  ///
  /// In fr, this message translates to:
  /// **'Associé le {date}'**
  String serverDeviceSince(String date);

  /// No description provided for @serverDeviceRevoked.
  ///
  /// In fr, this message translates to:
  /// **'Révoqué le {date}'**
  String serverDeviceRevoked(String date);

  /// No description provided for @serverRevoke.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer'**
  String get serverRevoke;

  /// No description provided for @serverRevokeConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Révoquer « {name} » ? Cet appareil ne pourra plus accéder au serveur.'**
  String serverRevokeConfirm(String name);

  /// No description provided for @serverRefresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get serverRefresh;

  /// No description provided for @serverUnpair.
  ///
  /// In fr, this message translates to:
  /// **'Dissocier cet appareil'**
  String get serverUnpair;

  /// No description provided for @serverUnpairConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Dissocier cet appareil ? Sa clé sera révoquée sur le serveur.'**
  String get serverUnpairConfirm;

  /// No description provided for @serverForget.
  ///
  /// In fr, this message translates to:
  /// **'Oublier ce serveur sur cet appareil'**
  String get serverForget;

  /// No description provided for @serverErrorAddress.
  ///
  /// In fr, this message translates to:
  /// **'Adresse invalide. Exemple : 192.168.1.95:8443.'**
  String get serverErrorAddress;

  /// No description provided for @serverErrorUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Serveur injoignable. Vérifiez qu\'il est allumé et que vous êtes sur le réseau de la maison.'**
  String get serverErrorUnreachable;

  /// No description provided for @serverErrorCertificate.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur présente un autre certificat que celui mémorisé lors de l\'association. Connexion refusée.'**
  String get serverErrorCertificate;

  /// No description provided for @serverErrorCodeInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Code d\'association incorrect.'**
  String get serverErrorCodeInvalid;

  /// No description provided for @serverErrorCodeExpired.
  ///
  /// In fr, this message translates to:
  /// **'Ce code a expiré. Demandez-en un nouveau au serveur.'**
  String get serverErrorCodeExpired;

  /// No description provided for @serverErrorCodeUsed.
  ///
  /// In fr, this message translates to:
  /// **'Ce code a déjà été utilisé. Demandez-en un nouveau au serveur.'**
  String get serverErrorCodeUsed;

  /// No description provided for @serverErrorName.
  ///
  /// In fr, this message translates to:
  /// **'Le nom de l\'appareil doit compter de 1 à 64 caractères.'**
  String get serverErrorName;

  /// No description provided for @serverErrorRevoked.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil a été révoqué. Oubliez ce serveur puis associez-le à nouveau.'**
  String get serverErrorRevoked;

  /// No description provided for @serverErrorOther.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur a répondu par une erreur inattendue.'**
  String get serverErrorOther;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @accountsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Comptes'**
  String get accountsTitle;

  /// No description provided for @accountsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte. Créez-en un avec le bouton +.'**
  String get accountsEmpty;

  /// No description provided for @accountsArchivedSection.
  ///
  /// In fr, this message translates to:
  /// **'Archivés'**
  String get accountsArchivedSection;

  /// No description provided for @accountNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau compte'**
  String get accountNew;

  /// No description provided for @accountEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le compte'**
  String get accountEdit;

  /// No description provided for @accountName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get accountName;

  /// No description provided for @accountType.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get accountType;

  /// No description provided for @accountImport.
  ///
  /// In fr, this message translates to:
  /// **'Import des relevés PostFinance'**
  String get accountImport;

  /// No description provided for @accountImportHint.
  ///
  /// In fr, this message translates to:
  /// **'Compte détaillé : ses transactions viennent uniquement des relevés. Un seul compte peut l\'être.'**
  String get accountImportHint;

  /// No description provided for @accountArchived.
  ///
  /// In fr, this message translates to:
  /// **'Archivé'**
  String get accountArchived;

  /// No description provided for @accountDetailed.
  ///
  /// In fr, this message translates to:
  /// **'Détaillé'**
  String get accountDetailed;

  /// No description provided for @accountDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le compte « {name} » ? S\'il est utilisé par des transactions, il sera archivé.'**
  String accountDeleteConfirm(String name);

  /// No description provided for @accountArchivedInstead.
  ///
  /// In fr, this message translates to:
  /// **'Compte archivé et non supprimé : {count, plural, =1{une transaction l\'utilise} other{{count} transactions l\'utilisent}}.'**
  String accountArchivedInstead(int count);

  /// No description provided for @accountDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Compte supprimé.'**
  String get accountDeleted;

  /// No description provided for @accountTypePrivateAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte privé'**
  String get accountTypePrivateAccount;

  /// No description provided for @accountTypeSavings.
  ///
  /// In fr, this message translates to:
  /// **'Épargne'**
  String get accountTypeSavings;

  /// No description provided for @accountTypePillar3.
  ///
  /// In fr, this message translates to:
  /// **'3e pilier'**
  String get accountTypePillar3;

  /// No description provided for @accountTypePillar2.
  ///
  /// In fr, this message translates to:
  /// **'2e pilier'**
  String get accountTypePillar2;

  /// No description provided for @accountTypeInvestments.
  ///
  /// In fr, this message translates to:
  /// **'Investissements'**
  String get accountTypeInvestments;

  /// No description provided for @accountTypeVehicle.
  ///
  /// In fr, this message translates to:
  /// **'Véhicule'**
  String get accountTypeVehicle;

  /// No description provided for @accountTypeRentDeposit.
  ///
  /// In fr, this message translates to:
  /// **'Garantie de loyer'**
  String get accountTypeRentDeposit;

  /// No description provided for @accountTypeCash.
  ///
  /// In fr, this message translates to:
  /// **'Espèces'**
  String get accountTypeCash;

  /// No description provided for @accountTypeDebts.
  ///
  /// In fr, this message translates to:
  /// **'Dettes'**
  String get accountTypeDebts;

  /// No description provided for @accountTypeOther.
  ///
  /// In fr, this message translates to:
  /// **'Autre'**
  String get accountTypeOther;

  /// No description provided for @errorNameRequired.
  ///
  /// In fr, this message translates to:
  /// **'Le nom est obligatoire.'**
  String get errorNameRequired;

  /// No description provided for @errorSecondDetailedAccount.
  ///
  /// In fr, this message translates to:
  /// **'Un seul compte peut être détaillé : l\'import est déjà activé sur un autre compte.'**
  String get errorSecondDetailedAccount;

  /// No description provided for @errorUnknownAccount.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte n\'existe plus.'**
  String get errorUnknownAccount;

  /// No description provided for @categoriesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Catégories'**
  String get categoriesTitle;

  /// No description provided for @categoriesYear.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get categoriesYear;

  /// No description provided for @categoriesNoTree.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore d\'arbre pour {year}.'**
  String categoriesNoTree(int year);

  /// No description provided for @categoriesNoTreeCopy.
  ///
  /// In fr, this message translates to:
  /// **'Il sera copié de l\'arbre {source}, puis modifiable sans effet sur {source}. La première transaction de {year} le crée aussi.'**
  String categoriesNoTreeCopy(int source, int year);

  /// No description provided for @categoriesNoTreeDefault.
  ///
  /// In fr, this message translates to:
  /// **'Il partira de deux groupes vides, « Revenus » et « Dépenses ». La première transaction de {year} le crée aussi.'**
  String categoriesNoTreeDefault(int year);

  /// No description provided for @categoriesCreateTree.
  ///
  /// In fr, this message translates to:
  /// **'Créer l\'arbre {year}'**
  String categoriesCreateTree(int year);

  /// No description provided for @categoriesNewGroup.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau groupe'**
  String get categoriesNewGroup;

  /// No description provided for @categoryName.
  ///
  /// In fr, this message translates to:
  /// **'Nom'**
  String get categoryName;

  /// No description provided for @categoryNature.
  ///
  /// In fr, this message translates to:
  /// **'Nature'**
  String get categoryNature;

  /// No description provided for @categoryAddChild.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une sous-catégorie'**
  String get categoryAddChild;

  /// No description provided for @categoryRename.
  ///
  /// In fr, this message translates to:
  /// **'Renommer'**
  String get categoryRename;

  /// No description provided for @categoryMove.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer'**
  String get categoryMove;

  /// No description provided for @categoryMoveUp.
  ///
  /// In fr, this message translates to:
  /// **'Monter'**
  String get categoryMoveUp;

  /// No description provided for @categoryMoveDown.
  ///
  /// In fr, this message translates to:
  /// **'Descendre'**
  String get categoryMoveDown;

  /// No description provided for @categoryMoveTitle.
  ///
  /// In fr, this message translates to:
  /// **'Déplacer « {name} » vers'**
  String categoryMoveTitle(String name);

  /// No description provided for @categoryTopLevel.
  ///
  /// In fr, this message translates to:
  /// **'Premier niveau, {nature}'**
  String categoryTopLevel(String nature);

  /// No description provided for @categoryDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la catégorie « {name} » ?'**
  String categoryDeleteConfirm(String name);

  /// No description provided for @categoryDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie supprimée.'**
  String get categoryDeleted;

  /// No description provided for @natureIncome.
  ///
  /// In fr, this message translates to:
  /// **'revenus'**
  String get natureIncome;

  /// No description provided for @natureExpense.
  ///
  /// In fr, this message translates to:
  /// **'dépenses'**
  String get natureExpense;

  /// No description provided for @errorUnknownCategory.
  ///
  /// In fr, this message translates to:
  /// **'Cette catégorie n\'existe plus.'**
  String get errorUnknownCategory;

  /// No description provided for @errorCategoryNameTaken.
  ///
  /// In fr, this message translates to:
  /// **'Ce nom est déjà utilisé dans l\'arbre de cette année (majuscules, accents et espaces autour ne comptent pas).'**
  String get errorCategoryNameTaken;

  /// No description provided for @errorNatureRequired.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la nature du groupe : revenus ou dépenses.'**
  String get errorNatureRequired;

  /// No description provided for @errorTreeExists.
  ///
  /// In fr, this message translates to:
  /// **'L\'arbre de cette année existe déjà.'**
  String get errorTreeExists;

  /// No description provided for @errorNoTree.
  ///
  /// In fr, this message translates to:
  /// **'Cette année n\'a pas encore d\'arbre.'**
  String get errorNoTree;

  /// No description provided for @errorCategoryLoop.
  ///
  /// In fr, this message translates to:
  /// **'Une catégorie ne peut pas être placée sous elle-même ni sous une de ses sous-catégories.'**
  String get errorCategoryLoop;

  /// No description provided for @errorParentHasTransactions.
  ///
  /// In fr, this message translates to:
  /// **'Impossible : {count, plural, =1{une transaction est classée} other{{count} transactions sont classées}} dans cette catégorie. Seule une catégorie sans transaction peut recevoir des sous-catégories.'**
  String errorParentHasTransactions(int count);

  /// No description provided for @errorCategoryHasChildren.
  ///
  /// In fr, this message translates to:
  /// **'Supprimez ou déplacez d\'abord ses sous-catégories.'**
  String get errorCategoryHasChildren;

  /// No description provided for @errorCategoryInUse.
  ///
  /// In fr, this message translates to:
  /// **'Suppression refusée : {count, plural, =1{une transaction utilise} other{{count} transactions utilisent}} cette catégorie.'**
  String errorCategoryInUse(int count);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

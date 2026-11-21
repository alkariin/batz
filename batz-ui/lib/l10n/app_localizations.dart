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

  /// No description provided for @categoriesToReplace.
  ///
  /// In fr, this message translates to:
  /// **'À replacer'**
  String get categoriesToReplace;

  /// No description provided for @categoriesToReplaceHint.
  ///
  /// In fr, this message translates to:
  /// **'Ces catégories ne sont plus rattachées à l\'arbre, souvent après des modifications faites en même temps sur deux appareils. Déplacez-les pour les replacer ; leurs sous-catégories suivent.'**
  String get categoriesToReplaceHint;

  /// No description provided for @detachedLoop.
  ///
  /// In fr, this message translates to:
  /// **'Placée sous une de ses propres sous-catégories'**
  String get detachedLoop;

  /// No description provided for @detachedMissingParent.
  ///
  /// In fr, this message translates to:
  /// **'Sa catégorie parente a été supprimée'**
  String get detachedMissingParent;

  /// No description provided for @detachedParentInOtherYear.
  ///
  /// In fr, this message translates to:
  /// **'Sa catégorie parente appartient à une autre année'**
  String get detachedParentInOtherYear;

  /// No description provided for @detachedGroupWithoutNature.
  ///
  /// In fr, this message translates to:
  /// **'Groupe sans nature (revenus ou dépenses)'**
  String get detachedGroupWithoutNature;

  /// No description provided for @detachedAncestor.
  ///
  /// In fr, this message translates to:
  /// **'Sous une catégorie à replacer'**
  String get detachedAncestor;

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

  /// No description provided for @errorUnknownTransaction.
  ///
  /// In fr, this message translates to:
  /// **'Cette transaction n\'existe plus.'**
  String get errorUnknownTransaction;

  /// No description provided for @errorAmountRequired.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant supérieur à zéro.'**
  String get errorAmountRequired;

  /// No description provided for @errorArchivedAccount.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte est archivé.'**
  String get errorArchivedAccount;

  /// No description provided for @errorDetailedAccountManual.
  ///
  /// In fr, this message translates to:
  /// **'Le compte détaillé ne reçoit que les transactions de ses relevés : pas de saisie manuelle.'**
  String get errorDetailedAccountManual;

  /// No description provided for @errorDebtsAccountManual.
  ///
  /// In fr, this message translates to:
  /// **'Un compte de dettes ne se modifie que par le tableau des dettes.'**
  String get errorDebtsAccountManual;

  /// No description provided for @errorCategoryNotAssignable.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une catégorie sans sous-catégorie, dans l\'arbre de l\'année du paiement.'**
  String get errorCategoryNotAssignable;

  /// No description provided for @errorPeriodInvalid.
  ///
  /// In fr, this message translates to:
  /// **'La fin de la période précède son début.'**
  String get errorPeriodInvalid;

  /// No description provided for @errorSameAccount.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez deux comptes différents.'**
  String get errorSameAccount;

  /// No description provided for @errorAccountNotDetailed.
  ///
  /// In fr, this message translates to:
  /// **'Ce compte n\'est pas détaillé : activez l\'import du compte pour y importer ses relevés.'**
  String get errorAccountNotDetailed;

  /// No description provided for @errorStatementOtherFormat.
  ///
  /// In fr, this message translates to:
  /// **'Ce relevé n\'est pas au format d\'import de ce compte.'**
  String get errorStatementOtherFormat;

  /// No description provided for @errorStatementAlreadyImported.
  ///
  /// In fr, this message translates to:
  /// **'Ce relevé est déjà importé.'**
  String get errorStatementAlreadyImported;

  /// No description provided for @errorStatementOtherAccount.
  ///
  /// In fr, this message translates to:
  /// **'Ce relevé est celui d\'un autre compte : IBAN {found}, alors que les relevés précédents portent l\'IBAN {expected}.'**
  String errorStatementOtherAccount(String found, String expected);

  /// No description provided for @errorStatementNotContiguous.
  ///
  /// In fr, this message translates to:
  /// **'Ce relevé ne suit pas le précédent : il commence le {foundStart} avec un solde de {foundOpening}, alors que le suivant doit commencer le {expectedStart} avec un solde de {expectedOpening}.'**
  String errorStatementNotContiguous(
    String foundStart,
    String foundOpening,
    String expectedStart,
    String expectedOpening,
  );

  /// No description provided for @errorStatementSumMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Les lignes du relevé ne donnent pas l\'écart entre ses soldes initial et final.'**
  String get errorStatementSumMismatch;

  /// No description provided for @errorStatementTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Ce relevé compte trop de lignes pour être importé en une fois.'**
  String get errorStatementTooLarge;

  /// No description provided for @errorStatementNotLast.
  ///
  /// In fr, this message translates to:
  /// **'Seul le dernier relevé du compte peut être supprimé.'**
  String get errorStatementNotLast;

  /// No description provided for @errorUnknownStatement.
  ///
  /// In fr, this message translates to:
  /// **'Ce relevé n\'existe plus.'**
  String get errorUnknownStatement;

  /// No description provided for @errorImportedTransaction.
  ///
  /// In fr, this message translates to:
  /// **'Une ligne importée garde le montant, la date, le compte et le texte de la banque ; seules sa catégorie, sa période, sa description et sa note se modifient.'**
  String get errorImportedTransaction;

  /// No description provided for @errorUnknownRule.
  ///
  /// In fr, this message translates to:
  /// **'Cette règle n\'existe plus.'**
  String get errorUnknownRule;

  /// No description provided for @errorRuleKeywordsRequired.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez au moins un mot-clé.'**
  String get errorRuleKeywordsRequired;

  /// No description provided for @errorRuleKeywordInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Expression régulière invalide : corrigez le mot-clé qui commence par « re: ».'**
  String get errorRuleKeywordInvalid;

  /// No description provided for @errorRuleTargetRequired.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une catégorie ou un compte de transfert.'**
  String get errorRuleTargetRequired;

  /// No description provided for @errorRulePeriodInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez un nombre de mois entre 1 et 120.'**
  String get errorRulePeriodInvalid;

  /// No description provided for @errorCategoryUsedByRules.
  ///
  /// In fr, this message translates to:
  /// **'Suppression refusée : {count, plural, =1{une règle vise} other{{count} règles visent}} cette catégorie.'**
  String errorCategoryUsedByRules(int count);

  /// No description provided for @errorUnknownRedistribution.
  ///
  /// In fr, this message translates to:
  /// **'Cette règle de redistribution n\'existe plus.'**
  String get errorUnknownRedistribution;

  /// No description provided for @errorRedistributionSameCategory.
  ///
  /// In fr, this message translates to:
  /// **'La source et la cible doivent être deux catégories différentes.'**
  String get errorRedistributionSameCategory;

  /// No description provided for @errorRedistributionNotLeaf.
  ///
  /// In fr, this message translates to:
  /// **'La source et la cible doivent être des catégories sans sous-catégorie de l\'année.'**
  String get errorRedistributionNotLeaf;

  /// No description provided for @errorRedistributionNatureMismatch.
  ///
  /// In fr, this message translates to:
  /// **'La source et la cible doivent être deux dépenses ou deux revenus.'**
  String get errorRedistributionNatureMismatch;

  /// No description provided for @errorRedistributionPercentInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez un pourcentage entre 0.01 et 100, avec deux décimales au plus.'**
  String get errorRedistributionPercentInvalid;

  /// No description provided for @errorRedistributionDuplicate.
  ///
  /// In fr, this message translates to:
  /// **'Une règle va déjà de cette source vers cette cible : modifiez-la.'**
  String get errorRedistributionDuplicate;

  /// No description provided for @errorRedistributionTargetIsSource.
  ///
  /// In fr, this message translates to:
  /// **'Cette cible est déjà la source d\'une autre règle : une cible ne peut pas être une source.'**
  String get errorRedistributionTargetIsSource;

  /// No description provided for @errorRedistributionSourceIsTarget.
  ///
  /// In fr, this message translates to:
  /// **'Cette source est déjà la cible d\'une autre règle : une cible ne peut pas être une source.'**
  String get errorRedistributionSourceIsTarget;

  /// No description provided for @errorRedistributionOverHundred.
  ///
  /// In fr, this message translates to:
  /// **'Les règles de cette source totaliseraient {total} : 100 % au plus.'**
  String errorRedistributionOverHundred(String total);

  /// No description provided for @errorCategoryUsedByRedistributions.
  ///
  /// In fr, this message translates to:
  /// **'Suppression refusée : {count, plural, =1{une règle de redistribution utilise} other{{count} règles de redistribution utilisent}} cette catégorie.'**
  String errorCategoryUsedByRedistributions(int count);

  /// No description provided for @errorRefundNotInflow.
  ///
  /// In fr, this message translates to:
  /// **'Seule une entrée d\'argent peut rembourser une dépense.'**
  String get errorRefundNotInflow;

  /// No description provided for @errorRefundIsTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Un transfert ne peut pas rembourser une dépense.'**
  String get errorRefundIsTransfer;

  /// No description provided for @errorRefundTargetNotExpense.
  ///
  /// In fr, this message translates to:
  /// **'Un remboursement se rattache à une dépense validée.'**
  String get errorRefundTargetNotExpense;

  /// No description provided for @errorShareNatureMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une catégorie de même nature que celle d\'origine : une dépense reste une dépense.'**
  String get errorShareNatureMismatch;

  /// No description provided for @edit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get edit;

  /// No description provided for @transactionsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction.'**
  String get transactionsEmpty;

  /// No description provided for @transactionsAllAccounts.
  ///
  /// In fr, this message translates to:
  /// **'Tous les comptes'**
  String get transactionsAllAccounts;

  /// No description provided for @transactionsAllYears.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les années'**
  String get transactionsAllYears;

  /// No description provided for @transactionNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle transaction'**
  String get transactionNew;

  /// No description provided for @transactionNewEntry.
  ///
  /// In fr, this message translates to:
  /// **'Dépense ou revenu'**
  String get transactionNewEntry;

  /// No description provided for @transactionNewTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Transfert'**
  String get transactionNewTransfer;

  /// No description provided for @entryNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Dépense ou revenu'**
  String get entryNewTitle;

  /// No description provided for @entryEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la transaction'**
  String get entryEditTitle;

  /// No description provided for @transferNewTitle.
  ///
  /// In fr, this message translates to:
  /// **'Nouveau transfert'**
  String get transferNewTitle;

  /// No description provided for @transferEditTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le transfert'**
  String get transferEditTitle;

  /// No description provided for @fieldAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get fieldAmount;

  /// No description provided for @fieldDate.
  ///
  /// In fr, this message translates to:
  /// **'Date (jj.mm.aaaa)'**
  String get fieldDate;

  /// No description provided for @fieldAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get fieldAccount;

  /// No description provided for @fieldCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get fieldCategory;

  /// No description provided for @fieldDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get fieldDescription;

  /// No description provided for @fieldNote.
  ///
  /// In fr, this message translates to:
  /// **'Note'**
  String get fieldNote;

  /// No description provided for @fieldRawText.
  ///
  /// In fr, this message translates to:
  /// **'Texte de la banque'**
  String get fieldRawText;

  /// No description provided for @fieldFrom.
  ///
  /// In fr, this message translates to:
  /// **'Compte de départ'**
  String get fieldFrom;

  /// No description provided for @fieldTo.
  ///
  /// In fr, this message translates to:
  /// **'Compte d\'arrivée'**
  String get fieldTo;

  /// No description provided for @pickDate.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la date'**
  String get pickDate;

  /// No description provided for @directionInflow.
  ///
  /// In fr, this message translates to:
  /// **'Entrée'**
  String get directionInflow;

  /// No description provided for @directionOutflow.
  ///
  /// In fr, this message translates to:
  /// **'Sortie'**
  String get directionOutflow;

  /// No description provided for @periodCustom.
  ///
  /// In fr, this message translates to:
  /// **'Période différente du paiement'**
  String get periodCustom;

  /// No description provided for @periodCustomHint.
  ///
  /// In fr, this message translates to:
  /// **'Par exemple une assurance payée pour douze mois.'**
  String get periodCustomHint;

  /// No description provided for @periodStart.
  ///
  /// In fr, this message translates to:
  /// **'Début de la période'**
  String get periodStart;

  /// No description provided for @periodEnd.
  ///
  /// In fr, this message translates to:
  /// **'Fin de la période'**
  String get periodEnd;

  /// No description provided for @errorAmountInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Montant invalide : saisissez par exemple 45.90, sans signe.'**
  String get errorAmountInvalid;

  /// No description provided for @errorDateInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Date invalide : saisissez par exemple 31.12.2026.'**
  String get errorDateInvalid;

  /// No description provided for @errorAccountMissing.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un compte.'**
  String get errorAccountMissing;

  /// No description provided for @errorCategoryMissing.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une catégorie.'**
  String get errorCategoryMissing;

  /// No description provided for @entryNoAccount.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte n\'accepte la saisie manuelle. Créez-en un dans Plus › Comptes.'**
  String get entryNoAccount;

  /// No description provided for @entryNoCategory.
  ///
  /// In fr, this message translates to:
  /// **'Aucune catégorie disponible en {year}. Ajoutez-en dans Plus › Catégories.'**
  String entryNoCategory(int year);

  /// No description provided for @kindExpense.
  ///
  /// In fr, this message translates to:
  /// **'Dépense'**
  String get kindExpense;

  /// No description provided for @kindRefund.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement'**
  String get kindRefund;

  /// No description provided for @kindIncome.
  ///
  /// In fr, this message translates to:
  /// **'Revenu'**
  String get kindIncome;

  /// No description provided for @kindTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Transfert'**
  String get kindTransfer;

  /// No description provided for @kindUnclassified.
  ///
  /// In fr, this message translates to:
  /// **'Non classé'**
  String get kindUnclassified;

  /// No description provided for @transferAccounts.
  ///
  /// In fr, this message translates to:
  /// **'{from} → {to}'**
  String transferAccounts(String from, String to);

  /// No description provided for @detailTitle.
  ///
  /// In fr, this message translates to:
  /// **'Transaction'**
  String get detailTitle;

  /// No description provided for @detailType.
  ///
  /// In fr, this message translates to:
  /// **'Type'**
  String get detailType;

  /// No description provided for @detailPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Période'**
  String get detailPeriod;

  /// No description provided for @detailShares.
  ///
  /// In fr, this message translates to:
  /// **'Parts par mois'**
  String get detailShares;

  /// No description provided for @detailYearTotals.
  ///
  /// In fr, this message translates to:
  /// **'Total par année'**
  String get detailYearTotals;

  /// No description provided for @transactionDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette transaction ?'**
  String get transactionDeleteConfirm;

  /// No description provided for @transactionDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Transaction supprimée.'**
  String get transactionDeleted;

  /// No description provided for @syncTitle.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation'**
  String get syncTitle;

  /// No description provided for @syncNotPaired.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil n\'est associé à aucun serveur : ses données restent sur lui seul.'**
  String get syncNotPaired;

  /// No description provided for @syncPairAction.
  ///
  /// In fr, this message translates to:
  /// **'Associer un serveur'**
  String get syncPairAction;

  /// No description provided for @syncNever.
  ///
  /// In fr, this message translates to:
  /// **'Jamais synchronisé'**
  String get syncNever;

  /// No description provided for @syncRunning.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation en cours…'**
  String get syncRunning;

  /// No description provided for @syncUpToDate.
  ///
  /// In fr, this message translates to:
  /// **'À jour'**
  String get syncUpToDate;

  /// No description provided for @syncOffline.
  ///
  /// In fr, this message translates to:
  /// **'Hors ligne'**
  String get syncOffline;

  /// No description provided for @syncOfflineHint.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur est injoignable. Les modifications partiront à la prochaine synchronisation.'**
  String get syncOfflineHint;

  /// No description provided for @syncRevoked.
  ///
  /// In fr, this message translates to:
  /// **'Appareil révoqué'**
  String get syncRevoked;

  /// No description provided for @syncRevokedHint.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur a révoqué cet appareil : la synchronisation est arrêtée. Ses données restent sur cet appareil. Pour reprendre, oubliez ce serveur dans Plus › Serveur, puis associez l\'appareil à nouveau : ses modifications non envoyées partiront au premier échange.'**
  String get syncRevokedHint;

  /// No description provided for @syncIncompatible.
  ///
  /// In fr, this message translates to:
  /// **'Versions incompatibles'**
  String get syncIncompatible;

  /// No description provided for @syncAppTooOld.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation refusée : cette version de l\'app est trop ancienne pour le serveur, qui demande au moins la version {version}. Mettez l\'app à jour.'**
  String syncAppTooOld(String version);

  /// No description provided for @syncServerTooOld.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation refusée : le serveur (version {version}) est trop ancien pour cette version de l\'app. Mettez le serveur à jour.'**
  String syncServerTooOld(String version);

  /// No description provided for @syncError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur de synchronisation'**
  String get syncError;

  /// No description provided for @syncErrorHint.
  ///
  /// In fr, this message translates to:
  /// **'La dernière synchronisation a échoué : {detail}'**
  String syncErrorHint(String detail);

  /// No description provided for @syncLast.
  ///
  /// In fr, this message translates to:
  /// **'Dernière synchronisation : {date} à {time}'**
  String syncLast(String date, String time);

  /// No description provided for @syncPending.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucune modification en attente} =1{Une modification en attente} other{{count} modifications en attente}}'**
  String syncPending(int count);

  /// No description provided for @syncNow.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser'**
  String get syncNow;

  /// No description provided for @syncClockWarning.
  ///
  /// In fr, this message translates to:
  /// **'L\'horloge de cet appareil s\'écarte de {minutes} minutes de celle du serveur. Corrigez-la : l\'ordre des modifications faites sur plusieurs appareils en dépend.'**
  String syncClockWarning(int minutes);

  /// No description provided for @syncDecision.
  ///
  /// In fr, this message translates to:
  /// **'Premier échange avec le serveur'**
  String get syncDecision;

  /// No description provided for @syncDecisionHint.
  ///
  /// In fr, this message translates to:
  /// **'Cet appareil et le serveur ont chacun des données, sans rien en commun : elles viennent d\'appareils utilisés séparément. Fusionner réunit les deux ; des doublons peuvent apparaître, ils seront signalés dans les tâches. Remplacer efface les données de cet appareil et reprend celles du serveur.'**
  String get syncDecisionHint;

  /// No description provided for @syncMerge.
  ///
  /// In fr, this message translates to:
  /// **'Fusionner'**
  String get syncMerge;

  /// No description provided for @syncReplace.
  ///
  /// In fr, this message translates to:
  /// **'Remplacer celles de l\'appareil'**
  String get syncReplace;

  /// No description provided for @syncReplaceAction.
  ///
  /// In fr, this message translates to:
  /// **'Remplacer les données de cet appareil par celles du serveur'**
  String get syncReplaceAction;

  /// No description provided for @syncReplaceConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Remplacer les données de cet appareil par celles du serveur ? Tout ce que cet appareil n\'a pas encore envoyé au serveur sera définitivement perdu.'**
  String get syncReplaceConfirm;

  /// No description provided for @syncReplaceDone.
  ///
  /// In fr, this message translates to:
  /// **'Les données de cet appareil sont maintenant celles du serveur.'**
  String get syncReplaceDone;

  /// No description provided for @syncServerChanged.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur a changé'**
  String get syncServerChanged;

  /// No description provided for @syncServerChangedHint.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur présente un autre certificat ou ne connaît plus cet appareil : il a sans doute été réinstallé. Associez cet appareil de nouveau : ses données, modifications non envoyées comprises, y seront recopiées.'**
  String get syncServerChangedHint;

  /// No description provided for @syncPairAgain.
  ///
  /// In fr, this message translates to:
  /// **'Associer de nouveau'**
  String get syncPairAgain;

  /// No description provided for @serverErrorUnknownDevice.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur ne connaît pas cet appareil : il a sans doute été réinstallé. Oubliez ce serveur puis associez l\'appareil à nouveau.'**
  String get serverErrorUnknownDevice;

  /// No description provided for @tasksTitle.
  ///
  /// In fr, this message translates to:
  /// **'À faire'**
  String get tasksTitle;

  /// No description provided for @tasksNone.
  ///
  /// In fr, this message translates to:
  /// **'Rien à faire pour l\'instant.'**
  String get tasksNone;

  /// No description provided for @taskDuplicateName.
  ///
  /// In fr, this message translates to:
  /// **'{count} catégories « {name} » en {year}'**
  String taskDuplicateName(int count, String name, int year);

  /// No description provided for @taskDuplicateNameHint.
  ///
  /// In fr, this message translates to:
  /// **'Un nom n\'apparaît qu\'une fois dans l\'arbre d\'une année : renommez ou supprimez l\'une d\'elles.'**
  String get taskDuplicateNameHint;

  /// No description provided for @taskDetailedAccounts.
  ///
  /// In fr, this message translates to:
  /// **'{count} comptes détaillés'**
  String taskDetailedAccounts(int count);

  /// No description provided for @taskDetailedAccountsHint.
  ///
  /// In fr, this message translates to:
  /// **'Un seul compte reçoit les relevés : désactivez l\'import sur les autres.'**
  String get taskDetailedAccountsHint;

  /// No description provided for @taskDetached.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Une catégorie à replacer} other{{count} catégories à replacer}} en {year}'**
  String taskDetached(int count, int year);

  /// No description provided for @taskDetachedHint.
  ///
  /// In fr, this message translates to:
  /// **'Elles ne sont plus rattachées à l\'arbre de l\'année : déplacez-les.'**
  String get taskDetachedHint;

  /// No description provided for @categoryDuplicateName.
  ///
  /// In fr, this message translates to:
  /// **'Nom en double dans cette année'**
  String get categoryDuplicateName;

  /// No description provided for @importTitle.
  ///
  /// In fr, this message translates to:
  /// **'Importer un relevé'**
  String get importTitle;

  /// No description provided for @importSyncing.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisation avant l\'import…'**
  String get importSyncing;

  /// No description provided for @importNotReady.
  ///
  /// In fr, this message translates to:
  /// **'L\'import commence par une synchronisation aboutie. Elle n\'a pas abouti : {reason}'**
  String importNotReady(String reason);

  /// No description provided for @importRetry.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get importRetry;

  /// No description provided for @importNoDetailedAccount.
  ///
  /// In fr, this message translates to:
  /// **'Aucun compte détaillé : activez l\'import d\'un compte dans Plus › Comptes.'**
  String get importNoDetailedAccount;

  /// No description provided for @importAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get importAccount;

  /// No description provided for @importChoose.
  ///
  /// In fr, this message translates to:
  /// **'Choisir le relevé PDF'**
  String get importChoose;

  /// No description provided for @importSending.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur lit et vérifie le relevé…'**
  String get importSending;

  /// No description provided for @importRefusedTitle.
  ///
  /// In fr, this message translates to:
  /// **'Relevé refusé'**
  String get importRefusedTitle;

  /// No description provided for @importDoneTitle.
  ///
  /// In fr, this message translates to:
  /// **'Relevé importé'**
  String get importDoneTitle;

  /// No description provided for @importDonePeriod.
  ///
  /// In fr, this message translates to:
  /// **'Du {start} au {end}'**
  String importDonePeriod(String start, String end);

  /// No description provided for @importDoneLines.
  ///
  /// In fr, this message translates to:
  /// **'{lines, plural, =1{Une ligne} other{{lines} lignes}} : {proposed} {proposed, plural, =0{proposée} =1{proposée} other{proposées}}, {toComplete} à compléter.'**
  String importDoneLines(int lines, int proposed, int toComplete);

  /// No description provided for @importStatements.
  ///
  /// In fr, this message translates to:
  /// **'Relevés du compte'**
  String get importStatements;

  /// No description provided for @importFirstTitle.
  ///
  /// In fr, this message translates to:
  /// **'Premier relevé de ce compte'**
  String get importFirstTitle;

  /// No description provided for @importFirstBody.
  ///
  /// In fr, this message translates to:
  /// **'Ce relevé fixe le solde de départ du compte : {balance} au {date}. Aucun relevé antérieur ne pourra être importé ensuite.'**
  String importFirstBody(String balance, String date);

  /// No description provided for @importFirstConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Importer'**
  String get importFirstConfirm;

  /// No description provided for @importUnreadable.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier n\'est pas un PDF lisible.'**
  String get importUnreadable;

  /// No description provided for @importUnknownFormat.
  ///
  /// In fr, this message translates to:
  /// **'Ce PDF n\'est pas un relevé PostFinance.'**
  String get importUnknownFormat;

  /// No description provided for @importInconsistent.
  ///
  /// In fr, this message translates to:
  /// **'Relevé incohérent, rien n\'est importé : {reason}.'**
  String importInconsistent(String reason);

  /// No description provided for @importCheckLayout.
  ///
  /// In fr, this message translates to:
  /// **'il n\'a pas pu être lu en entier'**
  String get importCheckLayout;

  /// No description provided for @importCheckCurrency.
  ///
  /// In fr, this message translates to:
  /// **'le compte n\'est pas en francs suisses'**
  String get importCheckCurrency;

  /// No description provided for @importCheckPeriod.
  ///
  /// In fr, this message translates to:
  /// **'une ligne est hors de la période du relevé, ou dans le désordre'**
  String get importCheckPeriod;

  /// No description provided for @importCheckRunningBalance.
  ///
  /// In fr, this message translates to:
  /// **'un solde imprimé en cours de relevé ne correspond pas aux mouvements qui le précèdent'**
  String get importCheckRunningBalance;

  /// No description provided for @importCheckTotals.
  ///
  /// In fr, this message translates to:
  /// **'les totaux imprimés des crédits ou des débits ne correspondent pas aux mouvements'**
  String get importCheckTotals;

  /// No description provided for @importCheckClosingBalance.
  ///
  /// In fr, this message translates to:
  /// **'le solde final ne correspond pas au solde initial plus les mouvements'**
  String get importCheckClosingBalance;

  /// No description provided for @importTooLarge.
  ///
  /// In fr, this message translates to:
  /// **'Ce fichier dépasse 10 Mo.'**
  String get importTooLarge;

  /// No description provided for @importServerRefused.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur refuse l\'envoi ({code}).'**
  String importServerRefused(String code);

  /// No description provided for @importServerTooOld.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur (version {version}) est trop ancien pour importer des relevés : installez la version 0.4.0 ou une suivante.'**
  String importServerTooOld(String version);

  /// No description provided for @importUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur ne répond plus : le relevé n\'a pas été envoyé.'**
  String get importUnreachable;

  /// No description provided for @statementsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Relevés de {account}'**
  String statementsTitle(String account);

  /// No description provided for @statementsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun relevé importé.'**
  String get statementsEmpty;

  /// No description provided for @statementPeriod.
  ///
  /// In fr, this message translates to:
  /// **'{start} – {end}'**
  String statementPeriod(String start, String end);

  /// No description provided for @statementSummary.
  ///
  /// In fr, this message translates to:
  /// **'Solde initial {opening} · final {closing} · {lines, plural, =1{une ligne} other{{lines} lignes}}'**
  String statementSummary(String opening, String closing, int lines);

  /// No description provided for @statementSavePdf.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer le PDF d\'origine'**
  String get statementSavePdf;

  /// No description provided for @statementPdfSaved.
  ///
  /// In fr, this message translates to:
  /// **'PDF enregistré.'**
  String get statementPdfSaved;

  /// No description provided for @statementPdfMissing.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur n\'a plus ce PDF : il a sans doute été reconstruit depuis l\'import.'**
  String get statementPdfMissing;

  /// No description provided for @statementPdfNotPaired.
  ///
  /// In fr, this message translates to:
  /// **'Associez un serveur pour récupérer le PDF d\'origine.'**
  String get statementPdfNotPaired;

  /// No description provided for @statementPdfUnreachable.
  ///
  /// In fr, this message translates to:
  /// **'Le serveur ne répond pas : le PDF n\'a pas pu être récupéré.'**
  String get statementPdfUnreachable;

  /// No description provided for @statementDeleteLast.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le dernier relevé'**
  String get statementDeleteLast;

  /// No description provided for @statementDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le relevé du {start} au {end} et ses {lines} lignes ? Leurs classements sont perdus ; le relevé pourra être importé de nouveau.'**
  String statementDeleteConfirm(String start, String end, int lines);

  /// No description provided for @statementDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Relevé supprimé.'**
  String get statementDeleted;

  /// No description provided for @accountStatements.
  ///
  /// In fr, this message translates to:
  /// **'Relevés importés'**
  String get accountStatements;

  /// No description provided for @validationTitle.
  ///
  /// In fr, this message translates to:
  /// **'Validation'**
  String get validationTitle;

  /// No description provided for @validationToCompleteTab.
  ///
  /// In fr, this message translates to:
  /// **'À compléter ({count})'**
  String validationToCompleteTab(int count);

  /// No description provided for @validationProposedTab.
  ///
  /// In fr, this message translates to:
  /// **'Proposées ({count})'**
  String validationProposedTab(int count);

  /// No description provided for @validationNothingToComplete.
  ///
  /// In fr, this message translates to:
  /// **'Aucune ligne à compléter.'**
  String get validationNothingToComplete;

  /// No description provided for @validationNothingProposed.
  ///
  /// In fr, this message translates to:
  /// **'Aucune proposition à confirmer.'**
  String get validationNothingProposed;

  /// No description provided for @validationConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Confirmer les propositions ({count})'**
  String validationConfirm(int count);

  /// No description provided for @validationConfirmed.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Une ligne validée} other{{count} lignes validées}}.'**
  String validationConfirmed(int count);

  /// No description provided for @validationConflict.
  ///
  /// In fr, this message translates to:
  /// **'Règles en concurrence : {rules}'**
  String validationConflict(String rules);

  /// No description provided for @validationUnusable.
  ///
  /// In fr, this message translates to:
  /// **'La règle « {keywords} » vise une cible inutilisable.'**
  String validationUnusable(String keywords);

  /// No description provided for @validationRule.
  ///
  /// In fr, this message translates to:
  /// **'Règle « {keywords} »'**
  String validationRule(String keywords);

  /// No description provided for @validationTransferWith.
  ///
  /// In fr, this message translates to:
  /// **'Transfert avec {account}'**
  String validationTransferWith(String account);

  /// No description provided for @validationAction.
  ///
  /// In fr, this message translates to:
  /// **'Valider les lignes'**
  String get validationAction;

  /// No description provided for @classifyTitle.
  ///
  /// In fr, this message translates to:
  /// **'Classer la ligne'**
  String get classifyTitle;

  /// No description provided for @classifyCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie'**
  String get classifyCategory;

  /// No description provided for @classifyTransfer.
  ///
  /// In fr, this message translates to:
  /// **'Transfert'**
  String get classifyTransfer;

  /// No description provided for @classifyCounterpart.
  ///
  /// In fr, this message translates to:
  /// **'Compte de contrepartie'**
  String get classifyCounterpart;

  /// No description provided for @classifyTransferOut.
  ///
  /// In fr, this message translates to:
  /// **'L\'argent part vers ce compte.'**
  String get classifyTransferOut;

  /// No description provided for @classifyTransferIn.
  ///
  /// In fr, this message translates to:
  /// **'L\'argent vient de ce compte.'**
  String get classifyTransferIn;

  /// No description provided for @classifyValidate.
  ///
  /// In fr, this message translates to:
  /// **'Valider'**
  String get classifyValidate;

  /// No description provided for @classifyValidated.
  ///
  /// In fr, this message translates to:
  /// **'Ligne validée.'**
  String get classifyValidated;

  /// No description provided for @classifyCreateRule.
  ///
  /// In fr, this message translates to:
  /// **'Créer une règle'**
  String get classifyCreateRule;

  /// No description provided for @classifyChooseCategory.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une catégorie.'**
  String get classifyChooseCategory;

  /// No description provided for @classifyChooseAccount.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez un compte.'**
  String get classifyChooseAccount;

  /// No description provided for @rulesMenu.
  ///
  /// In fr, this message translates to:
  /// **'Règles de classement'**
  String get rulesMenu;

  /// No description provided for @rulesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Règles {year}'**
  String rulesTitle(int year);

  /// No description provided for @rulesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune règle pour cette année.'**
  String get rulesEmpty;

  /// No description provided for @rulesNoTree.
  ///
  /// In fr, this message translates to:
  /// **'Cette année n\'a pas encore d\'arbre de catégories.'**
  String get rulesNoTree;

  /// No description provided for @ruleNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle règle'**
  String get ruleNew;

  /// No description provided for @ruleEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la règle'**
  String get ruleEdit;

  /// No description provided for @ruleKeywords.
  ///
  /// In fr, this message translates to:
  /// **'Mots-clés, un par ligne'**
  String get ruleKeywords;

  /// No description provided for @ruleKeywordsHint.
  ///
  /// In fr, this message translates to:
  /// **'Tous sont requis, sans tenir compte des majuscules, des accents ni des espaces. « re: » au début d\'un mot-clé pour une expression régulière.'**
  String get ruleKeywordsHint;

  /// No description provided for @ruleKeywordInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Expression régulière invalide : {keyword}'**
  String ruleKeywordInvalid(String keyword);

  /// No description provided for @ruleTarget.
  ///
  /// In fr, this message translates to:
  /// **'Cible'**
  String get ruleTarget;

  /// No description provided for @rulePeriod.
  ///
  /// In fr, this message translates to:
  /// **'Période'**
  String get rulePeriod;

  /// No description provided for @rulePeriodNone.
  ///
  /// In fr, this message translates to:
  /// **'Date du paiement'**
  String get rulePeriodNone;

  /// No description provided for @rulePeriodPreviousMonth.
  ///
  /// In fr, this message translates to:
  /// **'Mois précédent'**
  String get rulePeriodPreviousMonth;

  /// No description provided for @rulePeriodNextMonth.
  ///
  /// In fr, this message translates to:
  /// **'Mois suivant'**
  String get rulePeriodNextMonth;

  /// No description provided for @rulePeriodMonthsAfter.
  ///
  /// In fr, this message translates to:
  /// **'N mois après le paiement'**
  String get rulePeriodMonthsAfter;

  /// No description provided for @rulePeriodMonthsBefore.
  ///
  /// In fr, this message translates to:
  /// **'N mois avant le paiement'**
  String get rulePeriodMonthsBefore;

  /// No description provided for @rulePeriodCurrentYear.
  ///
  /// In fr, this message translates to:
  /// **'Année civile en cours'**
  String get rulePeriodCurrentYear;

  /// No description provided for @rulePeriodPreviousYear.
  ///
  /// In fr, this message translates to:
  /// **'Année civile précédente'**
  String get rulePeriodPreviousYear;

  /// No description provided for @ruleMonths.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de mois'**
  String get ruleMonths;

  /// No description provided for @ruleMatches.
  ///
  /// In fr, this message translates to:
  /// **'Cette règle classerait {count, plural, =0{aucune ligne non validée} =1{une ligne non validée} other{{count} lignes non validées}}.'**
  String ruleMatches(int count);

  /// No description provided for @ruleSaved.
  ///
  /// In fr, this message translates to:
  /// **'Règle enregistrée.'**
  String get ruleSaved;

  /// No description provided for @ruleDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Règle supprimée.'**
  String get ruleDeleted;

  /// No description provided for @ruleDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette règle ? Les lignes déjà validées ne changent pas.'**
  String get ruleDeleteConfirm;

  /// No description provided for @ruleUnusable.
  ///
  /// In fr, this message translates to:
  /// **'Cible inutilisable : cette règle ne propose rien.'**
  String get ruleUnusable;

  /// No description provided for @ruleSummary.
  ///
  /// In fr, this message translates to:
  /// **'{keywords} → {target}'**
  String ruleSummary(String keywords, String target);

  /// No description provided for @taskLinesToValidate.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Une ligne à valider} other{{count} lignes à valider}}'**
  String taskLinesToValidate(int count);

  /// No description provided for @taskLinesToValidateHint.
  ///
  /// In fr, this message translates to:
  /// **'Lignes importées : complétez-les ou confirmez les propositions.'**
  String get taskLinesToValidateHint;

  /// No description provided for @taskConflicts.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Une ligne dont les règles sont en concurrence} other{{count} lignes dont les règles sont en concurrence}}'**
  String taskConflicts(int count);

  /// No description provided for @taskConflictsHint.
  ///
  /// In fr, this message translates to:
  /// **'Classez-les à la main ou ajustez les règles.'**
  String get taskConflictsHint;

  /// No description provided for @taskUnusableRules.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Une règle de {year} ne propose plus rien} other{{count} règles de {year} ne proposent plus rien}}'**
  String taskUnusableRules(int count, int year);

  /// No description provided for @taskUnusableRulesHint.
  ///
  /// In fr, this message translates to:
  /// **'Leur catégorie ou leur compte n\'est plus utilisable : modifiez-les.'**
  String get taskUnusableRulesHint;

  /// No description provided for @transactionsSearch.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get transactionsSearch;

  /// No description provided for @transactionsAllMonths.
  ///
  /// In fr, this message translates to:
  /// **'Tous les mois'**
  String get transactionsAllMonths;

  /// No description provided for @transactionsAllCategories.
  ///
  /// In fr, this message translates to:
  /// **'Toutes les catégories'**
  String get transactionsAllCategories;

  /// No description provided for @transactionsUnclassified.
  ///
  /// In fr, this message translates to:
  /// **'Non classé'**
  String get transactionsUnclassified;

  /// No description provided for @transactionsAllStatuses.
  ///
  /// In fr, this message translates to:
  /// **'Tous les statuts'**
  String get transactionsAllStatuses;

  /// No description provided for @statusToValidate.
  ///
  /// In fr, this message translates to:
  /// **'À valider'**
  String get statusToValidate;

  /// No description provided for @statusToComplete.
  ///
  /// In fr, this message translates to:
  /// **'À compléter'**
  String get statusToComplete;

  /// No description provided for @statusProposed.
  ///
  /// In fr, this message translates to:
  /// **'Proposée'**
  String get statusProposed;

  /// No description provided for @statusValidated.
  ///
  /// In fr, this message translates to:
  /// **'Validée'**
  String get statusValidated;

  /// No description provided for @yearViewCash.
  ///
  /// In fr, this message translates to:
  /// **'Trésorerie'**
  String get yearViewCash;

  /// No description provided for @yearViewEconomic.
  ///
  /// In fr, this message translates to:
  /// **'Économique'**
  String get yearViewEconomic;

  /// No description provided for @yearPick.
  ///
  /// In fr, this message translates to:
  /// **'Année affichée'**
  String get yearPick;

  /// No description provided for @yearIncome.
  ///
  /// In fr, this message translates to:
  /// **'Revenus'**
  String get yearIncome;

  /// No description provided for @yearExpenses.
  ///
  /// In fr, this message translates to:
  /// **'Dépenses'**
  String get yearExpenses;

  /// No description provided for @yearSavings.
  ///
  /// In fr, this message translates to:
  /// **'Épargne'**
  String get yearSavings;

  /// No description provided for @yearUnclassified.
  ///
  /// In fr, this message translates to:
  /// **'Non classé'**
  String get yearUnclassified;

  /// No description provided for @yearToClassify.
  ///
  /// In fr, this message translates to:
  /// **'À classer'**
  String get yearToClassify;

  /// No description provided for @yearToClassifyNature.
  ///
  /// In fr, this message translates to:
  /// **'À classer · {nature}'**
  String yearToClassifyNature(String nature);

  /// No description provided for @yearOffsets.
  ///
  /// In fr, this message translates to:
  /// **'Décalages de période'**
  String get yearOffsets;

  /// No description provided for @yearPaidForOtherYears.
  ///
  /// In fr, this message translates to:
  /// **'Payé en {year} pour d\'autres années'**
  String yearPaidForOtherYears(String year);

  /// No description provided for @yearPaidInOtherYears.
  ///
  /// In fr, this message translates to:
  /// **'Payé d\'autres années pour {year}'**
  String yearPaidInOtherYears(String year);

  /// No description provided for @yearToValidate.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Une ligne à valider compte} other{{count} lignes à valider comptent}} comme ses règles le proposent.'**
  String yearToValidate(int count);

  /// No description provided for @yearPreview.
  ///
  /// In fr, this message translates to:
  /// **'{year} n\'a pas encore d\'arbre : il s\'affiche avec celui que sa copie lui donnera.'**
  String yearPreview(String year);

  /// No description provided for @yearNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune année à afficher : la première transaction d\'une année crée son arbre.'**
  String get yearNone;

  /// No description provided for @yearTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get yearTotal;

  /// No description provided for @yearMonths.
  ///
  /// In fr, this message translates to:
  /// **'janv.,févr.,mars,avr.,mai,juin,juil.,août,sept.,oct.,nov.,déc.'**
  String get yearMonths;

  /// No description provided for @yearMonthDetail.
  ///
  /// In fr, this message translates to:
  /// **'Détail par mois'**
  String get yearMonthDetail;

  /// No description provided for @yearCostsHint.
  ///
  /// In fr, this message translates to:
  /// **'Les dépenses s\'affichent comme des coûts ; un remboursement les diminue.'**
  String get yearCostsHint;

  /// No description provided for @yearRedistributionTo.
  ///
  /// In fr, this message translates to:
  /// **'Vers {name} · {percent}'**
  String yearRedistributionTo(String name, String percent);

  /// No description provided for @yearRedistributionFrom.
  ///
  /// In fr, this message translates to:
  /// **'Depuis {name} · {percent}'**
  String yearRedistributionFrom(String name, String percent);

  /// No description provided for @compositionEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune transaction dans ce montant.'**
  String get compositionEmpty;

  /// No description provided for @compositionTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get compositionTotal;

  /// No description provided for @compositionPeriod.
  ///
  /// In fr, this message translates to:
  /// **'{month} {year}'**
  String compositionPeriod(String month, String year);

  /// No description provided for @keyFiguresTitle.
  ///
  /// In fr, this message translates to:
  /// **'Chiffres clés {year}'**
  String keyFiguresTitle(String year);

  /// No description provided for @keyFiguresHint.
  ///
  /// In fr, this message translates to:
  /// **'Vue économique : ce que l\'année coûte.'**
  String get keyFiguresHint;

  /// No description provided for @keyFiguresOpen.
  ///
  /// In fr, this message translates to:
  /// **'Voir l\'année'**
  String get keyFiguresOpen;

  /// No description provided for @redistributionMenu.
  ///
  /// In fr, this message translates to:
  /// **'Redistribution'**
  String get redistributionMenu;

  /// No description provided for @redistributionTitle.
  ///
  /// In fr, this message translates to:
  /// **'Redistribution {year}'**
  String redistributionTitle(String year);

  /// No description provided for @redistributionExplain.
  ///
  /// In fr, this message translates to:
  /// **'Chaque mois, le pourcentage du montant de la source passe dans la cible, sur une ligne distincte de chaque côté, dans les deux vues.'**
  String get redistributionExplain;

  /// No description provided for @redistributionEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune règle de redistribution cette année.'**
  String get redistributionEmpty;

  /// No description provided for @redistributionNoTree.
  ///
  /// In fr, this message translates to:
  /// **'Cette année n\'a pas encore d\'arbre.'**
  String get redistributionNoTree;

  /// No description provided for @redistributionNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle règle'**
  String get redistributionNew;

  /// No description provided for @redistributionEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la règle'**
  String get redistributionEdit;

  /// No description provided for @redistributionSource.
  ///
  /// In fr, this message translates to:
  /// **'Source'**
  String get redistributionSource;

  /// No description provided for @redistributionTarget.
  ///
  /// In fr, this message translates to:
  /// **'Cible'**
  String get redistributionTarget;

  /// No description provided for @redistributionPercent.
  ///
  /// In fr, this message translates to:
  /// **'Pourcentage'**
  String get redistributionPercent;

  /// No description provided for @redistributionPercentHint.
  ///
  /// In fr, this message translates to:
  /// **'De 0.01 à 100, deux décimales au plus.'**
  String get redistributionPercentHint;

  /// No description provided for @redistributionRule.
  ///
  /// In fr, this message translates to:
  /// **'De {source} vers {target}'**
  String redistributionRule(String source, String target);

  /// No description provided for @redistributionSaved.
  ///
  /// In fr, this message translates to:
  /// **'Règle enregistrée.'**
  String get redistributionSaved;

  /// No description provided for @redistributionDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Règle supprimée.'**
  String get redistributionDeleted;

  /// No description provided for @redistributionDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette règle de redistribution ?'**
  String get redistributionDeleteConfirm;

  /// No description provided for @redistributionChooseSource.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la source.'**
  String get redistributionChooseSource;

  /// No description provided for @redistributionChooseTarget.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la cible.'**
  String get redistributionChooseTarget;

  /// No description provided for @redistributionProblemSourceMissing.
  ///
  /// In fr, this message translates to:
  /// **'Ne s\'applique pas : la source n\'est plus dans l\'arbre de l\'année.'**
  String get redistributionProblemSourceMissing;

  /// No description provided for @redistributionProblemTargetMissing.
  ///
  /// In fr, this message translates to:
  /// **'Ne s\'applique pas : la cible n\'est plus dans l\'arbre de l\'année.'**
  String get redistributionProblemTargetMissing;

  /// No description provided for @redistributionProblemSourceNotLeaf.
  ///
  /// In fr, this message translates to:
  /// **'Ne s\'applique pas : la source a des sous-catégories.'**
  String get redistributionProblemSourceNotLeaf;

  /// No description provided for @redistributionProblemTargetNotLeaf.
  ///
  /// In fr, this message translates to:
  /// **'Ne s\'applique pas : la cible a des sous-catégories.'**
  String get redistributionProblemTargetNotLeaf;

  /// No description provided for @redistributionProblemSameCategory.
  ///
  /// In fr, this message translates to:
  /// **'Ne s\'applique pas : la source et la cible sont la même catégorie.'**
  String get redistributionProblemSameCategory;

  /// No description provided for @redistributionProblemNatureMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Ne s\'applique pas : la source et la cible ne sont pas de même nature.'**
  String get redistributionProblemNatureMismatch;

  /// No description provided for @redistributionProblemPercentInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Ne s\'applique pas : le pourcentage n\'est pas entre 0.01 et 100.'**
  String get redistributionProblemPercentInvalid;

  /// No description provided for @redistributionProblemOverHundred.
  ///
  /// In fr, this message translates to:
  /// **'Ne s\'applique pas : les règles de cette source dépassent 100 %.'**
  String get redistributionProblemOverHundred;

  /// No description provided for @redistributionProblemChain.
  ///
  /// In fr, this message translates to:
  /// **'Ne s\'applique pas : une cible est aussi la source d\'une règle.'**
  String get redistributionProblemChain;

  /// No description provided for @taskInapplicableRedistributions.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Une règle de redistribution ne s\'applique pas} other{{count} règles de redistribution ne s\'appliquent pas}} en {year}'**
  String taskInapplicableRedistributions(int count, String year);

  /// No description provided for @taskInapplicableRedistributionsHint.
  ///
  /// In fr, this message translates to:
  /// **'Corrigez-les ou supprimez-les.'**
  String get taskInapplicableRedistributionsHint;

  /// No description provided for @taskShares.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Une part à classer} other{{count} parts à classer}}'**
  String taskShares(int count);

  /// No description provided for @taskSharesHint.
  ///
  /// In fr, this message translates to:
  /// **'Des montants reportés sur une autre année n\'y trouvent pas leur catégorie.'**
  String get taskSharesHint;

  /// No description provided for @taskBrokenRefunds.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Un remboursement a perdu sa dépense} other{{count} remboursements ont perdu leur dépense}}'**
  String taskBrokenRefunds(int count);

  /// No description provided for @taskBrokenRefundsHint.
  ///
  /// In fr, this message translates to:
  /// **'Ils comptent dans leur propre catégorie : détachez-les ou rattachez-les à une autre dépense.'**
  String get taskBrokenRefundsHint;

  /// No description provided for @classifyRefund.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement'**
  String get classifyRefund;

  /// No description provided for @refundExpense.
  ///
  /// In fr, this message translates to:
  /// **'Dépense remboursée'**
  String get refundExpense;

  /// No description provided for @refundPick.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la dépense'**
  String get refundPick;

  /// No description provided for @refundSearch.
  ///
  /// In fr, this message translates to:
  /// **'Texte ou montant de la dépense'**
  String get refundSearch;

  /// No description provided for @refundNoExpense.
  ///
  /// In fr, this message translates to:
  /// **'Aucune dépense validée trouvée.'**
  String get refundNoExpense;

  /// No description provided for @refundExpenseMissing.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez la dépense remboursée.'**
  String get refundExpenseMissing;

  /// No description provided for @refundHint.
  ///
  /// In fr, this message translates to:
  /// **'Le remboursement prend la catégorie et la période de sa dépense, qui affiche son coût net.'**
  String get refundHint;

  /// No description provided for @refundAttached.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement rattaché.'**
  String get refundAttached;

  /// No description provided for @refundDetach.
  ///
  /// In fr, this message translates to:
  /// **'Détacher'**
  String get refundDetach;

  /// No description provided for @refundDetached.
  ///
  /// In fr, this message translates to:
  /// **'Remboursement détaché.'**
  String get refundDetached;

  /// No description provided for @refundAttach.
  ///
  /// In fr, this message translates to:
  /// **'Rattacher à une dépense'**
  String get refundAttach;

  /// No description provided for @detailRefunds.
  ///
  /// In fr, this message translates to:
  /// **'Remboursements'**
  String get detailRefunds;

  /// No description provided for @detailNetCost.
  ///
  /// In fr, this message translates to:
  /// **'Coût net'**
  String get detailNetCost;

  /// No description provided for @detailRefundOf.
  ///
  /// In fr, this message translates to:
  /// **'Rembourse'**
  String get detailRefundOf;

  /// No description provided for @detailBrokenLink.
  ///
  /// In fr, this message translates to:
  /// **'La dépense de ce remboursement n\'existe plus ou n\'est plus une dépense validée : il compte dans sa propre catégorie, à sa date.'**
  String get detailBrokenLink;

  /// No description provided for @entryRefund.
  ///
  /// In fr, this message translates to:
  /// **'Rembourse une dépense'**
  String get entryRefund;

  /// No description provided for @brokenRefundsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Remboursements sans dépense'**
  String get brokenRefundsTitle;

  /// No description provided for @sharesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Parts à classer'**
  String get sharesTitle;

  /// No description provided for @sharesEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune part à classer.'**
  String get sharesEmpty;

  /// No description provided for @sharesGroup.
  ///
  /// In fr, this message translates to:
  /// **'{origin} {originYear}, parts de {year}'**
  String sharesGroup(String origin, String originYear, String year);

  /// No description provided for @sharesExplain.
  ///
  /// In fr, this message translates to:
  /// **'L\'arbre de {year} n\'a pas de catégorie « {name} » qui puisse recevoir ces montants. La réponse est mémorisée pour chaque ligne.'**
  String sharesExplain(String year, String name);

  /// No description provided for @sharesCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie en {year}'**
  String sharesCategory(String year);

  /// No description provided for @sharesClassifyGroup.
  ///
  /// In fr, this message translates to:
  /// **'Classer le groupe'**
  String get sharesClassifyGroup;

  /// No description provided for @sharesClassified.
  ///
  /// In fr, this message translates to:
  /// **'Parts classées.'**
  String get sharesClassified;

  /// No description provided for @sharesChoose.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez une catégorie.'**
  String get sharesChoose;

  /// No description provided for @sharesLineCategory.
  ///
  /// In fr, this message translates to:
  /// **'Pour cette ligne seulement'**
  String get sharesLineCategory;

  /// No description provided for @yearInapplicable.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Une règle de redistribution ne s\'applique pas} other{{count} règles de redistribution ne s\'appliquent pas}} cette année.'**
  String yearInapplicable(int count);

  /// No description provided for @errorUnknownBalance.
  ///
  /// In fr, this message translates to:
  /// **'Ce solde n\'existe plus.'**
  String get errorUnknownBalance;

  /// No description provided for @errorBalanceOnDetailedAccount.
  ///
  /// In fr, this message translates to:
  /// **'Le solde du compte détaillé vient de ses relevés : il ne se déclare pas.'**
  String get errorBalanceOnDetailedAccount;

  /// No description provided for @errorBalanceOnDebtsAccount.
  ///
  /// In fr, this message translates to:
  /// **'Un compte « Dettes » n\'a pas de solde propre : la fortune compte les dettes du tableau des dettes.'**
  String get errorBalanceOnDebtsAccount;

  /// No description provided for @errorBalanceInFuture.
  ///
  /// In fr, this message translates to:
  /// **'Un solde ne se déclare pas pour une date future.'**
  String get errorBalanceInFuture;

  /// No description provided for @accountArchivedBalances.
  ///
  /// In fr, this message translates to:
  /// **'Compte archivé et non supprimé : {count, plural, =1{un solde déclaré l\'utilise} other{{count} soldes déclarés l\'utilisent}}. Il reste dans la fortune avec son dernier solde ; déclarez un solde de 0 pour l\'en sortir.'**
  String accountArchivedBalances(int count);

  /// No description provided for @errorUnknownDebt.
  ///
  /// In fr, this message translates to:
  /// **'Cette dette n\'existe plus.'**
  String get errorUnknownDebt;

  /// No description provided for @errorDebtPersonRequired.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez la personne.'**
  String get errorDebtPersonRequired;

  /// No description provided for @errorDebtPercentInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez un pourcentage entre 0.01 et 100, avec deux décimales au plus.'**
  String get errorDebtPercentInvalid;

  /// No description provided for @errorDebtReceivedBeforeEvent.
  ///
  /// In fr, this message translates to:
  /// **'La date de réception ne peut pas précéder la date de l\'événement.'**
  String get errorDebtReceivedBeforeEvent;

  /// No description provided for @errorDebtSplitOutOfTotal.
  ///
  /// In fr, this message translates to:
  /// **'La première part doit être supérieure à zéro et inférieure au total de la dette.'**
  String get errorDebtSplitOutOfTotal;

  /// No description provided for @wealthNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun solde déclaré ni aucune dette : déclarez le solde d\'un compte pour suivre votre fortune.'**
  String get wealthNone;

  /// No description provided for @wealthNet.
  ///
  /// In fr, this message translates to:
  /// **'Fortune nette'**
  String get wealthNet;

  /// No description provided for @wealthSince.
  ///
  /// In fr, this message translates to:
  /// **'Depuis le {date}'**
  String wealthSince(String date);

  /// No description provided for @wealthAt.
  ///
  /// In fr, this message translates to:
  /// **'au {date}'**
  String wealthAt(String date);

  /// No description provided for @wealthBalanceDate.
  ///
  /// In fr, this message translates to:
  /// **'Solde du {date}'**
  String wealthBalanceDate(String date);

  /// No description provided for @wealthStatementDate.
  ///
  /// In fr, this message translates to:
  /// **'Relevé au {date}'**
  String wealthStatementDate(String date);

  /// No description provided for @wealthOld.
  ///
  /// In fr, this message translates to:
  /// **'ancien'**
  String get wealthOld;

  /// No description provided for @wealthWithoutBalance.
  ///
  /// In fr, this message translates to:
  /// **'Sans solde, hors fortune'**
  String get wealthWithoutBalance;

  /// No description provided for @wealthWithoutBalanceSection.
  ///
  /// In fr, this message translates to:
  /// **'Comptes sans solde'**
  String get wealthWithoutBalanceSection;

  /// No description provided for @wealthDebts.
  ///
  /// In fr, this message translates to:
  /// **'Dettes'**
  String get wealthDebts;

  /// No description provided for @wealthDebtsHint.
  ///
  /// In fr, this message translates to:
  /// **'Dettes ouvertes : ce qu\'on me doit moins ce que je dois.'**
  String get wealthDebtsHint;

  /// No description provided for @wealthCurve.
  ///
  /// In fr, this message translates to:
  /// **'Évolution'**
  String get wealthCurve;

  /// No description provided for @wealthCurveHint.
  ///
  /// In fr, this message translates to:
  /// **'Fortune à la fin de chaque mois. Touchez la courbe pour lire un mois.'**
  String get wealthCurveHint;

  /// No description provided for @wealthCurvePoint.
  ///
  /// In fr, this message translates to:
  /// **'{month} : {amount}'**
  String wealthCurvePoint(String month, String amount);

  /// No description provided for @wealthExplain.
  ///
  /// In fr, this message translates to:
  /// **'Pourquoi la fortune a varié'**
  String get wealthExplain;

  /// No description provided for @wealthExplainPeriod.
  ///
  /// In fr, this message translates to:
  /// **'Du {start} au {end}'**
  String wealthExplainPeriod(String start, String end);

  /// No description provided for @wealthNoTree.
  ///
  /// In fr, this message translates to:
  /// **'Pas d\'arbre de catégories cette année : seuls les soldes et les dettes y figurent.'**
  String get wealthNoTree;

  /// No description provided for @explainEconomic.
  ///
  /// In fr, this message translates to:
  /// **'Résultat économique'**
  String get explainEconomic;

  /// No description provided for @explainOffsets.
  ///
  /// In fr, this message translates to:
  /// **'+ Décalages de période'**
  String get explainOffsets;

  /// No description provided for @explainCash.
  ///
  /// In fr, this message translates to:
  /// **'= Résultat de trésorerie'**
  String get explainCash;

  /// No description provided for @explainVariations.
  ///
  /// In fr, this message translates to:
  /// **'+ Variations de valeur'**
  String get explainVariations;

  /// No description provided for @explainAdded.
  ///
  /// In fr, this message translates to:
  /// **'+ Comptes ajoutés'**
  String get explainAdded;

  /// No description provided for @explainDebts.
  ///
  /// In fr, this message translates to:
  /// **'+ Variation des dettes ouvertes'**
  String get explainDebts;

  /// No description provided for @explainDebtsDetail.
  ///
  /// In fr, this message translates to:
  /// **'Dettes ouvertes au début {start}, à la fin {end} ; mouvements des comptes « Dettes » {movements}'**
  String explainDebtsDetail(String start, String end, String movements);

  /// No description provided for @explainUnclassified.
  ///
  /// In fr, this message translates to:
  /// **'+ Non classé'**
  String get explainUnclassified;

  /// No description provided for @explainOutside.
  ///
  /// In fr, this message translates to:
  /// **'+ Hors fortune'**
  String get explainOutside;

  /// No description provided for @explainOutsideHint.
  ///
  /// In fr, this message translates to:
  /// **'Mouvements de comptes qui n\'avaient pas encore de solde, ou qui n\'existent plus.'**
  String get explainOutsideHint;

  /// No description provided for @explainChange.
  ///
  /// In fr, this message translates to:
  /// **'= Variation de la fortune'**
  String get explainChange;

  /// No description provided for @explainDeletedAccount.
  ///
  /// In fr, this message translates to:
  /// **'Compte supprimé'**
  String get explainDeletedAccount;

  /// No description provided for @accountBalanceNow.
  ///
  /// In fr, this message translates to:
  /// **'Solde'**
  String get accountBalanceNow;

  /// No description provided for @accountDeclare.
  ///
  /// In fr, this message translates to:
  /// **'Déclarer un solde'**
  String get accountDeclare;

  /// No description provided for @accountDeclareAmount.
  ///
  /// In fr, this message translates to:
  /// **'Solde (négatif pour un prêt)'**
  String get accountDeclareAmount;

  /// No description provided for @accountDeclareDate.
  ///
  /// In fr, this message translates to:
  /// **'Date du solde'**
  String get accountDeclareDate;

  /// No description provided for @accountBalanceEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le solde'**
  String get accountBalanceEdit;

  /// No description provided for @accountBalanceDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer le solde du {date} ?'**
  String accountBalanceDeleteConfirm(String date);

  /// No description provided for @accountBalanceDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Solde supprimé.'**
  String get accountBalanceDeleted;

  /// No description provided for @accountBalanceInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un montant et une date valides.'**
  String get accountBalanceInvalid;

  /// No description provided for @accountVariationResult.
  ///
  /// In fr, this message translates to:
  /// **'Variation de valeur : {amount}'**
  String accountVariationResult(String amount);

  /// No description provided for @accountEntersWealth.
  ///
  /// In fr, this message translates to:
  /// **'Le compte entre dans la fortune avec {amount}.'**
  String accountEntersWealth(String amount);

  /// No description provided for @accountHistory.
  ///
  /// In fr, this message translates to:
  /// **'Historique des soldes'**
  String get accountHistory;

  /// No description provided for @accountExpected.
  ///
  /// In fr, this message translates to:
  /// **'Attendu {amount}'**
  String accountExpected(String amount);

  /// No description provided for @accountVariation.
  ///
  /// In fr, this message translates to:
  /// **'Variation {amount}'**
  String accountVariation(String amount);

  /// No description provided for @accountFirstBalance.
  ///
  /// In fr, this message translates to:
  /// **'Premier solde : le compte entre dans la fortune.'**
  String get accountFirstBalance;

  /// No description provided for @accountStatementPoint.
  ///
  /// In fr, this message translates to:
  /// **'Solde initial du premier relevé'**
  String get accountStatementPoint;

  /// No description provided for @accountMovementsCount.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =0{Aucun mouvement} =1{Un mouvement} other{{count} mouvements}}'**
  String accountMovementsCount(int count);

  /// No description provided for @accountMovementsSince.
  ///
  /// In fr, this message translates to:
  /// **'Mouvements depuis le dernier solde'**
  String get accountMovementsSince;

  /// No description provided for @accountMovementsBefore.
  ///
  /// In fr, this message translates to:
  /// **'Mouvements avant le premier solde, compris dans celui-ci'**
  String get accountMovementsBefore;

  /// No description provided for @accountDetailedHint.
  ///
  /// In fr, this message translates to:
  /// **'Compte détaillé : son solde vient de ses relevés, il ne se déclare pas.'**
  String get accountDetailedHint;

  /// No description provided for @accountDebtsHint.
  ///
  /// In fr, this message translates to:
  /// **'Un compte « Dettes » n\'a pas de solde propre : la fortune compte le tableau des dettes.'**
  String get accountDebtsHint;

  /// No description provided for @accountNoBalance.
  ///
  /// In fr, this message translates to:
  /// **'Sans solde déclaré, ce compte est hors de la fortune.'**
  String get accountNoBalance;

  /// No description provided for @accountIgnoredBalances.
  ///
  /// In fr, this message translates to:
  /// **'Soldes ignorés'**
  String get accountIgnoredBalances;

  /// No description provided for @accountOpenBalances.
  ///
  /// In fr, this message translates to:
  /// **'Soldes et mouvements'**
  String get accountOpenBalances;

  /// No description provided for @accountOldBalance.
  ///
  /// In fr, this message translates to:
  /// **'Dernier solde déclaré il y a plus de 6 mois.'**
  String get accountOldBalance;

  /// No description provided for @accountEditAccount.
  ///
  /// In fr, this message translates to:
  /// **'Modifier le compte'**
  String get accountEditAccount;

  /// No description provided for @taskOldBalance.
  ///
  /// In fr, this message translates to:
  /// **'Solde de « {name} » à mettre à jour'**
  String taskOldBalance(String name);

  /// No description provided for @taskOldBalanceHint.
  ///
  /// In fr, this message translates to:
  /// **'Dernier solde déclaré le {date}, il y a plus de 6 mois.'**
  String taskOldBalanceHint(String date);

  /// No description provided for @keyFiguresWealth.
  ///
  /// In fr, this message translates to:
  /// **'Fortune nette'**
  String get keyFiguresWealth;

  /// No description provided for @keyFiguresWealthOpen.
  ///
  /// In fr, this message translates to:
  /// **'Voir la fortune'**
  String get keyFiguresWealthOpen;

  /// No description provided for @debtsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Dettes'**
  String get debtsTitle;

  /// No description provided for @debtsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune dette. Une dette compte dans la fortune du jour de l\'événement à la veille de sa réception.'**
  String get debtsEmpty;

  /// No description provided for @debtsOpen.
  ///
  /// In fr, this message translates to:
  /// **'Ouvertes'**
  String get debtsOpen;

  /// No description provided for @debtsRepaid.
  ///
  /// In fr, this message translates to:
  /// **'Remboursées'**
  String get debtsRepaid;

  /// No description provided for @debtsOwedToMe.
  ///
  /// In fr, this message translates to:
  /// **'On me doit'**
  String get debtsOwedToMe;

  /// No description provided for @debtsIOwe.
  ///
  /// In fr, this message translates to:
  /// **'Je dois'**
  String get debtsIOwe;

  /// No description provided for @debtsNet.
  ///
  /// In fr, this message translates to:
  /// **'Net, dans la fortune'**
  String get debtsNet;

  /// No description provided for @debtNew.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle dette'**
  String get debtNew;

  /// No description provided for @debtEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la dette'**
  String get debtEdit;

  /// No description provided for @debtOwedToMe.
  ///
  /// In fr, this message translates to:
  /// **'On me doit'**
  String get debtOwedToMe;

  /// No description provided for @debtIOwe.
  ///
  /// In fr, this message translates to:
  /// **'Je dois'**
  String get debtIOwe;

  /// No description provided for @debtPerson.
  ///
  /// In fr, this message translates to:
  /// **'Personne'**
  String get debtPerson;

  /// No description provided for @debtAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get debtAmount;

  /// No description provided for @debtPercent.
  ///
  /// In fr, this message translates to:
  /// **'Pourcentage'**
  String get debtPercent;

  /// No description provided for @debtTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total : {amount}'**
  String debtTotal(String amount);

  /// No description provided for @debtEventDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de l\'événement'**
  String get debtEventDate;

  /// No description provided for @debtInvoiceDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de la facture'**
  String get debtInvoiceDate;

  /// No description provided for @debtRequestDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de la demande'**
  String get debtRequestDate;

  /// No description provided for @debtReceivedDate.
  ///
  /// In fr, this message translates to:
  /// **'Date de réception'**
  String get debtReceivedDate;

  /// No description provided for @debtDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get debtDescription;

  /// No description provided for @debtRepaid.
  ///
  /// In fr, this message translates to:
  /// **'Remboursée'**
  String get debtRepaid;

  /// No description provided for @debtDatesHint.
  ///
  /// In fr, this message translates to:
  /// **'Sans date d\'événement, la dette compte du jour de sa saisie ; remboursée sans date de réception, jusqu\'à la veille du jour où elle est cochée.'**
  String get debtDatesHint;

  /// No description provided for @debtInvalidDate.
  ///
  /// In fr, this message translates to:
  /// **'Date invalide : jj.mm.aaaa, ou laissez vide.'**
  String get debtInvalidDate;

  /// No description provided for @debtSince.
  ///
  /// In fr, this message translates to:
  /// **'depuis le {date}'**
  String debtSince(String date);

  /// No description provided for @debtReceivedOn.
  ///
  /// In fr, this message translates to:
  /// **'reçue le {date}'**
  String debtReceivedOn(String date);

  /// No description provided for @debtCheckTitle.
  ///
  /// In fr, this message translates to:
  /// **'Dette remboursée'**
  String get debtCheckTitle;

  /// No description provided for @debtCheckHint.
  ///
  /// In fr, this message translates to:
  /// **'La dette cesse de compter dans la fortune le jour de sa réception.'**
  String get debtCheckHint;

  /// No description provided for @debtCheck.
  ///
  /// In fr, this message translates to:
  /// **'Cocher remboursée'**
  String get debtCheck;

  /// No description provided for @debtUncheck.
  ///
  /// In fr, this message translates to:
  /// **'Décocher'**
  String get debtUncheck;

  /// No description provided for @debtSplit.
  ///
  /// In fr, this message translates to:
  /// **'Scinder'**
  String get debtSplit;

  /// No description provided for @debtSplitTitle.
  ///
  /// In fr, this message translates to:
  /// **'Scinder la dette'**
  String get debtSplitTitle;

  /// No description provided for @debtSplitHint.
  ///
  /// In fr, this message translates to:
  /// **'Montant de la première part, pris sur le total de {total}. Le reste forme une deuxième ligne, avec les mêmes personne, sens, dates et description.'**
  String debtSplitHint(String total);

  /// No description provided for @debtSplitFirst.
  ///
  /// In fr, this message translates to:
  /// **'Première part'**
  String get debtSplitFirst;

  /// No description provided for @debtSplitDone.
  ///
  /// In fr, this message translates to:
  /// **'Dette scindée en {first} et {second}.'**
  String debtSplitDone(String first, String second);

  /// No description provided for @debtDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la dette de {person} ?'**
  String debtDeleteConfirm(String person);

  /// No description provided for @debtDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Dette supprimée.'**
  String get debtDeleted;

  /// No description provided for @accountDebtsOpen.
  ///
  /// In fr, this message translates to:
  /// **'Voir le tableau des dettes'**
  String get accountDebtsOpen;

  /// No description provided for @errorModuleCategoryRequired.
  ///
  /// In fr, this message translates to:
  /// **'Indiquez le nom de la catégorie.'**
  String get errorModuleCategoryRequired;

  /// No description provided for @errorUnknownSalarySheet.
  ///
  /// In fr, this message translates to:
  /// **'Cette fiche salaire n\'existe plus.'**
  String get errorUnknownSalarySheet;

  /// No description provided for @errorSalaryGrossRequired.
  ///
  /// In fr, this message translates to:
  /// **'Saisissez un salaire brut supérieur à zéro.'**
  String get errorSalaryGrossRequired;

  /// No description provided for @errorSalaryNetNegative.
  ///
  /// In fr, this message translates to:
  /// **'Le salaire net ne peut pas être négatif.'**
  String get errorSalaryNetNegative;

  /// No description provided for @errorSalaryDeductionLabelRequired.
  ///
  /// In fr, this message translates to:
  /// **'Chaque déduction a un libellé.'**
  String get errorSalaryDeductionLabelRequired;

  /// No description provided for @errorSalaryDeductionNegative.
  ///
  /// In fr, this message translates to:
  /// **'Une déduction ne peut pas être négative.'**
  String get errorSalaryDeductionNegative;

  /// No description provided for @moreAnalyses.
  ///
  /// In fr, this message translates to:
  /// **'Analyses'**
  String get moreAnalyses;

  /// No description provided for @moreSettings.
  ///
  /// In fr, this message translates to:
  /// **'Réglages'**
  String get moreSettings;

  /// No description provided for @moduleCategory.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie liée : « {name} »'**
  String moduleCategory(String name);

  /// No description provided for @moduleCategoryFound.
  ///
  /// In fr, this message translates to:
  /// **'Trouvée dans l\'arbre de {year}.'**
  String moduleCategoryFound(String year);

  /// No description provided for @moduleCategoryMissing.
  ///
  /// In fr, this message translates to:
  /// **'Aucune catégorie de ce nom dans l\'arbre de {year}.'**
  String moduleCategoryMissing(String year);

  /// No description provided for @moduleCategoryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Catégorie liée'**
  String get moduleCategoryTitle;

  /// No description provided for @moduleCategoryHint.
  ///
  /// In fr, this message translates to:
  /// **'Le même nom pour toutes les années, sans tenir compte des majuscules ni des accents. Un groupe compte avec tout ce qu\'il contient.'**
  String get moduleCategoryHint;

  /// No description provided for @moduleCategoryName.
  ///
  /// In fr, this message translates to:
  /// **'Nom de la catégorie'**
  String get moduleCategoryName;

  /// No description provided for @salaryTitle.
  ///
  /// In fr, this message translates to:
  /// **'Fiche salaire'**
  String get salaryTitle;

  /// No description provided for @salaryMenuHint.
  ///
  /// In fr, this message translates to:
  /// **'Brut, déductions et net de chaque année.'**
  String get salaryMenuHint;

  /// No description provided for @salaryYear.
  ///
  /// In fr, this message translates to:
  /// **'Année'**
  String get salaryYear;

  /// No description provided for @salaryGross.
  ///
  /// In fr, this message translates to:
  /// **'Salaire brut'**
  String get salaryGross;

  /// No description provided for @salaryNet.
  ///
  /// In fr, this message translates to:
  /// **'Salaire net'**
  String get salaryNet;

  /// No description provided for @salaryDeductions.
  ///
  /// In fr, this message translates to:
  /// **'Déductions'**
  String get salaryDeductions;

  /// No description provided for @salaryDeductionLabel.
  ///
  /// In fr, this message translates to:
  /// **'Libellé'**
  String get salaryDeductionLabel;

  /// No description provided for @salaryDeductionAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get salaryDeductionAmount;

  /// No description provided for @salaryDeductionAdd.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une déduction'**
  String get salaryDeductionAdd;

  /// No description provided for @salaryDeductionRemove.
  ///
  /// In fr, this message translates to:
  /// **'Retirer'**
  String get salaryDeductionRemove;

  /// No description provided for @salaryDeductionsTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total des déductions : {amount}'**
  String salaryDeductionsTotal(String amount);

  /// No description provided for @salaryGap.
  ///
  /// In fr, this message translates to:
  /// **'Écart : {amount} (brut moins déductions moins net)'**
  String salaryGap(String amount);

  /// No description provided for @salaryBalanced.
  ///
  /// In fr, this message translates to:
  /// **'Le brut moins les déductions donne le net.'**
  String get salaryBalanced;

  /// No description provided for @salaryNew.
  ///
  /// In fr, this message translates to:
  /// **'Pas encore de fiche pour {year} : les libellés proposés sont ceux de la fiche précédente.'**
  String salaryNew(String year);

  /// No description provided for @salarySaved.
  ///
  /// In fr, this message translates to:
  /// **'Fiche salaire enregistrée.'**
  String get salarySaved;

  /// No description provided for @salaryDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer la fiche salaire de {year} ?'**
  String salaryDeleteConfirm(String year);

  /// No description provided for @salaryDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Fiche salaire supprimée.'**
  String get salaryDeleted;

  /// No description provided for @salaryInvalidAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant invalide.'**
  String get salaryInvalidAmount;

  /// No description provided for @salaryTwoEmployers.
  ///
  /// In fr, this message translates to:
  /// **'Avec deux employeurs, additionnez les montants des deux certificats.'**
  String get salaryTwoEmployers;

  /// No description provided for @flowButton.
  ///
  /// In fr, this message translates to:
  /// **'Flux'**
  String get flowButton;

  /// No description provided for @flowTitle.
  ///
  /// In fr, this message translates to:
  /// **'Flux {year}'**
  String flowTitle(String year);

  /// No description provided for @flowGross.
  ///
  /// In fr, this message translates to:
  /// **'Salaire brut'**
  String get flowGross;

  /// No description provided for @flowGroupWithout.
  ///
  /// In fr, this message translates to:
  /// **'{group} hors {categories}'**
  String flowGroupWithout(String group, String categories);

  /// No description provided for @flowAnd.
  ///
  /// In fr, this message translates to:
  /// **' et '**
  String get flowAnd;

  /// No description provided for @flowFromWealth.
  ///
  /// In fr, this message translates to:
  /// **'Puisé dans la fortune'**
  String get flowFromWealth;

  /// No description provided for @flowFromGross.
  ///
  /// In fr, this message translates to:
  /// **'Le diagramme part du salaire brut de la fiche {year}.'**
  String flowFromGross(String year);

  /// No description provided for @flowFromNet.
  ///
  /// In fr, this message translates to:
  /// **'Le diagramme part du salaire net : pas de fiche salaire pour {year}.'**
  String flowFromNet(String year);

  /// No description provided for @flowNoSalary.
  ///
  /// In fr, this message translates to:
  /// **'Pas de catégorie « {name} » en {year} : le diagramme part des groupes de revenus.'**
  String flowNoSalary(String name, String year);

  /// No description provided for @flowGrossGap.
  ///
  /// In fr, this message translates to:
  /// **'Écart avec le brut saisi : {amount} (net reçu plus déductions, moins le brut de la fiche).'**
  String flowGrossGap(String amount);

  /// No description provided for @flowUnclassified.
  ///
  /// In fr, this message translates to:
  /// **'« Non classé » ({amount}) n\'entre pas dans le diagramme.'**
  String flowUnclassified(String amount);

  /// No description provided for @flowEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Rien à montrer pour cette année.'**
  String get flowEmpty;

  /// No description provided for @flowLeft.
  ///
  /// In fr, this message translates to:
  /// **'D\'où vient l\'argent'**
  String get flowLeft;

  /// No description provided for @flowRight.
  ///
  /// In fr, this message translates to:
  /// **'Où il va'**
  String get flowRight;

  /// No description provided for @flowTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total : {amount}'**
  String flowTotal(String amount);

  /// No description provided for @errorUnknownTaxYear.
  ///
  /// In fr, this message translates to:
  /// **'Cette année fiscale n\'existe plus.'**
  String get errorUnknownTaxYear;

  /// No description provided for @errorTaxBaseNegative.
  ///
  /// In fr, this message translates to:
  /// **'Une base imposable ne peut pas être négative.'**
  String get errorTaxBaseNegative;

  /// No description provided for @errorTaxRateInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Un taux de base va de 0 à 100 %, avec quatre décimales au plus.'**
  String get errorTaxRateInvalid;

  /// No description provided for @errorTaxCoefficientNegative.
  ///
  /// In fr, this message translates to:
  /// **'Un coefficient ne peut pas être négatif.'**
  String get errorTaxCoefficientNegative;

  /// No description provided for @errorTaxMarginalRateInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Le taux marginal va de 0 à 100 %, avec deux décimales au plus.'**
  String get errorTaxMarginalRateInvalid;

  /// No description provided for @taxesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Impôts'**
  String get taxesTitle;

  /// No description provided for @taxesMenuHint.
  ///
  /// In fr, this message translates to:
  /// **'Par année fiscale : lignes, total et contrôle des paiements.'**
  String get taxesMenuHint;

  /// No description provided for @taxesYear.
  ///
  /// In fr, this message translates to:
  /// **'Année fiscale'**
  String get taxesYear;

  /// No description provided for @taxesFederalIncome.
  ///
  /// In fr, this message translates to:
  /// **'Revenu fédéral'**
  String get taxesFederalIncome;

  /// No description provided for @taxesCantonalIncome.
  ///
  /// In fr, this message translates to:
  /// **'Revenu cantonal'**
  String get taxesCantonalIncome;

  /// No description provided for @taxesCommunalIncome.
  ///
  /// In fr, this message translates to:
  /// **'Revenu communal'**
  String get taxesCommunalIncome;

  /// No description provided for @taxesCantonalWealth.
  ///
  /// In fr, this message translates to:
  /// **'Fortune cantonale'**
  String get taxesCantonalWealth;

  /// No description provided for @taxesCommunalWealth.
  ///
  /// In fr, this message translates to:
  /// **'Fortune communale'**
  String get taxesCommunalWealth;

  /// No description provided for @taxesBase.
  ///
  /// In fr, this message translates to:
  /// **'Base imposable'**
  String get taxesBase;

  /// No description provided for @taxesTaxableWealth.
  ///
  /// In fr, this message translates to:
  /// **'Fortune imposable'**
  String get taxesTaxableWealth;

  /// No description provided for @taxesBaseRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux de base %'**
  String get taxesBaseRate;

  /// No description provided for @taxesCoefficient.
  ///
  /// In fr, this message translates to:
  /// **'Coefficient %'**
  String get taxesCoefficient;

  /// No description provided for @taxesMarginalRate.
  ///
  /// In fr, this message translates to:
  /// **'Taux marginal (TMI) %'**
  String get taxesMarginalRate;

  /// No description provided for @taxesLineResult.
  ///
  /// In fr, this message translates to:
  /// **'Taux total {rate} · {amount}'**
  String taxesLineResult(String rate, String amount);

  /// No description provided for @taxesLineIncomplete.
  ///
  /// In fr, this message translates to:
  /// **'Ligne incomplète : 0.00'**
  String get taxesLineIncomplete;

  /// No description provided for @taxesTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get taxesTotal;

  /// No description provided for @taxesShareOfGross.
  ///
  /// In fr, this message translates to:
  /// **'Part du brut'**
  String get taxesShareOfGross;

  /// No description provided for @taxesShareOfNet.
  ///
  /// In fr, this message translates to:
  /// **'Part du net'**
  String get taxesShareOfNet;

  /// No description provided for @taxesNoSheet.
  ///
  /// In fr, this message translates to:
  /// **'Sans fiche salaire pour {year}, les parts du brut et du net ne s\'affichent pas.'**
  String taxesNoSheet(String year);

  /// No description provided for @taxesControl.
  ///
  /// In fr, this message translates to:
  /// **'Contrôle'**
  String get taxesControl;

  /// No description provided for @taxesPaid.
  ///
  /// In fr, this message translates to:
  /// **'Payé pour {year}'**
  String taxesPaid(String year);

  /// No description provided for @taxesPaidHint.
  ///
  /// In fr, this message translates to:
  /// **'Ce que la vue économique de {year} compte dans la catégorie liée : la période compte, pas la date de paiement.'**
  String taxesPaidHint(String year);

  /// No description provided for @taxesLeftToPay.
  ///
  /// In fr, this message translates to:
  /// **'Reste à payer'**
  String get taxesLeftToPay;

  /// No description provided for @taxesPaidTooMuch.
  ///
  /// In fr, this message translates to:
  /// **'Payé en trop'**
  String get taxesPaidTooMuch;

  /// No description provided for @taxesSettled.
  ///
  /// In fr, this message translates to:
  /// **'Payé exactement'**
  String get taxesSettled;

  /// No description provided for @taxesNoControl.
  ///
  /// In fr, this message translates to:
  /// **'Pas de contrôle pour {year} : l\'année n\'a pas d\'arbre de catégories, ou pas de catégorie liée.'**
  String taxesNoControl(String year);

  /// No description provided for @taxesSummary.
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif'**
  String get taxesSummary;

  /// No description provided for @taxesSummaryLine.
  ///
  /// In fr, this message translates to:
  /// **'Total {total} · brut {gross} · net {net} · TMI {marginal} · payé {paid} · écart {gap}'**
  String taxesSummaryLine(String total, String gross, String net, String marginal, String paid, String gap);

  /// No description provided for @taxesSaved.
  ///
  /// In fr, this message translates to:
  /// **'Année fiscale enregistrée.'**
  String get taxesSaved;

  /// No description provided for @taxesDeleteConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer l\'année fiscale {year} ?'**
  String taxesDeleteConfirm(String year);

  /// No description provided for @taxesDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Année fiscale supprimée.'**
  String get taxesDeleted;

  /// No description provided for @taxesInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Valeur invalide : vérifiez les montants et les pourcentages.'**
  String get taxesInvalid;

  /// No description provided for @taxesNone.
  ///
  /// In fr, this message translates to:
  /// **'–'**
  String get taxesNone;

  /// No description provided for @errorUnknownTripSheet.
  ///
  /// In fr, this message translates to:
  /// **'Cette fiche de voyage n\'existe plus.'**
  String get errorUnknownTripSheet;

  /// No description provided for @errorTripDaysInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Un voyage dure au moins un jour.'**
  String get errorTripDaysInvalid;

  /// No description provided for @errorTripDateRequired.
  ///
  /// In fr, this message translates to:
  /// **'Une ligne manuelle a une date.'**
  String get errorTripDateRequired;

  /// No description provided for @errorTripAmountRequired.
  ///
  /// In fr, this message translates to:
  /// **'Une ligne manuelle a un montant.'**
  String get errorTripAmountRequired;

  /// No description provided for @vacationsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vacances'**
  String get vacationsTitle;

  /// No description provided for @vacationsMenuHint.
  ///
  /// In fr, this message translates to:
  /// **'Les voyages, regroupés par leurs périodes.'**
  String get vacationsMenuHint;

  /// No description provided for @vacationsNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucun voyage : les transactions de la catégorie liée forment les voyages, selon leurs périodes.'**
  String get vacationsNone;

  /// No description provided for @vacationsYearTotal.
  ///
  /// In fr, this message translates to:
  /// **'{year} · {amount}'**
  String vacationsYearTotal(String year, String amount);

  /// No description provided for @vacationsTripSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'{date} · {days}'**
  String vacationsTripSubtitle(String date, String days);

  /// No description provided for @vacationsDays.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{1 jour} other{{count} jours}}'**
  String vacationsDays(int count);

  /// No description provided for @vacationsNoDays.
  ///
  /// In fr, this message translates to:
  /// **'jours à saisir'**
  String get vacationsNoDays;

  /// No description provided for @vacationsPerDay.
  ///
  /// In fr, this message translates to:
  /// **'{amount} par jour'**
  String vacationsPerDay(String amount);

  /// No description provided for @vacationsNoPlace.
  ///
  /// In fr, this message translates to:
  /// **'Voyage sans lieu'**
  String get vacationsNoPlace;

  /// No description provided for @vacationsManual.
  ///
  /// In fr, this message translates to:
  /// **'Ligne manuelle'**
  String get vacationsManual;

  /// No description provided for @vacationsNewManual.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle ligne manuelle'**
  String get vacationsNewManual;

  /// No description provided for @vacationsTrip.
  ///
  /// In fr, this message translates to:
  /// **'Voyage'**
  String get vacationsTrip;

  /// No description provided for @vacationsPlace.
  ///
  /// In fr, this message translates to:
  /// **'Lieu'**
  String get vacationsPlace;

  /// No description provided for @vacationsDaysField.
  ///
  /// In fr, this message translates to:
  /// **'Jours'**
  String get vacationsDaysField;

  /// No description provided for @vacationsDate.
  ///
  /// In fr, this message translates to:
  /// **'Date'**
  String get vacationsDate;

  /// No description provided for @vacationsAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant'**
  String get vacationsAmount;

  /// No description provided for @vacationsReplaceDate.
  ///
  /// In fr, this message translates to:
  /// **'Date remplacée'**
  String get vacationsReplaceDate;

  /// No description provided for @vacationsReplaceAmount.
  ///
  /// In fr, this message translates to:
  /// **'Montant remplacé'**
  String get vacationsReplaceAmount;

  /// No description provided for @vacationsAutomatic.
  ///
  /// In fr, this message translates to:
  /// **'Automatique : {value}'**
  String vacationsAutomatic(String value);

  /// No description provided for @vacationsRestore.
  ///
  /// In fr, this message translates to:
  /// **'Rétablir'**
  String get vacationsRestore;

  /// No description provided for @vacationsTransactions.
  ///
  /// In fr, this message translates to:
  /// **'Transactions du voyage'**
  String get vacationsTransactions;

  /// No description provided for @vacationsExtraSheets.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Une autre fiche est accrochée à ce voyage : la plus ancienne s\'applique.} other{{count} autres fiches sont accrochées à ce voyage : la plus ancienne s\'applique.}}'**
  String vacationsExtraSheets(int count);

  /// No description provided for @vacationsOrphans.
  ///
  /// In fr, this message translates to:
  /// **'Fiches sans transaction'**
  String get vacationsOrphans;

  /// No description provided for @vacationsOrphansHint.
  ///
  /// In fr, this message translates to:
  /// **'Leur transaction a quitté la catégorie ou n\'existe plus.'**
  String get vacationsOrphansHint;

  /// No description provided for @vacationsSaved.
  ///
  /// In fr, this message translates to:
  /// **'Voyage enregistré.'**
  String get vacationsSaved;

  /// No description provided for @vacationsDeleted.
  ///
  /// In fr, this message translates to:
  /// **'Fiche supprimée.'**
  String get vacationsDeleted;

  /// No description provided for @vacationsInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Valeur invalide : vérifiez la date, le montant et les jours.'**
  String get vacationsInvalid;

  /// No description provided for @errorUnknownElectricityReading.
  ///
  /// In fr, this message translates to:
  /// **'Cette ligne n\'a pas de kWh saisis.'**
  String get errorUnknownElectricityReading;

  /// No description provided for @errorElectricityNegative.
  ///
  /// In fr, this message translates to:
  /// **'Les kWh ne peuvent pas être négatifs.'**
  String get errorElectricityNegative;

  /// No description provided for @electricityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Électricité'**
  String get electricityTitle;

  /// No description provided for @electricityMenuHint.
  ///
  /// In fr, this message translates to:
  /// **'Prix, kWh et jours par année.'**
  String get electricityMenuHint;

  /// No description provided for @electricityNone.
  ///
  /// In fr, this message translates to:
  /// **'Aucune facture : les transactions de la catégorie liée apparaissent ici.'**
  String get electricityNone;

  /// No description provided for @electricityPrice.
  ///
  /// In fr, this message translates to:
  /// **'Prix total'**
  String get electricityPrice;

  /// No description provided for @electricityKwh.
  ///
  /// In fr, this message translates to:
  /// **'kWh'**
  String get electricityKwh;

  /// No description provided for @electricityDays.
  ///
  /// In fr, this message translates to:
  /// **'Jours'**
  String get electricityDays;

  /// No description provided for @electricityPerDay.
  ///
  /// In fr, this message translates to:
  /// **'CHF par jour'**
  String get electricityPerDay;

  /// No description provided for @electricityPerKwh.
  ///
  /// In fr, this message translates to:
  /// **'CHF par kWh'**
  String get electricityPerKwh;

  /// No description provided for @electricityKwhPerDay.
  ///
  /// In fr, this message translates to:
  /// **'kWh par jour'**
  String get electricityKwhPerDay;

  /// No description provided for @electricityMissing.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{Une ligne sans kWh : le prix par kWh est surestimé.} other{{count} lignes sans kWh : le prix par kWh est surestimé.}}'**
  String electricityMissing(int count);

  /// No description provided for @electricityLines.
  ///
  /// In fr, this message translates to:
  /// **'Factures de {year}'**
  String electricityLines(String year);

  /// No description provided for @electricityLine.
  ///
  /// In fr, this message translates to:
  /// **'{date} · {start} – {end} · {days} j'**
  String electricityLine(String date, String start, String end, String days);

  /// No description provided for @electricityLineKwh.
  ///
  /// In fr, this message translates to:
  /// **'{kwh} kWh'**
  String electricityLineKwh(String kwh);

  /// No description provided for @electricityNoKwh.
  ///
  /// In fr, this message translates to:
  /// **'kWh à saisir'**
  String get electricityNoKwh;

  /// No description provided for @electricityEnter.
  ///
  /// In fr, this message translates to:
  /// **'kWh de la facture'**
  String get electricityEnter;

  /// No description provided for @electricityErase.
  ///
  /// In fr, this message translates to:
  /// **'Effacer'**
  String get electricityErase;

  /// No description provided for @electricityInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Nombre de kWh invalide.'**
  String get electricityInvalid;

  /// No description provided for @electricityOrphans.
  ///
  /// In fr, this message translates to:
  /// **'kWh sans facture'**
  String get electricityOrphans;

  /// No description provided for @electricityOrphansHint.
  ///
  /// In fr, this message translates to:
  /// **'Leur transaction a quitté la catégorie ou n\'existe plus.'**
  String get electricityOrphansHint;
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

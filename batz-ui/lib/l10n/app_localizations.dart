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

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
  String get startupErrorTitle => 'batz ne peut pas démarrer';

  @override
  String get startupErrorBody => 'La base de données locale n\'a pas pu être ouverte. Détail technique :';

  @override
  String get cancel => 'Annuler';

  @override
  String get close => 'Fermer';

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

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get accountsTitle => 'Comptes';

  @override
  String get accountsEmpty => 'Aucun compte. Créez-en un avec le bouton +.';

  @override
  String get accountsArchivedSection => 'Archivés';

  @override
  String get accountNew => 'Nouveau compte';

  @override
  String get accountEdit => 'Modifier le compte';

  @override
  String get accountName => 'Nom';

  @override
  String get accountType => 'Type';

  @override
  String get accountImport => 'Import';

  @override
  String get accountImportHint => 'Compte détaillé : ses transactions viennent uniquement des relevés importés.';

  @override
  String get accountImportNone => 'Aucun : solde déclaré';

  @override
  String get accountImportPostfinance => 'Relevés PDF PostFinance';

  @override
  String get accountImportNeon => 'Exports CSV Neon';

  @override
  String get accountArchived => 'Archivé';

  @override
  String get accountDeclared => 'Déclaré aux impôts';

  @override
  String get accountDeclaredHint => 'Son nom et son solde s\'affichent dans une autre couleur dans « Fortune ».';

  @override
  String get accountDetailed => 'Détaillé';

  @override
  String accountDeleteConfirm(String name) {
    return 'Supprimer le compte « $name » ? S\'il est utilisé par des transactions, il sera archivé.';
  }

  @override
  String accountArchivedInstead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions l\'utilisent',
      one: 'une transaction l\'utilise',
    );
    return 'Compte archivé et non supprimé : $_temp0.';
  }

  @override
  String get accountDeleted => 'Compte supprimé.';

  @override
  String get accountTypePrivateAccount => 'Compte privé';

  @override
  String get accountTypeSavings => 'Épargne';

  @override
  String get accountTypePillar3 => '3e pilier';

  @override
  String get accountTypePillar2 => '2e pilier';

  @override
  String get accountTypeInvestments => 'Investissements';

  @override
  String get accountTypeVehicle => 'Véhicule';

  @override
  String get accountTypeRentDeposit => 'Garantie de loyer';

  @override
  String get accountTypeCash => 'Espèces';

  @override
  String get accountTypeDebts => 'Dettes';

  @override
  String get accountTypeOther => 'Autre';

  @override
  String get errorNameRequired => 'Le nom est obligatoire.';

  @override
  String get errorUnknownAccount => 'Ce compte n\'existe plus.';

  @override
  String get categoriesTitle => 'Catégories et règles';

  @override
  String get categoriesTransfers => 'Transferts';

  @override
  String get categoriesTransfersHint => 'Règles qui marquent une ligne comme transfert vers un compte.';

  @override
  String get categoriesAddTransferRule => 'Ajouter une règle de transfert';

  @override
  String get categoriesUnusableRules => 'Règles sans cible utilisable';

  @override
  String get categoriesUnusableRulesHint =>
      'Leur catégorie ou leur compte n\'est plus utilisable : elles ne proposent rien.';

  @override
  String get categoriesYear => 'Année';

  @override
  String categoriesNoTree(int year) {
    return 'Pas encore d\'arbre pour $year.';
  }

  @override
  String categoriesNoTreeCopy(int source, int year) {
    return 'Il sera copié de l\'arbre $source, puis modifiable sans effet sur $source. La première transaction de $year le crée aussi.';
  }

  @override
  String categoriesNoTreeDefault(int year) {
    return 'Il partira de deux groupes vides, « Revenus » et « Dépenses ». La première transaction de $year le crée aussi.';
  }

  @override
  String categoriesCreateTree(int year) {
    return 'Créer l\'arbre $year';
  }

  @override
  String get categoriesNewGroup => 'Nouveau groupe';

  @override
  String get categoryName => 'Nom';

  @override
  String get categoryNature => 'Nature';

  @override
  String get categoryAddChild => 'Ajouter une sous-catégorie';

  @override
  String get categoryRename => 'Renommer';

  @override
  String get categoryMove => 'Déplacer';

  @override
  String get categoryMoveUp => 'Monter';

  @override
  String get categoryMoveDown => 'Descendre';

  @override
  String get categoryAddRule => 'Ajouter une règle';

  @override
  String categoryMoveTitle(String name) {
    return 'Déplacer « $name » vers';
  }

  @override
  String categoryTopLevel(String nature) {
    return 'Premier niveau, $nature';
  }

  @override
  String categoryDeleteConfirm(String name) {
    return 'Supprimer la catégorie « $name » ?';
  }

  @override
  String categoryDeleteWithRules(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'ses $count règles', one: 'sa règle');
    return 'Supprimer la catégorie « $name » et $_temp0 ?';
  }

  @override
  String get categoryDeleted => 'Catégorie supprimée.';

  @override
  String get categoriesToReplace => 'À replacer';

  @override
  String get categoriesToReplaceHint =>
      'Ces catégories ne sont plus rattachées à l\'arbre, souvent après des modifications faites en même temps sur deux appareils. Déplacez-les pour les replacer ; leurs sous-catégories suivent.';

  @override
  String get detachedLoop => 'Placée sous une de ses propres sous-catégories';

  @override
  String get detachedMissingParent => 'Sa catégorie parente a été supprimée';

  @override
  String get detachedParentInOtherYear => 'Sa catégorie parente appartient à une autre année';

  @override
  String get detachedGroupWithoutNature => 'Groupe sans nature (revenus ou dépenses)';

  @override
  String get detachedAncestor => 'Sous une catégorie à replacer';

  @override
  String get natureIncome => 'revenus';

  @override
  String get natureExpense => 'dépenses';

  @override
  String get errorUnknownCategory => 'Cette catégorie n\'existe plus.';

  @override
  String get errorCategoryNameTaken =>
      'Ce nom est déjà utilisé dans l\'arbre de cette année (majuscules, accents et espaces autour ne comptent pas).';

  @override
  String get errorNatureRequired => 'Choisissez la nature du groupe : revenus ou dépenses.';

  @override
  String get errorTreeExists => 'L\'arbre de cette année existe déjà.';

  @override
  String get errorNoTree => 'Cette année n\'a pas encore d\'arbre.';

  @override
  String get errorCategoryLoop =>
      'Une catégorie ne peut pas être placée sous elle-même ni sous une de ses sous-catégories.';

  @override
  String errorParentHasTransactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions sont classées',
      one: 'une transaction est classée',
    );
    return 'Impossible : $_temp0 dans cette catégorie. Seule une catégorie sans transaction peut recevoir des sous-catégories.';
  }

  @override
  String get errorCategoryHasChildren => 'Supprimez ou déplacez d\'abord ses sous-catégories.';

  @override
  String errorCategoryInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions utilisent',
      one: 'une transaction utilise',
    );
    return 'Suppression refusée : $_temp0 cette catégorie.';
  }

  @override
  String get errorUnknownTransaction => 'Cette transaction n\'existe plus.';

  @override
  String get errorAmountRequired => 'Saisissez un montant supérieur à zéro.';

  @override
  String get errorArchivedAccount => 'Ce compte est archivé.';

  @override
  String get errorDetailedAccountManual =>
      'Le compte détaillé ne reçoit que les transactions de ses relevés : pas de saisie manuelle.';

  @override
  String get errorDebtsAccountManual => 'Un compte de dettes ne se modifie que par le tableau des dettes.';

  @override
  String get errorCategoryNotAssignable =>
      'Choisissez une catégorie sans sous-catégorie, dans l\'arbre de l\'année du paiement.';

  @override
  String get errorPeriodInvalid => 'La fin de la période précède son début.';

  @override
  String get errorSplitLineAmountInvalid => 'Chaque ligne de la ventilation doit avoir un montant supérieur à zéro.';

  @override
  String get errorSplitSumMismatch =>
      'Les lignes de la ventilation doivent faire ensemble le montant de la transaction.';

  @override
  String get errorSplitRefund => 'Un remboursement rattaché à une dépense ne se ventile pas.';

  @override
  String get splitAction => 'Ventiler';

  @override
  String get splitTitle => 'Ventilation';

  @override
  String get splitHint =>
      'Chaque ligne a sa catégorie, son montant et sa période ; la première reçoit le reste du montant.';

  @override
  String get splitRest => 'Reste';

  @override
  String get splitAddLine => 'Ajouter une ligne';

  @override
  String get splitRemoveLine => 'Retirer la ligne';

  @override
  String get splitOverTotal => 'Les autres lignes dépassent le montant de la transaction.';

  @override
  String get errorSameAccount => 'Choisissez deux comptes différents.';

  @override
  String get errorAccountNotDetailed =>
      'Ce compte n\'est pas détaillé : activez l\'import du compte pour y importer ses relevés.';

  @override
  String get errorStatementOtherFormat => 'Ce relevé n\'est pas au format d\'import de ce compte.';

  @override
  String get errorStatementAlreadyImported => 'Ce relevé est déjà importé.';

  @override
  String errorStatementOtherAccount(String found, String expected) {
    return 'Ce relevé est celui d\'un autre compte : IBAN $found, alors que les relevés précédents portent l\'IBAN $expected.';
  }

  @override
  String errorStatementNotContiguous(
    String foundStart,
    String foundOpening,
    String expectedStart,
    String expectedOpening,
  ) {
    return 'Ce relevé ne suit pas le précédent : il commence le $foundStart avec un solde de $foundOpening, alors que le suivant doit commencer le $expectedStart avec un solde de $expectedOpening.';
  }

  @override
  String get errorStatementSumMismatch =>
      'Les lignes du relevé ne donnent pas l\'écart entre ses soldes initial et final.';

  @override
  String get errorStatementTooLarge => 'Ce relevé compte trop de lignes pour être importé en une fois.';

  @override
  String get errorStatementNotLast => 'Seul le dernier relevé du compte peut être supprimé.';

  @override
  String get errorStatementNoNewLines => 'Cet export n\'apporte aucune nouvelle ligne : toutes sont déjà importées.';

  @override
  String errorStatementLinesBeforeFirst(String found, String expected) {
    return 'Cet export a des lignes du $found, avant le premier import de ce compte, qui commence le $expected : exportez à partir du $expected.';
  }

  @override
  String get errorStatementImportedToday =>
      'Un export de ce compte a déjà été importé aujourd\'hui : importez le suivant demain, ou supprimez le dernier import pour le remplacer.';

  @override
  String get errorStatementBalanceRequired => 'Saisissez le solde du compte pour importer cet export.';

  @override
  String errorStatementBalanceMismatch(String found, int count, String expected) {
    return 'Le solde saisi, $found, ne correspond pas : le solde du dernier import plus les nouvelles lignes ($count) donne $expected. Exportez jusqu\'à aujourd\'hui, sans paiement en attente, et saisissez le solde affiché à ce moment.';
  }

  @override
  String get errorUnknownStatement => 'Ce relevé n\'existe plus.';

  @override
  String get errorImportedTransaction =>
      'Une ligne importée garde le montant, la date, le compte et le texte de la banque ; seules sa catégorie, sa période, sa description et sa note se modifient.';

  @override
  String get errorUnknownRule => 'Cette règle n\'existe plus.';

  @override
  String get errorRuleKeywordsRequired => 'Indiquez au moins une ligne.';

  @override
  String get errorRuleKeywordInvalid => 'Expression régulière invalide : corrigez le terme qui commence par « re: ».';

  @override
  String get errorRuleTargetRequired => 'Choisissez une catégorie ou un compte de transfert.';

  @override
  String get errorUnknownRedistribution => 'Cette règle de redistribution n\'existe plus.';

  @override
  String get errorRedistributionSameCategory => 'La source et la cible doivent être deux catégories différentes.';

  @override
  String get errorRedistributionNotLeaf =>
      'La source et la cible doivent être des catégories sans sous-catégorie de l\'année.';

  @override
  String get errorRedistributionNatureMismatch => 'La source et la cible doivent être deux dépenses ou deux revenus.';

  @override
  String get errorRedistributionPercentInvalid =>
      'Indiquez un pourcentage entre 0.01 et 100, avec deux décimales au plus.';

  @override
  String get errorRedistributionAmountInvalid => 'Indiquez un montant fixe supérieur à zéro.';

  @override
  String get errorRedistributionPercentOrAmount => 'Indiquez soit un pourcentage, soit un montant fixe.';

  @override
  String get errorRedistributionDuplicate => 'Une règle va déjà de cette source vers cette cible : modifiez-la.';

  @override
  String get errorRedistributionTargetIsSource =>
      'Cette cible est déjà la source d\'une autre règle : une cible ne peut pas être une source.';

  @override
  String get errorRedistributionSourceIsTarget =>
      'Cette source est déjà la cible d\'une autre règle : une cible ne peut pas être une source.';

  @override
  String errorRedistributionOverHundred(String total) {
    return 'Les règles de cette source totaliseraient $total : 100 % au plus.';
  }

  @override
  String errorCategoryUsedByRedistributions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles de redistribution utilisent',
      one: 'une règle de redistribution utilise',
    );
    return 'Suppression refusée : $_temp0 cette catégorie.';
  }

  @override
  String get errorRefundNotInflow => 'Seule une entrée d\'argent peut rembourser une dépense.';

  @override
  String get errorRefundIsTransfer => 'Un transfert ne peut pas rembourser une dépense.';

  @override
  String get errorRefundTargetNotExpense => 'Un remboursement se rattache à une dépense validée.';

  @override
  String get errorShareNatureMismatch =>
      'Choisissez une catégorie de même nature que celle d\'origine : une dépense reste une dépense.';

  @override
  String get edit => 'Modifier';

  @override
  String get transactionsEmpty => 'Aucune transaction.';

  @override
  String get transactionsAllAccounts => 'Tous les comptes';

  @override
  String get transactionsAllYears => 'Toutes les années';

  @override
  String get transactionNew => 'Nouvelle transaction';

  @override
  String get transactionNewEntry => 'Dépense ou revenu';

  @override
  String get transactionNewTransfer => 'Transfert';

  @override
  String get entryNewTitle => 'Dépense ou revenu';

  @override
  String get entryEditTitle => 'Modifier la transaction';

  @override
  String get transferNewTitle => 'Nouveau transfert';

  @override
  String get transferEditTitle => 'Modifier le transfert';

  @override
  String get fieldAmount => 'Montant';

  @override
  String get fieldDate => 'Date (jj.mm.aaaa)';

  @override
  String get fieldAccount => 'Compte';

  @override
  String get fieldCategory => 'Catégorie';

  @override
  String get fieldDescription => 'Description';

  @override
  String get fieldNote => 'Note';

  @override
  String get fieldRawText => 'Texte de la banque';

  @override
  String get fieldFrom => 'Compte de départ';

  @override
  String get fieldTo => 'Compte d\'arrivée';

  @override
  String get pickDate => 'Choisir la date';

  @override
  String get directionInflow => 'Entrée';

  @override
  String get directionOutflow => 'Sortie';

  @override
  String get periodCustom => 'Période différente du paiement';

  @override
  String get periodCustomHint => 'Par exemple une assurance payée pour douze mois.';

  @override
  String get periodStart => 'Début de la période';

  @override
  String get periodEnd => 'Fin de la période';

  @override
  String get errorAmountInvalid => 'Montant invalide : saisissez par exemple 45.90, sans signe.';

  @override
  String get errorDateInvalid => 'Date invalide : saisissez par exemple 31.12.2026.';

  @override
  String get errorAccountMissing => 'Choisissez un compte.';

  @override
  String get errorCategoryMissing => 'Choisissez une catégorie.';

  @override
  String get entryNoAccount => 'Aucun compte n\'accepte la saisie manuelle. Créez-en un dans Plus › Comptes.';

  @override
  String entryNoCategory(int year) {
    return 'Aucune catégorie disponible en $year. Ajoutez-en dans Plus › Catégories.';
  }

  @override
  String get kindExpense => 'Dépense';

  @override
  String get kindRefund => 'Remboursement';

  @override
  String get kindIncome => 'Revenu';

  @override
  String get kindTransfer => 'Transfert';

  @override
  String get kindUnclassified => 'Non classé';

  @override
  String transferAccounts(String from, String to) {
    return '$from → $to';
  }

  @override
  String get detailTitle => 'Transaction';

  @override
  String get detailType => 'Type';

  @override
  String get detailPeriod => 'Période';

  @override
  String get detailShares => 'Parts par mois';

  @override
  String get detailYearTotals => 'Total par année';

  @override
  String get transactionDeleteConfirm => 'Supprimer cette transaction ?';

  @override
  String get transactionDeleted => 'Transaction supprimée.';

  @override
  String get syncTitle => 'Synchronisation';

  @override
  String get syncNotPaired => 'Cet appareil n\'est associé à aucun serveur : ses données restent sur lui seul.';

  @override
  String get syncPairAction => 'Associer un serveur';

  @override
  String get syncNever => 'Jamais synchronisé';

  @override
  String get syncRunning => 'Synchronisation en cours…';

  @override
  String get syncUpToDate => 'À jour';

  @override
  String get syncOffline => 'Hors ligne';

  @override
  String get syncOfflineHint =>
      'Le serveur est injoignable. Les modifications partiront à la prochaine synchronisation.';

  @override
  String get syncRevoked => 'Appareil révoqué';

  @override
  String get syncRevokedHint =>
      'Le serveur a révoqué cet appareil : la synchronisation est arrêtée. Ses données restent sur cet appareil. Pour reprendre, oubliez ce serveur dans Plus › Serveur, puis associez l\'appareil à nouveau : ses modifications non envoyées partiront au premier échange.';

  @override
  String get syncIncompatible => 'Versions incompatibles';

  @override
  String syncAppTooOld(String version) {
    return 'Synchronisation refusée : cette version de l\'app est trop ancienne pour le serveur, qui demande au moins la version $version. Mettez l\'app à jour.';
  }

  @override
  String syncServerTooOld(String version) {
    return 'Synchronisation refusée : le serveur (version $version) est trop ancien pour cette version de l\'app. Mettez le serveur à jour.';
  }

  @override
  String get syncError => 'Erreur de synchronisation';

  @override
  String syncErrorHint(String detail) {
    return 'La dernière synchronisation a échoué : $detail';
  }

  @override
  String syncLast(String date, String time) {
    return 'Dernière synchronisation : $date à $time';
  }

  @override
  String syncPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifications en attente',
      one: 'Une modification en attente',
      zero: 'Aucune modification en attente',
    );
    return '$_temp0';
  }

  @override
  String get syncNow => 'Synchroniser';

  @override
  String syncClockWarning(int minutes) {
    return 'L\'horloge de cet appareil s\'écarte de $minutes minutes de celle du serveur. Corrigez-la : l\'ordre des modifications faites sur plusieurs appareils en dépend.';
  }

  @override
  String get syncDecision => 'Premier échange avec le serveur';

  @override
  String get syncDecisionHint =>
      'Cet appareil et le serveur ont chacun des données, sans rien en commun : elles viennent d\'appareils utilisés séparément. Fusionner réunit les deux ; des doublons peuvent apparaître, ils seront signalés dans les tâches. Remplacer efface les données de cet appareil et reprend celles du serveur.';

  @override
  String get syncMerge => 'Fusionner';

  @override
  String get syncReplace => 'Remplacer celles de l\'appareil';

  @override
  String get syncReplaceAction => 'Remplacer les données de cet appareil par celles du serveur';

  @override
  String get syncReplaceConfirm =>
      'Remplacer les données de cet appareil par celles du serveur ? Tout ce que cet appareil n\'a pas encore envoyé au serveur sera définitivement perdu.';

  @override
  String get syncReplaceDone => 'Les données de cet appareil sont maintenant celles du serveur.';

  @override
  String get syncServerChanged => 'Le serveur a changé';

  @override
  String get syncServerChangedHint =>
      'Le serveur présente un autre certificat ou ne connaît plus cet appareil : il a sans doute été réinstallé. Associez cet appareil de nouveau : ses données, modifications non envoyées comprises, y seront recopiées.';

  @override
  String get syncPairAgain => 'Associer de nouveau';

  @override
  String get serverErrorUnknownDevice =>
      'Le serveur ne connaît pas cet appareil : il a sans doute été réinstallé. Oubliez ce serveur puis associez l\'appareil à nouveau.';

  @override
  String get tasksTitle => 'À faire';

  @override
  String get tasksNone => 'Rien à faire pour l\'instant.';

  @override
  String taskDuplicateName(int count, String name, int year) {
    return '$count catégories « $name » en $year';
  }

  @override
  String get taskDuplicateNameHint =>
      'Un nom n\'apparaît qu\'une fois dans l\'arbre d\'une année : renommez ou supprimez l\'une d\'elles.';

  @override
  String taskDetached(int count, int year) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count catégories à replacer',
      one: 'Une catégorie à replacer',
    );
    return '$_temp0 en $year';
  }

  @override
  String get taskDetachedHint => 'Elles ne sont plus rattachées à l\'arbre de l\'année : déplacez-les.';

  @override
  String get categoryDuplicateName => 'Nom en double dans cette année';

  @override
  String get importTitle => 'Importer un relevé';

  @override
  String get importSyncing => 'Synchronisation avant l\'import…';

  @override
  String importNotReady(String reason) {
    return 'L\'import commence par une synchronisation aboutie. Elle n\'a pas abouti : $reason';
  }

  @override
  String get importRetry => 'Réessayer';

  @override
  String get importNoDetailedAccount => 'Aucun compte détaillé : activez l\'import d\'un compte dans Plus › Comptes.';

  @override
  String get importAccount => 'Compte';

  @override
  String get importChoose => 'Choisir le relevé PDF ou l\'export CSV';

  @override
  String get importSending => 'Le serveur lit et vérifie le relevé…';

  @override
  String get importRefusedTitle => 'Relevé refusé';

  @override
  String get importDoneTitle => 'Relevé importé';

  @override
  String importDonePeriod(String start, String end) {
    return 'Du $start au $end';
  }

  @override
  String importDoneLines(int lines, int proposed, int toComplete) {
    String _temp0 = intl.Intl.pluralLogic(lines, locale: localeName, other: '$lines lignes', one: 'Une ligne');
    String _temp1 = intl.Intl.pluralLogic(
      proposed,
      locale: localeName,
      other: 'proposées',
      one: 'proposée',
      zero: 'proposée',
    );
    return '$_temp0 : $proposed $_temp1, $toComplete à compléter.';
  }

  @override
  String get importStatements => 'Relevés du compte';

  @override
  String get importFirstTitle => 'Premier relevé de ce compte';

  @override
  String importFirstBody(String balance, String date) {
    return 'Ce relevé fixe le solde de départ du compte : $balance au $date. Aucun relevé antérieur ne pourra être importé ensuite.';
  }

  @override
  String get importFirstConfirm => 'Importer';

  @override
  String get importBalanceTitle => 'Solde du compte';

  @override
  String importBalanceLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouvelles lignes.',
      one: 'Une nouvelle ligne.',
    );
    return '$_temp0';
  }

  @override
  String get importBalanceFirstHint =>
      'Premier import de ce compte : saisissez le solde affiché maintenant par la banque. Il fixe le solde de départ du compte ; aucune ligne antérieure ne pourra être importée ensuite.';

  @override
  String get importBalanceNextHint =>
      'Saisissez le solde affiché maintenant par la banque : il doit être celui du dernier import plus ces lignes, sinon rien n\'est importé.';

  @override
  String get importBalanceField => 'Solde actuel';

  @override
  String get importBalanceInvalid => 'Montant invalide : saisissez par exemple 1234.50.';

  @override
  String get importUnreadable => 'Ce fichier n\'est pas un PDF lisible.';

  @override
  String get importUnknownFormat => 'Ce fichier n\'est ni un relevé PDF PostFinance ni un export CSV Neon.';

  @override
  String importInconsistent(String reason) {
    return 'Relevé incohérent, rien n\'est importé : $reason.';
  }

  @override
  String get importCheckLayout => 'il n\'a pas pu être lu en entier';

  @override
  String get importCheckCurrency => 'le compte n\'est pas en francs suisses';

  @override
  String get importCheckPeriod => 'une ligne est hors de la période du relevé, ou dans le désordre';

  @override
  String get importCheckRunningBalance =>
      'un solde imprimé en cours de relevé ne correspond pas aux mouvements qui le précèdent';

  @override
  String get importCheckTotals => 'les totaux imprimés des crédits ou des débits ne correspondent pas aux mouvements';

  @override
  String get importCheckClosingBalance => 'le solde final ne correspond pas au solde initial plus les mouvements';

  @override
  String get importTooLarge => 'Ce fichier dépasse 10 Mo.';

  @override
  String importServerRefused(String code) {
    return 'Le serveur refuse l\'envoi ($code).';
  }

  @override
  String importServerTooOld(String version) {
    return 'Le serveur (version $version) est trop ancien pour importer des relevés : installez la version 0.4.0 ou une suivante.';
  }

  @override
  String get importUnreachable => 'Le serveur ne répond plus : le relevé n\'a pas été envoyé.';

  @override
  String statementsTitle(String account) {
    return 'Relevés de $account';
  }

  @override
  String get statementsEmpty => 'Aucun relevé importé.';

  @override
  String statementPeriod(String start, String end) {
    return '$start – $end';
  }

  @override
  String statementSummary(String opening, String closing, int lines) {
    String _temp0 = intl.Intl.pluralLogic(lines, locale: localeName, other: '$lines lignes', one: 'une ligne');
    return 'Solde initial $opening · final $closing · $_temp0';
  }

  @override
  String get statementSavePdf => 'Enregistrer le fichier d\'origine';

  @override
  String get statementPdfSaved => 'Fichier enregistré.';

  @override
  String get statementPdfMissing =>
      'Le serveur n\'a plus ce fichier : il a sans doute été reconstruit depuis l\'import.';

  @override
  String get statementPdfNotPaired => 'Associez un serveur pour récupérer le fichier d\'origine.';

  @override
  String get statementPdfUnreachable => 'Le serveur ne répond pas : le fichier n\'a pas pu être récupéré.';

  @override
  String get statementDeleteLast => 'Supprimer le dernier relevé';

  @override
  String statementDeleteConfirm(String start, String end, int lines) {
    return 'Supprimer le relevé du $start au $end et ses $lines lignes ? Leurs classements sont perdus ; le relevé pourra être importé de nouveau.';
  }

  @override
  String get statementDeleted => 'Relevé supprimé.';

  @override
  String get accountStatements => 'Relevés importés';

  @override
  String get validationTitle => 'Validation';

  @override
  String validationToCompleteTab(int count) {
    return 'À compléter ($count)';
  }

  @override
  String validationProposedTab(int count) {
    return 'Proposées ($count)';
  }

  @override
  String get validationNothingToComplete => 'Aucune ligne à compléter.';

  @override
  String get validationNothingProposed => 'Aucune proposition à confirmer.';

  @override
  String validationConfirm(int count) {
    return 'Confirmer les propositions ($count)';
  }

  @override
  String get monthlyTitle => 'Suivi mensuel';

  @override
  String get monthlyMonthNames =>
      'janvier,février,mars,avril,mai,juin,juillet,août,septembre,octobre,novembre,décembre';

  @override
  String get monthlyEdit => 'Modifier les tâches';

  @override
  String get monthlyEmpty =>
      'Aucune tâche mensuelle : définissez ce que vous faites chaque mois (importer les relevés, saisir les espèces, mettre à jour les dettes…).';

  @override
  String get monthlySuggest => 'Proposer une liste';

  @override
  String monthlySuggestImport(String account) {
    return 'Importer $account';
  }

  @override
  String get monthlySuggestCash => 'Saisir les transactions en espèces';

  @override
  String get monthlySuggestDebts => 'Mettre à jour les dettes';

  @override
  String monthlyProgress(int done, int total) {
    return '$done sur $total';
  }

  @override
  String get monthlyComplete => 'Terminé';

  @override
  String monthlyCurrent(String month) {
    return '$month, en cours';
  }

  @override
  String monthlyImported(String date) {
    return 'Importé jusqu\'au $date';
  }

  @override
  String get monthlyNotImported => 'Pas encore importé';

  @override
  String get monthlyAll => 'Tous les mois';

  @override
  String get monthlyTaskNew => 'Nouvelle tâche';

  @override
  String get monthlyTaskEdit => 'Modifier la tâche';

  @override
  String get monthlyTaskName => 'Tâche';

  @override
  String get monthlyTaskAccount => 'Cochée par';

  @override
  String get monthlyTaskByHand => 'Moi, à la main';

  @override
  String monthlyTaskByImports(String account) {
    return 'Les imports de $account';
  }

  @override
  String get monthlyTaskAccountHint =>
      'Cochée seule pour un mois dès que les imports de ce compte couvrent son dernier jour.';

  @override
  String get monthlyTaskSince => 'Depuis';

  @override
  String get monthlyTaskSinceMonth => 'Mois';

  @override
  String get monthlyTaskSinceYear => 'Année';

  @override
  String monthlyTaskSummary(String month, String by) {
    return 'Depuis $month · $by';
  }

  @override
  String monthlyTaskDeleteConfirm(String name) {
    return 'Supprimer la tâche « $name » et ses coches ?';
  }

  @override
  String get monthlyTaskDeleted => 'Tâche supprimée.';

  @override
  String get errorUnknownMonthlyTask => 'Cette tâche n\'existe plus.';

  @override
  String get errorMonthlyTaskAccountNotDetailed => 'Seuls les imports d\'un compte détaillé peuvent cocher une tâche.';

  @override
  String get validationConfirmOne => 'Valider cette proposition';

  @override
  String validationPaired(String date, String account) {
    return 'Autre côté du transfert du $date sur $account';
  }

  @override
  String get pairedTitle => 'Autre côté du transfert';

  @override
  String pairedMissing(String account, int days) {
    return 'Autre côté introuvable sur $account : même montant, de signe opposé, à $days jours au plus.';
  }

  @override
  String get unpairedTitle => 'Transferts sans autre côté';

  @override
  String unpairedHint(int days) {
    return 'Un transfert entre deux comptes importés figure sur les deux relevés : même montant, de signe opposé, à $days jours au plus. Ceux-ci n\'ont pas leur ligne sur l\'autre compte : importez son relevé, ou corrigez leur classification.';
  }

  @override
  String get unpairedEmpty => 'Aucun transfert sans son autre côté.';

  @override
  String taskUnpairedTransfers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transferts entre comptes importés sans leur autre côté',
      one: 'Un transfert entre comptes importés sans son autre côté',
    );
    return '$_temp0';
  }

  @override
  String get taskUnpairedTransfersHint =>
      'L\'autre compte n\'a pas la ligne correspondante : importez son relevé, ou corrigez la classification.';

  @override
  String validationConfirmed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes validées',
      one: 'Une ligne validée',
    );
    return '$_temp0.';
  }

  @override
  String validationConflict(String rules) {
    return 'Règles en concurrence : $rules';
  }

  @override
  String validationUnusable(String keywords) {
    return 'La règle « $keywords » vise une cible inutilisable.';
  }

  @override
  String validationRule(String keywords) {
    return 'Règle « $keywords »';
  }

  @override
  String validationTransferWith(String account) {
    return 'Transfert avec $account';
  }

  @override
  String get validationAction => 'Valider les lignes';

  @override
  String get classifyTitle => 'Classer la ligne';

  @override
  String get classifyCategory => 'Catégorie';

  @override
  String get classifyTransfer => 'Transfert';

  @override
  String get classifyCounterpart => 'Compte de contrepartie';

  @override
  String get classifyTransferOut => 'L\'argent part vers ce compte.';

  @override
  String get classifyTransferIn => 'L\'argent vient de ce compte.';

  @override
  String get classifyValidate => 'Valider';

  @override
  String get classifyValidated => 'Ligne validée.';

  @override
  String get classifyCreateRule => 'Créer une règle';

  @override
  String get classifyChooseCategory => 'Choisissez une catégorie.';

  @override
  String get classifyChooseAccount => 'Choisissez un compte.';

  @override
  String get ruleNew => 'Nouvelle règle';

  @override
  String get ruleEdit => 'Modifier la règle';

  @override
  String ruleFor(String target) {
    return 'Classe dans « $target »';
  }

  @override
  String get rulesOr => ' OU ';

  @override
  String get rulesHelp => 'Aide sur les règles';

  @override
  String get rulesHelpTitle => 'Règles de classement';

  @override
  String get rulesHelpBody =>
      'Une règle classe les lignes importées encore à valider dans sa catégorie, ou comme transfert vers un compte. Elle lit le texte de la banque, jamais la description.\n\nChaque ligne de la règle est une possibilité : la règle s\'applique dès qu\'une de ses lignes est trouvée dans le texte (OU).\n\nPour exiger plusieurs termes qui ne se suivent pas, joignez-les par ET en majuscules : « coop ET pronto » demande « coop » et « pronto », n\'importe où dans le texte. Sans ET, la ligne est cherchée telle quelle, mots collés.\n\nLes majuscules, les accents et les espaces répétés ne comptent pas. « re: » au début d\'un terme en fait une expression régulière, par exemple « re:migros|coop ».\n\nQuand plusieurs règles s\'appliquent, celle dont la ligne trouvée a le plus de termes gagne. À égalité entre deux cibles, la ligne reste « à compléter ».\n\nLa période proposée est toujours la date du paiement. Une règle créée, modifiée ou supprimée ne change que les lignes encore à valider.';

  @override
  String get ruleKeywords => 'Lignes de la règle';

  @override
  String get ruleKeywordsHint =>
      'Une ligne trouvée suffit. « ET » en majuscules entre deux termes : les deux sont requis, n\'importe où dans le texte.';

  @override
  String ruleKeywordInvalid(String keyword) {
    return 'Expression régulière invalide : $keyword';
  }

  @override
  String get ruleTarget => 'Cible';

  @override
  String ruleMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes non validées',
      one: 'une ligne non validée',
      zero: 'aucune ligne non validée',
    );
    return 'Cette règle classerait $_temp0.';
  }

  @override
  String get ruleSaved => 'Règle enregistrée.';

  @override
  String get ruleDeleted => 'Règle supprimée.';

  @override
  String get ruleDeleteConfirm => 'Supprimer cette règle ? Les lignes déjà validées ne changent pas.';

  @override
  String get ruleUnusable => 'Cible inutilisable : cette règle ne propose rien.';

  @override
  String ruleSummary(String keywords, String target) {
    return '$keywords → $target';
  }

  @override
  String taskLinesToValidate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes à valider',
      one: 'Une ligne à valider',
    );
    return '$_temp0';
  }

  @override
  String get taskLinesToValidateHint => 'Lignes importées : complétez-les ou confirmez les propositions.';

  @override
  String taskConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes dont les règles sont en concurrence',
      one: 'Une ligne dont les règles sont en concurrence',
    );
    return '$_temp0';
  }

  @override
  String get taskConflictsHint => 'Classez-les à la main ou ajustez les règles.';

  @override
  String taskUnusableRules(int count, int year) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles de $year ne proposent plus rien',
      one: 'Une règle de $year ne propose plus rien',
    );
    return '$_temp0';
  }

  @override
  String get taskUnusableRulesHint => 'Leur catégorie ou leur compte n\'est plus utilisable : modifiez-les.';

  @override
  String get transactionsSearch => 'Rechercher';

  @override
  String get transactionsAllMonths => 'Tous les mois';

  @override
  String get transactionsAllCategories => 'Toutes les catégories';

  @override
  String get transactionsUnclassified => 'Non classé';

  @override
  String get transactionsAllStatuses => 'Tous les statuts';

  @override
  String get statusToValidate => 'À valider';

  @override
  String get statusToComplete => 'À compléter';

  @override
  String get statusProposed => 'Proposée';

  @override
  String get statusValidated => 'Validée';

  @override
  String get yearViewCash => 'Trésorerie';

  @override
  String get yearViewEconomic => 'Économique';

  @override
  String get yearPick => 'Année affichée';

  @override
  String get yearIncome => 'Revenus';

  @override
  String get yearExpenses => 'Dépenses';

  @override
  String get yearSavings => 'Épargne';

  @override
  String get yearUnclassified => 'Non classé';

  @override
  String get yearToClassify => 'À classer';

  @override
  String yearToClassifyNature(String nature) {
    return 'À classer · $nature';
  }

  @override
  String get yearOffsets => 'Décalages de période';

  @override
  String yearPaidForOtherYears(String year) {
    return 'Payé en $year pour d\'autres années';
  }

  @override
  String yearPaidInOtherYears(String year) {
    return 'Payé d\'autres années pour $year';
  }

  @override
  String yearToValidate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes à valider comptent',
      one: 'Une ligne à valider compte',
    );
    return '$_temp0 comme ses règles le proposent.';
  }

  @override
  String yearPreview(String year) {
    return '$year n\'a pas encore d\'arbre : il s\'affiche avec celui que sa copie lui donnera.';
  }

  @override
  String get yearNone => 'Aucune année à afficher : la première transaction d\'une année crée son arbre.';

  @override
  String get yearTotal => 'Total';

  @override
  String get yearMonths => 'janv.,févr.,mars,avr.,mai,juin,juil.,août,sept.,oct.,nov.,déc.';

  @override
  String get yearMonthDetail => 'Détail par mois';

  @override
  String get yearCostsHint => 'Les dépenses s\'affichent comme des coûts ; un remboursement les diminue.';

  @override
  String yearRedistributionTo(String name, String percent) {
    return 'Vers $name · $percent';
  }

  @override
  String yearRedistributionFrom(String name, String percent) {
    return 'Depuis $name · $percent';
  }

  @override
  String get compositionEmpty => 'Aucune transaction dans ce montant.';

  @override
  String get compositionTotal => 'Total';

  @override
  String compositionPeriod(String month, String year) {
    return '$month $year';
  }

  @override
  String keyFiguresTitle(String year) {
    return 'Chiffres clés $year';
  }

  @override
  String get keyFiguresHint => 'Vue économique : ce que l\'année coûte.';

  @override
  String get keyFiguresOpen => 'Voir l\'année';

  @override
  String get redistributionMenu => 'Redistribution';

  @override
  String redistributionTitle(String year) {
    return 'Redistribution $year';
  }

  @override
  String get redistributionExplain =>
      'Un pourcentage : chaque mois, cette part du montant de la source passe dans la cible. Un montant fixe : il est retiré de chaque paiement de la source, par exemple les charges et la place de parc comprises dans le loyer. Une ligne distincte de chaque côté, dans les deux vues.';

  @override
  String get redistributionEmpty => 'Aucune règle de redistribution cette année.';

  @override
  String get redistributionNoTree => 'Cette année n\'a pas encore d\'arbre.';

  @override
  String get redistributionNew => 'Nouvelle règle';

  @override
  String get redistributionEdit => 'Modifier la règle';

  @override
  String get redistributionSource => 'Source';

  @override
  String get redistributionTarget => 'Cible';

  @override
  String get redistributionPercent => 'Pourcentage';

  @override
  String get redistributionPercentHint => 'De 0.01 à 100, deux décimales au plus.';

  @override
  String get redistributionFixed => 'Montant fixe';

  @override
  String get redistributionAmount => 'Montant par paiement';

  @override
  String get redistributionAmountHint =>
      'Retiré de chaque paiement de la source, au plus le paiement. Les remboursements ne sont pas touchés ; un pourcentage s\'applique à ce qui reste.';

  @override
  String redistributionPerPayment(String amount) {
    return '$amount par paiement';
  }

  @override
  String redistributionRule(String source, String target) {
    return 'De $source vers $target';
  }

  @override
  String get redistributionSaved => 'Règle enregistrée.';

  @override
  String get redistributionDeleted => 'Règle supprimée.';

  @override
  String get redistributionDeleteConfirm => 'Supprimer cette règle de redistribution ?';

  @override
  String get redistributionChooseSource => 'Choisissez la source.';

  @override
  String get redistributionChooseTarget => 'Choisissez la cible.';

  @override
  String get redistributionProblemSourceMissing =>
      'Ne s\'applique pas : la source n\'est plus dans l\'arbre de l\'année.';

  @override
  String get redistributionProblemTargetMissing =>
      'Ne s\'applique pas : la cible n\'est plus dans l\'arbre de l\'année.';

  @override
  String get redistributionProblemSourceNotLeaf => 'Ne s\'applique pas : la source a des sous-catégories.';

  @override
  String get redistributionProblemTargetNotLeaf => 'Ne s\'applique pas : la cible a des sous-catégories.';

  @override
  String get redistributionProblemSameCategory => 'Ne s\'applique pas : la source et la cible sont la même catégorie.';

  @override
  String get redistributionProblemNatureMismatch =>
      'Ne s\'applique pas : la source et la cible ne sont pas de même nature.';

  @override
  String get redistributionProblemPercentInvalid => 'Ne s\'applique pas : le pourcentage n\'est pas entre 0.01 et 100.';

  @override
  String get redistributionProblemAmountInvalid => 'Ne s\'applique pas : le montant fixe n\'est pas supérieur à zéro.';

  @override
  String get redistributionProblemPercentOrAmount =>
      'Ne s\'applique pas : la règle a à la fois un pourcentage et un montant fixe, ou aucun des deux.';

  @override
  String get redistributionProblemOverHundred => 'Ne s\'applique pas : les règles de cette source dépassent 100 %.';

  @override
  String get redistributionProblemChain => 'Ne s\'applique pas : une cible est aussi la source d\'une règle.';

  @override
  String taskInapplicableRedistributions(int count, String year) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles de redistribution ne s\'appliquent pas',
      one: 'Une règle de redistribution ne s\'applique pas',
    );
    return '$_temp0 en $year';
  }

  @override
  String get taskInapplicableRedistributionsHint => 'Corrigez-les ou supprimez-les.';

  @override
  String taskShares(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parts à classer',
      one: 'Une part à classer',
    );
    return '$_temp0';
  }

  @override
  String get taskSharesHint => 'Des montants reportés sur une autre année n\'y trouvent pas leur catégorie.';

  @override
  String taskBrokenRefunds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count remboursements ont perdu leur dépense',
      one: 'Un remboursement a perdu sa dépense',
    );
    return '$_temp0';
  }

  @override
  String get taskBrokenRefundsHint =>
      'Ils comptent dans leur propre catégorie : détachez-les ou rattachez-les à une autre dépense.';

  @override
  String get classifyRefund => 'Remboursement';

  @override
  String get refundExpense => 'Dépense remboursée';

  @override
  String get refundPick => 'Choisir la dépense';

  @override
  String get refundSearch => 'Texte ou montant de la dépense';

  @override
  String get refundNoExpense => 'Aucune dépense validée trouvée.';

  @override
  String refundSplitOf(String total) {
    return 'ventilée, sur $total';
  }

  @override
  String get refundExpenseMissing => 'Choisissez la dépense remboursée.';

  @override
  String get refundHint => 'Le remboursement prend la catégorie et la période de sa dépense, qui affiche son coût net.';

  @override
  String get refundAttached => 'Remboursement rattaché.';

  @override
  String get refundDetach => 'Détacher';

  @override
  String get refundDetached => 'Remboursement détaché.';

  @override
  String get refundAttach => 'Rattacher à une dépense';

  @override
  String get detailRefunds => 'Remboursements';

  @override
  String get detailNetCost => 'Coût net';

  @override
  String get detailRefundOf => 'Rembourse';

  @override
  String get detailBrokenLink =>
      'La dépense de ce remboursement n\'existe plus ou n\'est plus une dépense validée : il compte dans sa propre catégorie, à sa date.';

  @override
  String get entryRefund => 'Rembourse une dépense';

  @override
  String get brokenRefundsTitle => 'Remboursements sans dépense';

  @override
  String get sharesTitle => 'Parts à classer';

  @override
  String get sharesEmpty => 'Aucune part à classer.';

  @override
  String sharesGroup(String origin, String originYear, String year) {
    return '$origin $originYear, parts de $year';
  }

  @override
  String sharesExplain(String year, String name) {
    return 'L\'arbre de $year n\'a pas de catégorie « $name » qui puisse recevoir ces montants. La réponse est mémorisée pour chaque ligne.';
  }

  @override
  String sharesCategory(String year) {
    return 'Catégorie en $year';
  }

  @override
  String get sharesClassifyGroup => 'Classer le groupe';

  @override
  String get sharesClassified => 'Parts classées.';

  @override
  String get sharesChoose => 'Choisissez une catégorie.';

  @override
  String get sharesLineCategory => 'Pour cette ligne seulement';

  @override
  String yearInapplicable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count règles de redistribution ne s\'appliquent pas',
      one: 'Une règle de redistribution ne s\'applique pas',
    );
    return '$_temp0 cette année.';
  }

  @override
  String get errorUnknownBalance => 'Ce solde n\'existe plus.';

  @override
  String get errorBalanceOnDetailedAccount =>
      'Le solde du compte détaillé vient de ses relevés : il ne se déclare pas.';

  @override
  String get errorBalanceOnDebtsAccount =>
      'Un compte « Dettes » n\'a pas de solde propre : la fortune compte les dettes du tableau des dettes.';

  @override
  String get errorBalanceInFuture => 'Un solde ne se déclare pas pour une date future.';

  @override
  String accountArchivedBalances(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count soldes déclarés l\'utilisent',
      one: 'un solde déclaré l\'utilise',
    );
    return 'Compte archivé et non supprimé : $_temp0. Il reste dans la fortune avec son dernier solde ; déclarez un solde de 0 pour l\'en sortir.';
  }

  @override
  String get errorUnknownDebt => 'Cette dette n\'existe plus.';

  @override
  String get errorDebtPersonRequired => 'Indiquez la personne.';

  @override
  String get errorDebtPercentInvalid => 'Indiquez un pourcentage entre 0.01 et 100, avec deux décimales au plus.';

  @override
  String get errorDebtAlreadyRepaid => 'Cette dette est déjà remboursée.';

  @override
  String get errorDebtTransactionIsTransfer => 'Un transfert ne peut pas être lié à une dette.';

  @override
  String get errorDebtRepaymentDirection =>
      'Une dette qu\'on me doit se rembourse par une entrée d\'argent, une dette que je dois par une sortie.';

  @override
  String get errorDebtReceivedBeforeEvent => 'La date du remboursement ne peut pas précéder la date de l\'événement.';

  @override
  String get errorDebtSplitOutOfTotal =>
      'La première part doit être supérieure à zéro et inférieure au total de la dette.';

  @override
  String get wealthNone =>
      'Aucun solde déclaré ni aucune dette : déclarez le solde d\'un compte pour suivre votre fortune.';

  @override
  String get wealthNet => 'Fortune nette';

  @override
  String wealthSince(String date) {
    return 'Depuis le $date';
  }

  @override
  String wealthAt(String date) {
    return 'au $date';
  }

  @override
  String wealthBalanceDate(String date) {
    return 'Solde du $date';
  }

  @override
  String wealthStatementDate(String date) {
    return 'Relevé au $date';
  }

  @override
  String get wealthOld => 'ancien';

  @override
  String get wealthWithoutBalance => 'Sans solde, hors fortune';

  @override
  String get wealthWithoutBalanceSection => 'Comptes sans solde';

  @override
  String get wealthDeclaredLegend => 'En couleur : les comptes déclarés aux impôts.';

  @override
  String get wealthDebts => 'Dettes';

  @override
  String get wealthDebtsHint => 'Dettes ouvertes : ce qu\'on me doit moins ce que je dois.';

  @override
  String get wealthCurve => 'Évolution';

  @override
  String get wealthCurveHint => 'Fortune à la fin de chaque mois. Touchez la courbe pour lire un mois.';

  @override
  String wealthCurvePoint(String month, String amount) {
    return '$month : $amount';
  }

  @override
  String get wealthExplain => 'Pourquoi la fortune a varié';

  @override
  String wealthExplainPeriod(String start, String end) {
    return 'Du $start au $end';
  }

  @override
  String get wealthNoTree => 'Pas d\'arbre de catégories cette année : seuls les soldes et les dettes y figurent.';

  @override
  String get explainEconomic => 'Résultat économique';

  @override
  String get explainOffsets => '+ Décalages de période';

  @override
  String get explainCash => '= Résultat de trésorerie';

  @override
  String get explainVariations => '+ Variations de valeur';

  @override
  String get explainAdded => '+ Comptes ajoutés';

  @override
  String get explainDebts => '+ Variation des dettes ouvertes';

  @override
  String explainDebtsDetail(String start, String end, String movements) {
    return 'Dettes ouvertes au début $start, à la fin $end ; mouvements des comptes « Dettes » $movements';
  }

  @override
  String get explainUnclassified => '+ Non classé';

  @override
  String get explainOutside => '+ Hors fortune';

  @override
  String get explainOutsideHint => 'Mouvements de comptes qui n\'avaient pas encore de solde, ou qui n\'existent plus.';

  @override
  String get explainChange => '= Variation de la fortune';

  @override
  String get explainDeletedAccount => 'Compte supprimé';

  @override
  String get accountBalanceNow => 'Solde';

  @override
  String get accountDeclare => 'Déclarer un solde';

  @override
  String get accountDeclareAmount => 'Solde (négatif pour un prêt)';

  @override
  String get accountDeclareDate => 'Date du solde';

  @override
  String get accountBalanceEdit => 'Modifier le solde';

  @override
  String accountBalanceDeleteConfirm(String date) {
    return 'Supprimer le solde du $date ?';
  }

  @override
  String get accountBalanceDeleted => 'Solde supprimé.';

  @override
  String get accountBalanceInvalid => 'Saisissez un montant et une date valides.';

  @override
  String accountVariationResult(String amount) {
    return 'Variation de valeur : $amount';
  }

  @override
  String accountEntersWealth(String amount) {
    return 'Le compte entre dans la fortune avec $amount.';
  }

  @override
  String get accountHistory => 'Historique des soldes';

  @override
  String accountExpected(String amount) {
    return 'Attendu $amount';
  }

  @override
  String accountVariation(String amount) {
    return 'Variation $amount';
  }

  @override
  String get accountFirstBalance => 'Premier solde : le compte entre dans la fortune.';

  @override
  String get accountStatementPoint => 'Solde initial du premier relevé';

  @override
  String accountMovementsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mouvements',
      one: 'Un mouvement',
      zero: 'Aucun mouvement',
    );
    return '$_temp0';
  }

  @override
  String get accountMovementsSince => 'Mouvements depuis le dernier solde';

  @override
  String get accountMovementsBefore => 'Mouvements avant le premier solde, compris dans celui-ci';

  @override
  String get accountDetailedHint => 'Compte détaillé : son solde vient de ses relevés, il ne se déclare pas.';

  @override
  String get accountDebtsHint =>
      'Un compte « Dettes » n\'a pas de solde propre : la fortune compte le tableau des dettes.';

  @override
  String get accountNoBalance => 'Sans solde déclaré, ce compte est hors de la fortune.';

  @override
  String get accountIgnoredBalances => 'Soldes ignorés';

  @override
  String get accountOpenBalances => 'Soldes et mouvements';

  @override
  String get accountOldBalance => 'Dernier solde déclaré il y a plus de 6 mois.';

  @override
  String get accountEditAccount => 'Modifier le compte';

  @override
  String taskOldBalance(String name) {
    return 'Solde de « $name » à mettre à jour';
  }

  @override
  String taskOldBalanceHint(String date) {
    return 'Dernier solde déclaré le $date, il y a plus de 6 mois.';
  }

  @override
  String get keyFiguresWealth => 'Fortune nette';

  @override
  String get keyFiguresWealthOpen => 'Voir la fortune';

  @override
  String get debtsTitle => 'Dettes';

  @override
  String get debtsEmpty =>
      'Aucune dette. Une dette compte dans la fortune du jour de l\'événement à la veille de son remboursement. Elle peut aussi naître d\'une transaction, depuis l\'écran de celle-ci.';

  @override
  String get debtsOpen => 'Ouvertes';

  @override
  String get debtsRepaid => 'Remboursées';

  @override
  String get debtsOwedToMe => 'On me doit';

  @override
  String get debtsIOwe => 'Je dois';

  @override
  String get debtsNet => 'Net, dans la fortune';

  @override
  String get debtNew => 'Nouvelle dette';

  @override
  String get debtEdit => 'Modifier la dette';

  @override
  String get debtOwedToMe => 'On me doit';

  @override
  String get debtIOwe => 'Je dois';

  @override
  String get debtPerson => 'Personne';

  @override
  String get debtAmount => 'Montant';

  @override
  String get debtPercent => 'Pourcentage';

  @override
  String debtTotal(String amount) {
    return 'Total : $amount';
  }

  @override
  String get debtEventDate => 'Date de l\'événement';

  @override
  String get debtInvoiceDate => 'Date de la transaction de la facture';

  @override
  String get debtRequestDate => 'Date de la demande';

  @override
  String get debtReceivedDate => 'Date de la transaction du remboursement';

  @override
  String get debtDescription => 'Description';

  @override
  String get debtRepaid => 'Remboursée';

  @override
  String get debtDatesHint =>
      'Sans date d\'événement, la dette compte du jour de sa saisie ; remboursée sans date de remboursement, jusqu\'à la veille du jour où elle est cochée.';

  @override
  String get debtInvalidDate => 'Date invalide : jj.mm.aaaa, ou laissez vide.';

  @override
  String debtSince(String date) {
    return 'depuis le $date';
  }

  @override
  String debtReceivedOn(String date) {
    return 'remboursée le $date';
  }

  @override
  String get debtCheckTitle => 'Dette remboursée';

  @override
  String get debtCheckHint => 'La dette cesse de compter dans la fortune le jour de son remboursement.';

  @override
  String get debtCheck => 'Cocher remboursée';

  @override
  String get debtUncheck => 'Décocher';

  @override
  String get debtSplit => 'Scinder';

  @override
  String get debtSplitTitle => 'Scinder la dette';

  @override
  String debtSplitHint(String total) {
    return 'Montant de la première part, pris sur le total de $total. Le reste forme une deuxième ligne, avec les mêmes personne, sens, dates et description.';
  }

  @override
  String get debtSplitFirst => 'Première part';

  @override
  String debtSplitDone(String first, String second) {
    return 'Dette scindée en $first et $second.';
  }

  @override
  String debtDeleteConfirm(String person) {
    return 'Supprimer la dette de $person ?';
  }

  @override
  String get debtDeleted => 'Dette supprimée.';

  @override
  String get debtFromThis => 'née de cette transaction';

  @override
  String get debtRepaidByThis => 'remboursée par cette transaction';

  @override
  String get debtCreateFromTransaction => 'Créer une dette';

  @override
  String get debtRepayWithTransaction => 'Rembourse une dette';

  @override
  String get debtRepayTitle => 'Quelle dette cette transaction rembourse-t-elle ?';

  @override
  String debtRepaidDone(String person) {
    return 'Dette de $person remboursée par cette transaction.';
  }

  @override
  String get accountDebtsOpen => 'Voir le tableau des dettes';

  @override
  String get errorModuleCategoryRequired => 'Indiquez le nom de la catégorie.';

  @override
  String get errorUnknownSalarySheet => 'Cette fiche salaire n\'existe plus.';

  @override
  String get errorSalaryGrossRequired => 'Saisissez un salaire brut supérieur à zéro.';

  @override
  String get errorSalaryNetNegative => 'Le salaire net ne peut pas être négatif.';

  @override
  String get errorSalaryDeductionLabelRequired => 'Chaque déduction a un libellé.';

  @override
  String get errorSalaryDeductionNegative => 'Une déduction ne peut pas être négative.';

  @override
  String get moreAnalyses => 'Analyses';

  @override
  String get moreSettings => 'Réglages';

  @override
  String moduleCategory(String name) {
    return 'Catégorie liée : « $name »';
  }

  @override
  String moduleCategoryFound(String year) {
    return 'Trouvée dans l\'arbre de $year.';
  }

  @override
  String moduleCategoryMissing(String year) {
    return 'Aucune catégorie de ce nom dans l\'arbre de $year.';
  }

  @override
  String get moduleCategoryTitle => 'Catégorie liée';

  @override
  String get moduleCategoryHint =>
      'Le même nom pour toutes les années, sans tenir compte des majuscules ni des accents. Un groupe compte avec tout ce qu\'il contient.';

  @override
  String get moduleCategoryName => 'Nom de la catégorie';

  @override
  String get salaryTitle => 'Fiche salaire';

  @override
  String get salaryMenuHint => 'Brut, déductions et net de chaque année.';

  @override
  String get salaryYear => 'Année';

  @override
  String get salaryGross => 'Salaire brut';

  @override
  String get salaryNet => 'Salaire net';

  @override
  String get salaryDeductions => 'Déductions';

  @override
  String get salaryDeductionLabel => 'Libellé';

  @override
  String get salaryDeductionAmount => 'Montant';

  @override
  String get salaryDeductionAdd => 'Ajouter une déduction';

  @override
  String get salaryDeductionRemove => 'Retirer';

  @override
  String salaryDeductionsTotal(String amount) {
    return 'Total des déductions : $amount';
  }

  @override
  String salaryGap(String amount) {
    return 'Écart : $amount (brut moins déductions moins net)';
  }

  @override
  String get salaryBalanced => 'Le brut moins les déductions donne le net.';

  @override
  String salaryNew(String year) {
    return 'Pas encore de fiche pour $year : les libellés proposés sont ceux de la fiche précédente.';
  }

  @override
  String get salarySaved => 'Fiche salaire enregistrée.';

  @override
  String salaryDeleteConfirm(String year) {
    return 'Supprimer la fiche salaire de $year ?';
  }

  @override
  String get salaryDeleted => 'Fiche salaire supprimée.';

  @override
  String get salaryInvalidAmount => 'Montant invalide.';

  @override
  String get salaryTwoEmployers => 'Avec deux employeurs, additionnez les montants des deux certificats.';

  @override
  String get flowButton => 'Flux';

  @override
  String flowTitle(String year) {
    return 'Flux $year';
  }

  @override
  String get flowGross => 'Salaire brut';

  @override
  String flowGroupWithout(String group, String categories) {
    return '$group hors $categories';
  }

  @override
  String get flowAnd => ' et ';

  @override
  String get flowFromWealth => 'Puisé dans la fortune';

  @override
  String flowFromGross(String year) {
    return 'Le diagramme part du salaire brut de la fiche $year.';
  }

  @override
  String flowFromNet(String year) {
    return 'Le diagramme part du salaire net : pas de fiche salaire pour $year.';
  }

  @override
  String flowNoSalary(String name, String year) {
    return 'Pas de catégorie « $name » en $year : le diagramme part des groupes de revenus.';
  }

  @override
  String flowGrossGap(String amount) {
    return 'Écart avec le brut saisi : $amount (net reçu plus déductions, moins le brut de la fiche).';
  }

  @override
  String flowUnclassified(String amount) {
    return '« Non classé » ($amount) n\'entre pas dans le diagramme.';
  }

  @override
  String get flowEmpty => 'Rien à montrer pour cette année.';

  @override
  String get flowLeft => 'D\'où vient l\'argent';

  @override
  String get flowRight => 'Où il va';

  @override
  String flowTotal(String amount) {
    return 'Total : $amount';
  }

  @override
  String get errorUnknownTaxYear => 'Cette année fiscale n\'existe plus.';

  @override
  String get errorTaxBaseNegative => 'Une base imposable ne peut pas être négative.';

  @override
  String get errorTaxRateInvalid => 'Un taux de base va de 0 à 100 %, avec quatre décimales au plus.';

  @override
  String get errorTaxCoefficientNegative => 'Un coefficient ne peut pas être négatif.';

  @override
  String get errorTaxMarginalRateInvalid => 'Le taux marginal va de 0 à 100 %, avec deux décimales au plus.';

  @override
  String get taxesTitle => 'Impôts';

  @override
  String get taxesMenuHint => 'Par année fiscale : lignes, total et contrôle des paiements.';

  @override
  String get taxesYear => 'Année fiscale';

  @override
  String get taxesFederalIncome => 'Revenu fédéral';

  @override
  String get taxesCantonalIncome => 'Revenu cantonal';

  @override
  String get taxesCommunalIncome => 'Revenu communal';

  @override
  String get taxesCantonalWealth => 'Fortune cantonale';

  @override
  String get taxesCommunalWealth => 'Fortune communale';

  @override
  String get taxesBase => 'Base imposable';

  @override
  String get taxesTaxableWealth => 'Fortune imposable';

  @override
  String get taxesBaseRate => 'Taux de base %';

  @override
  String get taxesCoefficient => 'Coefficient %';

  @override
  String get taxesMarginalRate => 'Taux marginal (TMI) %';

  @override
  String taxesLineResult(String rate, String amount) {
    return 'Taux total $rate · $amount';
  }

  @override
  String get taxesLineIncomplete => 'Ligne incomplète : 0.00';

  @override
  String get taxesTotal => 'Total';

  @override
  String get taxesShareOfGross => 'Part du brut';

  @override
  String get taxesShareOfNet => 'Part du net';

  @override
  String taxesNoSheet(String year) {
    return 'Sans fiche salaire pour $year, les parts du brut et du net ne s\'affichent pas.';
  }

  @override
  String get taxesControl => 'Contrôle';

  @override
  String taxesPaid(String year) {
    return 'Payé pour $year';
  }

  @override
  String taxesPaidHint(String year) {
    return 'Ce que la vue économique de $year compte dans la catégorie liée : la période compte, pas la date de paiement.';
  }

  @override
  String get taxesLeftToPay => 'Reste à payer';

  @override
  String get taxesPaidTooMuch => 'Payé en trop';

  @override
  String get taxesSettled => 'Payé exactement';

  @override
  String taxesNoControl(String year) {
    return 'Pas de contrôle pour $year : l\'année n\'a pas d\'arbre de catégories, ou pas de catégorie liée.';
  }

  @override
  String get taxesSummary => 'Récapitulatif';

  @override
  String taxesSummaryLine(String total, String gross, String net, String marginal, String paid, String gap) {
    return 'Total $total · brut $gross · net $net · TMI $marginal · payé $paid · écart $gap';
  }

  @override
  String get taxesSaved => 'Année fiscale enregistrée.';

  @override
  String taxesDeleteConfirm(String year) {
    return 'Supprimer l\'année fiscale $year ?';
  }

  @override
  String get taxesDeleted => 'Année fiscale supprimée.';

  @override
  String get taxesInvalid => 'Valeur invalide : vérifiez les montants et les pourcentages.';

  @override
  String get taxesNone => '–';

  @override
  String get errorUnknownTripSheet => 'Cette fiche de voyage n\'existe plus.';

  @override
  String get errorTripDaysInvalid => 'Un voyage dure au moins un jour.';

  @override
  String get errorTripDateRequired => 'Une ligne manuelle a une date.';

  @override
  String get errorTripAmountRequired => 'Une ligne manuelle a un montant.';

  @override
  String get vacationsTitle => 'Vacances';

  @override
  String get vacationsMenuHint => 'Les voyages, regroupés par leurs périodes.';

  @override
  String get vacationsNone =>
      'Aucun voyage : les transactions de la catégorie liée forment les voyages, selon leurs périodes.';

  @override
  String vacationsYearTotal(String year, String amount) {
    return '$year · $amount';
  }

  @override
  String vacationsTripSubtitle(String date, String days) {
    return '$date · $days';
  }

  @override
  String vacationsDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count jours', one: '1 jour');
    return '$_temp0';
  }

  @override
  String get vacationsNoDays => 'jours à saisir';

  @override
  String vacationsPerDay(String amount) {
    return '$amount par jour';
  }

  @override
  String get vacationsNoPlace => 'Voyage sans lieu';

  @override
  String get vacationsManual => 'Ligne manuelle';

  @override
  String get vacationsNewManual => 'Nouvelle ligne manuelle';

  @override
  String get vacationsTrip => 'Voyage';

  @override
  String get vacationsPlace => 'Lieu';

  @override
  String get vacationsDaysField => 'Jours';

  @override
  String get vacationsDate => 'Date';

  @override
  String get vacationsAmount => 'Montant';

  @override
  String get vacationsReplaceDate => 'Date remplacée';

  @override
  String get vacationsReplaceAmount => 'Montant remplacé';

  @override
  String vacationsAutomatic(String value) {
    return 'Automatique : $value';
  }

  @override
  String get vacationsRestore => 'Rétablir';

  @override
  String get vacationsTransactions => 'Transactions du voyage';

  @override
  String vacationsExtraSheets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autres fiches sont accrochées à ce voyage : la plus ancienne s\'applique.',
      one: 'Une autre fiche est accrochée à ce voyage : la plus ancienne s\'applique.',
    );
    return '$_temp0';
  }

  @override
  String get vacationsOrphans => 'Fiches sans transaction';

  @override
  String get vacationsOrphansHint => 'Leur transaction a quitté la catégorie ou n\'existe plus.';

  @override
  String get vacationsSaved => 'Voyage enregistré.';

  @override
  String get vacationsDeleted => 'Fiche supprimée.';

  @override
  String get vacationsInvalid => 'Valeur invalide : vérifiez la date, le montant et les jours.';

  @override
  String get errorUnknownElectricityReading => 'Cette ligne n\'a pas de kWh saisis.';

  @override
  String get errorElectricityNegative => 'Les kWh ne peuvent pas être négatifs.';

  @override
  String get electricityTitle => 'Électricité';

  @override
  String get electricityMenuHint => 'Prix, kWh et jours par année.';

  @override
  String get electricityNone => 'Aucune facture : les transactions de la catégorie liée apparaissent ici.';

  @override
  String get electricityPrice => 'Prix total';

  @override
  String get electricityKwh => 'kWh';

  @override
  String get electricityDays => 'Jours';

  @override
  String get electricityPerDay => 'CHF par jour';

  @override
  String get electricityPerKwh => 'CHF par kWh';

  @override
  String get electricityKwhPerDay => 'kWh par jour';

  @override
  String electricityMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes sans kWh : le prix par kWh est surestimé.',
      one: 'Une ligne sans kWh : le prix par kWh est surestimé.',
    );
    return '$_temp0';
  }

  @override
  String electricityLines(String year) {
    return 'Factures de $year';
  }

  @override
  String electricityLine(String date, String start, String end, String days) {
    return '$date · $start – $end · $days j';
  }

  @override
  String electricityLineKwh(String kwh) {
    return '$kwh kWh';
  }

  @override
  String get electricityNoKwh => 'kWh à saisir';

  @override
  String get electricityEnter => 'kWh de la facture';

  @override
  String get electricityErase => 'Effacer';

  @override
  String get electricityInvalid => 'Nombre de kWh invalide.';

  @override
  String get electricityOrphans => 'kWh sans facture';

  @override
  String get electricityOrphansHint => 'Leur transaction a quitté la catégorie ou n\'existe plus.';

  @override
  String get errorUnknownSubscription => 'Cet abonnement n\'existe plus.';

  @override
  String get errorTrancheEndBeforeStart => 'La fin d\'une tranche ne peut pas précéder son début.';

  @override
  String get errorTrancheOverlap => 'Cette tranche chevauche une autre tranche de l\'abonnement.';

  @override
  String get subscriptionsTitle => 'Abonnements';

  @override
  String get subscriptionsMenuHint => 'Coût par mois et par an des abonnements en cours.';

  @override
  String get subscriptionsNone => 'Aucun abonnement.';

  @override
  String get subscriptionsTotals => 'Abonnements en cours';

  @override
  String get subscriptionsPerMonth => 'Par mois';

  @override
  String get subscriptionsPerYear => 'Par an';

  @override
  String get subscriptionsCurrent => 'En cours';

  @override
  String get subscriptionsUpcoming => 'À venir';

  @override
  String get subscriptionsEnded => 'Terminés';

  @override
  String subscriptionsCosts(String month, String year) {
    return '$month par mois · $year par an';
  }

  @override
  String subscriptionsSince(String date) {
    return 'depuis le $date';
  }

  @override
  String subscriptionsFrom(String date) {
    return 'dès le $date';
  }

  @override
  String subscriptionsUntil(String date) {
    return 'jusqu\'au $date';
  }

  @override
  String get subscriptionsOverlap => 'Deux tranches se chevauchent : corrigez-en une.';

  @override
  String get subscriptionNew => 'Nouvel abonnement';

  @override
  String get subscriptionEdit => 'Abonnement';

  @override
  String get subscriptionName => 'Nom';

  @override
  String get subscriptionNote => 'Note';

  @override
  String get subscriptionTranches => 'Tranches';

  @override
  String get subscriptionAddTranche => 'Nouvelle tranche';

  @override
  String get subscriptionTrancheHint =>
      'Un changement de prix ou une reprise est une nouvelle tranche : elle ferme la précédente la veille de son début.';

  @override
  String get subscriptionAmount => 'Montant';

  @override
  String get subscriptionMonthly => 'Mensuel';

  @override
  String get subscriptionYearly => 'Annuel';

  @override
  String get subscriptionStart => 'Début';

  @override
  String get subscriptionEnd => 'Fin (facultative)';

  @override
  String subscriptionTranche(String amount, String frequency, String period) {
    return '$amount $frequency · $period';
  }

  @override
  String get subscriptionPerMonthShort => 'par mois';

  @override
  String get subscriptionPerYearShort => 'par an';

  @override
  String subscriptionDeleteConfirm(String name) {
    return 'Supprimer l\'abonnement « $name » ?';
  }

  @override
  String get subscriptionDeleted => 'Abonnement supprimé.';

  @override
  String get subscriptionSaved => 'Abonnement enregistré.';

  @override
  String get subscriptionInvalid => 'Valeur invalide : vérifiez le montant et les dates.';

  @override
  String get exportMenu => 'Exporter les données';

  @override
  String get exportMenuHint => 'Un fichier ZIP de fichiers CSV, pour un tableur';

  @override
  String get exportTitle => 'Exporter les données';

  @override
  String get exportContents =>
      'L\'export enregistre tout ce qui a été saisi ou importé sur cet appareil, dans son état du jour : comptes, soldes déclarés, relevés, catégories, règles, transactions, dettes et saisies des modules. Un fichier CSV par sujet, dans un fichier ZIP, avec un LISEZMOI.txt qui explique le format.';

  @override
  String get exportNotIncluded =>
      'Ce que l\'app calcule (vue annuelle, fortune, diagramme) n\'est pas exporté, ni les PDF des relevés, qui restent sur le serveur.';

  @override
  String get exportNotEncrypted =>
      'Le fichier n\'est pas chiffré : quiconque l\'ouvre lit vos données. Gardez-le en lieu sûr.';

  @override
  String get exportOffline => 'L\'export ne passe pas par le serveur et ne modifie rien.';

  @override
  String get exportButton => 'Exporter';

  @override
  String get exportWorking => 'Préparation de l\'export…';

  @override
  String exportSaved(int files, int transactions) {
    String _temp0 = intl.Intl.pluralLogic(
      transactions,
      locale: localeName,
      other: '$transactions transactions',
      one: 'une transaction',
      zero: 'aucune transaction',
    );
    return 'Export enregistré : $files fichiers CSV et LISEZMOI.txt, $_temp0.';
  }

  @override
  String get exportCancelled => 'Export annulé : rien n\'a été enregistré.';

  @override
  String exportFailed(String error) {
    return 'L\'export a échoué : $error';
  }

  @override
  String get lockTitle => 'L\'app est verrouillée.';

  @override
  String get lockUnlock => 'Déverrouiller';

  @override
  String get lockRetry => 'Réessayer';

  @override
  String get lockDialogTitle => 'Déverrouiller batz';

  @override
  String get lockDialogReason => 'Empreinte, visage ou code de l\'appareil';

  @override
  String get lockCancelled => 'Déverrouillage annulé.';

  @override
  String get lockLockedOut => 'Trop d\'essais : réessayez dans un moment.';

  @override
  String lockFailed(String error) {
    return 'Le déverrouillage a échoué : $error';
  }

  @override
  String get taskNoScreenLock => 'Ce téléphone n\'a pas de verrouillage d\'écran';

  @override
  String get taskNoScreenLockHint =>
      'batz s\'ouvre sans déverrouillage. Activez un verrouillage d\'écran dans les réglages d\'Android.';

  @override
  String moreVersion(String version) {
    return 'batz $version';
  }
}

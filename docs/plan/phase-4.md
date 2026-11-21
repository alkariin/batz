# Plan de la phase 4 — Vue annuelle

Référence : [specification.md](../specification.md), chapitres 3, 4.1, 4.2, 4.6, 6, 11 et 13 ; règles de conception dans [decisions.md](../decisions.md).

But de la phase : répondre à la deuxième question de l'app, « combien me coûte réellement chaque année ». L'écran « Année » montre l'arbre des catégories avec ses montants, mois par mois, en vue trésorerie (ce qui a été payé dans l'année) ou en vue économique (ce que l'année a coûté). S'y ajoutent la redistribution entre catégories, le remboursement rattaché à sa dépense, et la question posée quand une part reportée sur une autre année n'y trouve pas sa catégorie.

## État de départ

Contrôle de la phase 3 fait le 21 novembre 2026 :

- Analyse sans défaut et 327 tests de l'app au vert ; tests du serveur au vert avec le détecteur d'accès concurrents ; garde-fou des données personnelles au vert (fichiers suivis, textes des PDF et messages de commit) ; les trois relevés réels présents sont acceptés, avec des dates et des montants identiques à la référence ; CI au vert sur `main` ; versions 0.4.0 puis 0.4.1 publiées. La 0.4.1 corrige l'APK publié, qui n'avait pas le droit d'accéder au réseau.
- Relus : côté serveur, le domaine du relevé et ses contrôles, la lecture du texte PostFinance, le libellé court, le service d'import, le rangement des PDF et les copies de la base ; côté app, le domaine (import, suppression du dernier relevé, règles, propositions, validation, recherche), le parcours d'import et l'écran de classement. Ils sont conformes au plan de la phase 3, à ses principes et aux décisions H1 à H8. Le générateur de relevés fictifs et les autres écrans n'ont pas été relus en détail.

Deux points à reprendre, placés dans l'étape 4.0 :

1. **« Créer une règle » peut proposer un mot-clé qui ne classe rien.** Le formulaire part de la description de la ligne (le libellé court), alors que les règles lisent le texte de la banque. Mesuré sur les trois relevés réels : une ligne par relevé (sur 62, 49 et 70) a un libellé court qui ne se retrouve pas tel quel dans ce texte. La règle proposée ne classerait alors aucune ligne, pas même la sienne. Le compteur du formulaire affiche bien zéro, sans dire pourquoi.
2. **Après chaque écriture, l'app relit toutes ses données et recalcule toutes les propositions.** Sans effet visible aujourd'hui. La vue annuelle ajoute un calcul sur toutes les lignes : le temps de rechargement est à mesurer avec dix ans de données avant de construire dessus. Rien n'indique un problème ; ce n'est pas mesuré.

## Décisions de l'utilisateur pour cette phase

Validées le 21 novembre 2026. La spécification ne tranchait pas ces points. Aucune décision ne s'écarte de sa lettre ; H8 avance dans cette phase un élément qu'elle ne rattache à aucune phase.

| N° | Point | Décision |
|---|---|---|
| H1 | Redistribution : dans quelles vues | **Les deux**, mois par mois : la règle déplace une part du total mensuel de la source, tel que la vue l'affiche. Si elle ne valait qu'en vue économique, la bascule changerait aussi la répartition entre catégories, et les deux vues ne différeraient plus seulement par les décalages de période. |
| H2 | Redistribution : quelles catégories, quel pourcentage | Source et cible : deux catégories **sans enfant**, de la même année et de la **même nature** (deux dépenses, ou deux revenus). Pourcentage de 0,01 à 100, deux décimales au plus. Plusieurs règles peuvent partir d'une même source si leur total ne dépasse pas 100 %. Une cible ne peut pas être une source (spécification). Le pourcentage s'applique au montant de la source **avant toute redistribution**, arrondi au centime mois par mois. Une catégorie utilisée par une règle ne peut pas être supprimée. |
| H3 | Remboursement rattaché : ce qu'il reprend | Il **suit sa dépense** tant qu'il lui est rattaché : sa catégorie et sa période sont celles de la dépense, y compris si elles changent ensuite. En vue trésorerie, il compte à sa propre date de paiement ; en vue économique, il est réparti sur la période de la dépense. Détaché, ou si la dépense disparaît, il retrouve sa propre catégorie et sa date. |
| H4 | Remboursement rattaché : quoi, à quoi, où | Se rattache : une entrée d'argent qui n'est pas un transfert, saisie à la main ou importée. À : une **dépense validée**, de n'importe quel compte et de n'importe quelle année. Plusieurs remboursements par dépense, sans plafond. Le rattachement se fait à la validation d'une ligne importée (troisième choix, après « Catégorie » et « Transfert »), depuis le détail d'une transaction et dans la saisie manuelle. Les règles de mapping ne proposent pas de rattachement. |
| H5 | Part reportée sans catégorie de même nom : la forme de la question | La question **n'interrompt rien** : une tâche « Parts à classer » à l'accueil, et une ligne « À classer » dans l'année concernée, qui compte déjà dans les revenus ou les dépenses selon la nature de la catégorie d'origine. L'écran de réponse regroupe les parts par catégorie d'origine et par année : une réponse pour le groupe, modifiable ligne par ligne. La réponse est mémorisée par ligne et par année (spécification, chapitre 6). Une catégorie de même nom devenue un groupe ne convient pas : la question est posée. Si la catégorie choisie disparaît ou devient un groupe, la question revient. |
| H6 | Années sans arbre | Une année à venir sans arbre (2027, vue depuis 2026) s'affiche avec l'arbre et les règles qu'elle recevra par copie. Une année **antérieure au premier arbre** (2025) n'est pas affichée : les parts qui la concernent, par exemple des impôts 2025 payés en 2026, sortent de la vue économique de l'année du paiement et n'apparaissent que dans ses décalages de période. |
| H7 | Vue « Année » : signes et vue d'ouverture | Sous « Dépenses », les montants s'affichent comme des **coûts, sans signe moins** ; un remboursement les diminue. Épargne = revenus moins dépenses. L'écran s'ouvre en vue économique la première fois, puis sur le dernier choix fait sur l'appareil. |
| H8 | Chiffres clés de l'accueil | **Dès cette phase** : revenus, dépenses et épargne de l'année en cours, en vue économique, avec un accès à l'écran « Année ». La spécification (4.6) les prévoit sans dire dans quelle phase. La fortune s'y ajoutera en phase 5. |

**Commits** : même régime qu'en phases 0 à 3. Commits locaux sur des branches, un par étape, sans push. Messages en anglais, au format Conventional Commits, sujet de 50 caractères au plus, sans ligne `Co-Authored-By`. Le push, la version 0.5.0 et le déploiement sur le NAS se font à la fin, avec l'accord de l'utilisateur. Le serveur ne change que de version : il refusera ensuite les apps 0.4, qui ignoreraient les règles de redistribution, les rattachements et les réponses, et afficheraient d'autres totaux. Les apps 0.5.0 fonctionnent avec le serveur 0.4 en attendant.

## Principes

1. **Les vues se calculent, rien ne s'y enregistre.** Totaux, détail par mois, montants redistribués, coût net, décalages de période : tout est recalculé à chaque chargement à partir de ce que l'utilisateur a saisi. Le journal ne reçoit que trois choses nouvelles : les règles de redistribution, le rattachement d'un remboursement, les réponses aux parts à classer.
2. **Un seul calcul pour les deux vues.** Chaque ligne produit des montants datés par mois : un seul, au mois du paiement, en vue trésorerie ; un par part mensuelle en vue économique. Tout le reste est commun : choix de la catégorie dans l'année du mois, sommes des groupes, redistribution, totaux. Les deux vues ne peuvent donc différer que par l'endroit où tombent les montants. Une ligne à valider compte comme ses règles la proposent, catégorie et période (principe 3 de la phase 3).
3. **Entre années, la correspondance se fait par le nom, à chaque chargement.** Un montant qui tombe dans une autre année que celle du paiement va dans la catégorie de même nom de cette année, si elle peut recevoir des transactions ; à défaut, dans la catégorie de la réponse mémorisée, si elle est encore valable ; à défaut, il est « à classer ». Rien n'est figé : renommer une catégorie change la correspondance aussitôt, sur tous les appareils.
4. **La redistribution est un déplacement à somme nulle.** Pour chaque mois et chaque règle : le pourcentage du montant de la source avant redistribution, arrondi au centime, quitte la source et rejoint la cible, sur une ligne distincte de chaque côté. Le total d'un groupe qui contient les deux ne change pas ; les revenus, les dépenses et l'épargne non plus. Le montant annuel d'une ligne de redistribution est la somme de ses douze mois.
5. **Un remboursement rattaché suit sa dépense.** Le journal ne retient que le lien. La catégorie et la période du remboursement se lisent sur la dépense tant que le lien mène à une dépense validée ; sinon, sur le remboursement lui-même.
6. **Rien ne bloque.** Une règle de redistribution devenue inapplicable, une part sans catégorie, un lien de remboursement rompu : l'app continue, compte ce qu'elle peut et liste le reste dans les tâches, comme pour les incohérences d'une fusion (phase 2) et les règles de mapping inutilisables (phase 3).
7. **Identifiants calculés** pour ce que deux appareils peuvent créer séparément à partir de la même source : la copie d'une règle de redistribution (règle d'origine et année), la réponse à une part (ligne et année).
8. **Aucun nombre à virgule.** Un pourcentage s'enregistre en centièmes de pour-cent, entier. Les arrondis sont ceux de la répartition : au centime, la moitié s'éloignant de zéro.
9. **Aucune donnée réelle dans le repo**, comme en phase 3 : les exemples et les jeux d'essai sont inventés.

## Étapes

Chaque étape est une branche locale et un commit, avec ses tests.

### 4.0 Préparation

- Reprise 1 : le mot-clé proposé par « Créer une règle » se trouve toujours dans le texte de la banque de la ligne dont il part. La règle proposée classe donc au moins cette ligne, tant que l'utilisateur ne change pas les mots-clés.
- Reprise 2 : mesurer le rechargement après une écriture (lecture de la base, construction du grand livre, propositions) avec 10 000 transactions sur cinq ans et 200 règles de mapping. Mesure consignée dans `docs/decisions.md`. Au-delà de 300 ms sur la machine de développement, corriger avant d'aller plus loin.
- Test : une base de la version 0.4.1 (un relevé fictif importé, des règles, des lignes validées et à valider) s'ouvre avec la nouvelle version, données conservées.

### 4.1 Domaine : les deux vues d'une année

Dart pur, dans ses propres fichiers : le calcul lit le grand livre, il ne grossit pas `ledger.dart`.

- Pour une année et une vue : pour chaque catégorie de l'arbre, douze montants mensuels et le total de l'année ; un groupe additionne ses enfants ; totaux des revenus, des dépenses, épargne.
- « Non classé » : les lignes sans catégorie d'origine utilisable (à valider sans proposition, ou dont la catégorie n'est plus dans l'arbre de l'année du paiement). Elles comptent à leur date de paiement dans les deux vues, hors revenus et dépenses.
- « À classer » : les montants dont la catégorie d'origine n'a pas de correspondante dans l'année (principe 3), par nature. Ils comptent dans les revenus ou les dépenses.
- Années sans arbre, selon H6 : arbre et règles de la copie à venir pour une année postérieure ; année non affichée avant le premier arbre.
- Décalages de période d'une année, en montants signés : payé dans l'année pour d'autres années, et payé d'autres années pour celle-ci. Identité vérifiée : résultat de trésorerie = résultat économique + premier − second.
- Composition d'un montant : pour une catégorie, et au besoin un mois, la liste des transactions qui le forment, avec la part comptée.
- Les totaux de trésorerie de la phase 1 passent par ce calcul : une seule implémentation.
- Tests : les exemples de la spécification ; puis, sur des données tirées au hasard : la somme des douze mois est le total de chaque ligne ; le total de trésorerie d'une année est la somme de ses paiements hors transferts ; sur l'ensemble des années, les deux vues totalisent le même montant ; l'identité des décalages.

### 4.2 Domaine : redistribution

- Entité « règle de redistribution » d'une année : source, cible, pourcentage en centièmes de pour-cent.
- Création, modification, suppression, avec les règles de H2 ; refus motivé.
- Les règles suivent la copie de l'arbre : identifiants calculés, source et cible transposées. L'arbre à venir d'une année (H6) les comprend.
- Calcul selon le principe 4, dans les deux vues (H1). La base d'une règle comprend tout ce que la source affiche pour le mois : lignes proposées, remboursements, parts venues d'autres années.
- Une règle inapplicable ne s'applique pas et figure dans les tâches : source ou cible absente, devenue un groupe ou détachée ; natures différentes ; et, après une fusion, total d'une source au-delà de 100 % ou cible qui est aussi une source (toutes les règles en cause sont écartées).
- Une catégorie utilisée par une règle ne peut pas être supprimée, avec le nombre de règles.
- Tests : l'exemple de la spécification, mois par mois ; arrondi ; plusieurs règles depuis une source ; totaux des groupes et des natures inchangés ; chaque refus ; chaque cas d'inapplicabilité ; copie de l'arbre sur deux appareils.

### 4.3 Domaine : remboursement rattaché

- Champ nouveau sur la ligne du remboursement : la ligne remboursée (spécification, chapitre 6).
- Rattacher : refusé si la transaction est une sortie d'argent ou un transfert, ou si la cible n'est pas une dépense validée. Rattacher une ligne importée à valider la valide. La ligne garde une catégorie propre, celle de même nom dans l'année de son paiement quand elle existe : c'est elle qui sert si le lien se rompt.
- Détacher : la ligne retrouve sa catégorie propre et sa date.
- Tant que le lien tient (principe 5) : catégorie et période de la dépense, coût net de la dépense (son montant plus ses remboursements), liste de ses remboursements. Les parts d'un remboursement suivent celles de la dépense, année par année, réponses mémorisées comprises.
- Supprimer la dépense, ou le relevé qui la contient, rompt le lien sans erreur.
- Tests : le critère de la spécification ; remboursement reçu l'année suivante ; période de la dépense modifiée après coup ; plusieurs remboursements ; lien rompu ; chaîne créée par deux appareils, sans effet.

### 4.4 Domaine : parts à classer

- Entité « classement d'une part » : ligne, année, catégorie choisie, et catégorie d'origine pour laquelle la réponse a été donnée. Identifiant calculé à partir de la ligne et de l'année.
- Une réponse vaut tant que la ligne a toujours cette catégorie d'origine et que la catégorie choisie peut recevoir des transactions dans l'arbre de l'année.
- Liste des questions en attente, regroupées par catégorie d'origine et par année, avec les lignes et les montants concernés.
- Répondre : une modification pour tout un groupe ou pour une ligne. Répondre pour une année dont l'arbre n'existe pas encore écrit cet arbre dans la même modification, comme une première transaction.
- Tests : le critère de la spécification ; réponse mémorisée après rechargement ; catégorie renommée dans l'année concernée ; catégorie de même nom devenue un groupe ; réponse devenue caduque ; deux appareils répondant à la même question.

### 4.5 App : écran « Année »

- Choix de l'année ; bascule Trésorerie / Économique (H7).
- En tête : revenus, dépenses, épargne ; « Non classé » s'il n'est pas nul ; en vue économique, les deux décalages de période. Un rappel quand des montants viennent de lignes à valider.
- Arbre avec montants, groupes repliables ; lignes de redistribution sous la source et sous la cible ; ligne « À classer » par nature.
- Détail par mois : douze colonnes et le total quand la largeur le permet, détail dépliable par ligne sinon.
- Un montant ouvre la liste des transactions qui le composent, puis le détail d'une transaction.
- Accueil : chiffres clés de l'année en cours (H8).
- Formats suisses ; signes selon H7.
- Test d'interface : la bascule change les montants d'un paiement à cheval sur deux années ; détail par mois ; accès aux transactions d'une catégorie.

### 4.6 App : redistribution, remboursements, parts à classer

- « Plus » → « Redistribution » : règles de l'année, création, modification, suppression ; règles inapplicables signalées, et listées dans les tâches de l'accueil.
- Rattachement (H4) : troisième choix de l'écran de classement pour une entrée d'argent, avec recherche de la dépense par texte et par montant ; même action depuis le détail d'une transaction et dans la saisie manuelle ; « Détacher ».
- Détail d'une dépense : remboursements rattachés et coût net. Détail d'un remboursement : la dépense, avec un accès.
- « Parts à classer » : tâche à l'accueil, ligne « À classer » de la vue « Année », écran de réponse (H5).
- Tests d'interface : rattacher un remboursement à la validation et voir le coût net ; répondre à une part à classer ; créer une règle de redistribution et voir ses deux lignes.

### 4.7 Documentation et version

- En anglais : `docs/year-view.md` (les deux vues, la correspondance par nom, la redistribution, les remboursements, les parts à classer, avec leurs exemples chiffrés) ; mise à jour de `batz-web/docs/architecture.md` et de `README.md` ; décisions prises en route dans `docs/decisions.md`.
- App et serveur en version 0.5.0 ; le serveur exige l'app 0.5.0.

## Critères d'acceptation

### Vérifiables par une commande sur la machine de développement

| Critère | Commande |
|---|---|
| Pour une même année, les deux vues ne diffèrent que par les décalages de période : identité vérifiée au centime sur des données tirées au hasard, redistribution et remboursements compris. | `flutter test`, test des vues |
| 2'100 CHF payés en 2026 pour le 1.9.2026 – 31.8.2027 : 2'100 en trésorerie 2026 ; 700 en économique 2026 et 1'400 en 2027 ; 1'400 de décalage dans chaque année. | `flutter test`, test des vues |
| Pour chaque ligne de l'arbre, la somme des douze mois est le total de l'année, dans les deux vues. | `flutter test`, test des vues |
| 10 % de « Nourriture » apparaît dans « Entretien ménage », mois par mois, sur une ligne distincte de chaque côté ; 345.67 donne 34.57 ; le groupe commun et le total des dépenses ne changent pas. | `flutter test`, test de redistribution |
| Une règle de redistribution contraire à H2 est refusée avec son motif ; une règle devenue inapplicable ne s'applique pas et figure dans les tâches. | `flutter test`, test de redistribution |
| Une dépense de 300 pour janvier à mars et un remboursement de 120 reçu en mai, rattaché : coût net de 60 par mois de janvier à mars en vue économique, rien en mai ; en trésorerie, 300 en janvier et 120 en mai. | `flutter test`, test des remboursements |
| Un remboursement rattaché suit un changement de période ou de catégorie de sa dépense ; détaché ou lien rompu, il retrouve sa catégorie et sa date. | `flutter test`, test des remboursements |
| Une part reportée sans catégorie de même nom figure en « À classer », compte dans sa nature et crée une tâche ; la réponse la classe et reste mémorisée. | `flutter test`, test des parts à classer |
| Une année antérieure au premier arbre n'est pas affichée ; une année à venir s'affiche avec l'arbre de sa copie. | `flutter test`, test des vues |
| Règles de redistribution, rattachements et réponses saisis sur un appareil arrivent sur un autre ; la copie d'un arbre faite sur deux appareils donne les mêmes règles ; le test de convergence comprend les nouvelles opérations. | `flutter test`, tests de bout en bout |
| Avec 10 000 transactions sur cinq ans : rechargement après une écriture en moins de 300 ms, calcul des deux vues d'une année en moins de 100 ms. | `flutter test`, test de performance |
| Le mot-clé proposé par « Créer une règle » classe au moins la ligne dont il part. | `flutter test`, test de validation |
| Une base de la version 0.4.1 s'ouvre avec la nouvelle version. | `flutter test`, test d'ouverture |
| Les parcours de l'écran « Année », du rattachement, des parts à classer et de la redistribution fonctionnent dans l'interface. | `flutter test`, tests d'interface |
| L'app ne présente aucun défaut d'analyse et tous ses tests passent. | `flutter analyze && flutter test` dans `batz-ui` |
| Le serveur passe ses tests et refuse une app 0.4. | `go vet ./... && go test -race ./...` dans `batz-web/src` |
| La version Ubuntu, l'APK et l'image du serveur se fabriquent. | `flutter build linux`, `flutter build apk`, `docker build` |
| Aucun fichier personnel ni terme personnel n'est suivi par git. | `scripts/check-personal-files.sh` |

### Vérifiables sur GitHub, après le push

- Tous les contrôles de la CI sont au vert, compilation Windows comprise.
- La publication de la version 0.5.0 produit l'APK signé, les versions Ubuntu et Windows et l'image du serveur.

### À vérifier par l'utilisateur, après installation de la version 0.5.0

- L'année 2026, avec les relevés réels importés : en vue trésorerie, les montants d'un mois correspondent au relevé de ce mois ; la bascule déplace les paiements qui concernent une autre période.
- Un paiement à cheval sur 2026 et 2027 ne pèse sur 2026 que pour sa part, et 2027 s'affiche avec le reste.
- Une règle de redistribution réelle (par exemple 10 % de « Nourriture » vers « Entretien ménage ») affiche ses deux lignes.
- Un remboursement réel rattaché à sa dépense : coût net dans le détail et dans la vue économique.
- Sur l'ordinateur, les douze colonnes ; sur le téléphone, le détail dépliable.
- Après le déploiement du serveur 0.5.0 sur le NAS : une app 0.4 est refusée, les apps 0.5.0 se synchronisent.

## Hors de cette phase

- Fortune, soldes déclarés, variations de valeur, dettes, tableau d'explication de l'année : phase 5. Les décalages de période calculés ici en seront une ligne.
- Diagramme de flux, fiche salaire, impôts, vacances, électricité, abonnements : phase 6.
- Export : phase 7.
- Comparaison entre années, ventilation d'une transaction en plusieurs lignes, remboursement partiel réparti sur plusieurs dépenses : plus tard, sans engagement.

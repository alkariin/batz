# Plan de la phase 5 — Fortune

Référence : [specification.md](../specification.md), chapitres 3, 4.3, 4.6, 4.7 (dettes), 6, 11, 13 et 14 ; règles de conception dans [decisions.md](../decisions.md) ; calcul de la vue annuelle dans [year-view.md](../year-view.md).

But de la phase : répondre à la troisième question de l'app, « comment évolue ma fortune ». L'utilisateur déclare le solde de ses comptes une ou deux fois par an ; l'app en déduit les variations de valeur, tient le tableau des dettes, affiche la fortune nette, sa courbe mensuelle, et explique chaque année, au centime, pourquoi la fortune a varié. Cette phase termine le MVP.

## État de départ

Contrôle de la phase 4 fait le 21 novembre 2026 :

- Analyse sans défaut et 382 tests de l'app au vert ; tests du serveur au vert avec le détecteur d'accès concurrents ; garde-fou des données personnelles au vert (fichiers suivis, textes des PDF et messages de commit) ; CI au vert sur `main` ; version 0.5.0 publiée avec ses quatre fichiers. Le déploiement du serveur 0.5.0 sur le NAS est consigné par la session d'implémentation ; il n'a pas été revérifié ici.
- Relus : le calcul des deux vues, la redistribution, le rattachement des remboursements, les réponses aux parts à classer, les changements du grand livre, `docs/year-view.md` et les décisions 4.0 à 4.7. Ils sont conformes au plan de la phase 4, à ses principes et aux décisions H1 à H8. Les écrans n'ont pas été relus en détail ni lancés ; des tests, seuls les intitulés ont été relus.

Un point à reprendre, placé dans l'étape 5.0 :

1. **Le montant d'une ligne peut s'écarter de celui de sa transaction après une fusion.** Exemple : sur un appareil hors ligne, le montant d'une saisie manuelle est corrigé ; sur un autre, la même saisie est rattachée à une dépense, ce qui réécrit le montant de sa ligne avec l'ancienne valeur. Après synchronisation, la transaction porte un montant et sa ligne un autre. La vue annuelle compte la ligne, le solde du compte comptera la transaction : le tableau d'explication aurait un écart que rien ne montre. Sans effet tant qu'il n'y avait pas de solde ; à régler avant de construire la fortune.

## Décisions de l'utilisateur pour cette phase

Validées le 21 novembre 2026. La spécification ne tranchait pas ces points. H3 ajoute une ligne au tableau d'explication de la spécification (4.6), avec l'accord de l'utilisateur ; les autres décisions ne s'écartent pas de sa lettre.

| N° | Point | Décision |
|---|---|---|
| H1 | Solde d'un compte entre deux soldes déclarés | Le **dernier solde déclaré, plus les mouvements enregistrés depuis** (transferts, saisies). Sinon un virement vers l'épargne ferait baisser la fortune jusqu'à la déclaration suivante. Un solde déclaré vaut pour la **fin de sa journée** : les mouvements du même jour y sont compris. La variation de valeur est l'écart entre le solde déclaré et ce solde attendu ; elle est datée du jour de la déclaration, en entier, même si elle s'est formée sur plusieurs années. Un solde peut être négatif (un prêt). Un seul solde par compte et par jour. |
| H2 | Entrée d'un compte dans la fortune | Un compte au solde déclaré entre à son **premier solde déclaré** (spécification). Le compte détaillé entre avec le **solde initial de son premier relevé, la veille du début de ce relevé** : le 31.12.2025 pour un relevé de janvier 2026. L'année 2026 part ainsi d'une fortune qui comprend déjà le compte bancaire. Aucun solde ne se déclare sur le compte détaillé (ses relevés font foi) ni sur un compte « Dettes ». |
| H3 | Mouvements d'un compte qui n'est pas encore dans la fortune | Une ligne de plus dans le tableau d'explication, **« Hors fortune »**, affichée seulement si elle n'est pas nulle : ce qui est allé vers des comptes sans solde déclaré, ou en est venu. Exemple : 200 retirés vers « Espèces » jamais déclaré quittent la fortune suivie. Sans cette ligne, le tableau ne peut pas tomber juste. L'autre voie, compter un compte à partir de zéro dès son premier mouvement, contredit la spécification. |
| H4 | Compte archivé, compte supprimé | Un compte archivé **reste dans la fortune** avec son dernier solde : pour l'en sortir, déclarer un solde de 0. Le passé ne change donc pas quand on archive. Un compte qui a des soldes déclarés est archivé plutôt que supprimé, comme un compte qui a des transactions. |
| H5 | Dettes : montant, dates, signe | Total = montant × pourcentage, arrondi au centime ; pourcentage de 0,01 à 100, 100 par défaut. Une dette compte **du jour de l'événement** (à défaut, du jour de sa saisie) **jusqu'à la veille de la réception** (à défaut, du jour où elle est cochée). Cocher « remboursé » propose la date du jour comme date de réception. « On me doit » augmente la fortune, « je dois » la diminue. La fortune affiche une seule ligne « Dettes », égale au total des dettes ouvertes, qu'un compte de ce type existe ou non : un tel compte ne sert que de contrepartie aux transferts d'un prêt. |
| H6 | Scinder une dette | « Scinder » demande le montant de la première part, pris sur le total. La ligne devient deux lignes qui gardent sens, personne, dates et description ; chacune porte sa part comme montant, à 100 %. Les deux totaux font exactement le total d'origine. Le détail « montant × pourcentage » d'origine n'est pas conservé sur les parts. |
| H7 | Rappel des soldes anciens | Tâche à l'accueil pour un compte **non archivé** dont le dernier solde déclaré a plus de **6 mois** (spécification). Un compte qui n'a aucun solde n'est pas une tâche : l'écran « Fortune » le montre « sans solde, hors fortune ». Le compte détaillé et « Dettes » ne sont pas concernés. |
| H8 | Tableau d'explication et courbe : quelles dates | Un tableau par année, de la première année où la fortune existe à l'année en cours ; pour l'année en cours, il s'arrête **à ce jour**. La courbe donne la fortune à la fin de chaque mois, du premier solde au mois en cours. Une année antérieure au premier arbre de catégories a des résultats nuls : seuls ses soldes et ses dettes y figurent. |

**Commits** : même régime qu'en phases 0 à 4. Commits locaux sur des branches, un par étape, sans push. Messages en anglais, au format Conventional Commits, sujet de 50 caractères au plus, sans ligne `Co-Authored-By`. Le push, la version 0.6.0 et le déploiement sur le NAS se font à la fin, avec l'accord de l'utilisateur. Le serveur ne change que de version : il refusera ensuite les apps 0.5, qui garderaient les soldes et les dettes sans les montrer. Les apps 0.6.0 fonctionnent avec le serveur 0.5 en attendant.

## Principes

1. **La fortune se calcule, rien ne s'y enregistre.** Le journal ne reçoit que deux choses nouvelles : les soldes déclarés et les dettes. Solde d'un compte à une date, variations de valeur, fortune, courbe, lignes du tableau : tout est recalculé à chaque chargement.
2. **Un seul calcul des soldes.** La même fonction donne le solde d'un compte à n'importe quelle date ; la fortune du jour, la courbe et le tableau en découlent.
3. **Aucune ligne du tableau n'est un reste.** Chaque ligne se calcule pour elle-même, la variation de la fortune aussi (fortune de fin d'année moins fortune de fin d'année précédente). L'égalité est vérifiée par les tests sur des données tirées au hasard, pas obtenue par différence.
4. **Une variation de valeur n'est jamais un revenu ni une dépense.** Déclarer un solde ne crée aucune transaction et ne change aucun montant de la vue annuelle.
5. **Tout mouvement compte des deux côtés.** Un transfert sort d'un compte et entre dans l'autre ; une ligne à valider que ses règles proposent en transfert compte déjà comme ce transfert (principe 3 de la phase 3). Une transaction hors transfert compte dans la vue annuelle pour exactement son montant.
6. **Rien ne bloque.** Un solde déclaré laissé par une fusion sur un compte devenu détaillé, un transfert vers un compte supprimé sur un autre appareil : l'app compte ce qu'elle peut, et le reste apparaît dans une ligne du tableau, jamais dans un écart muet.
7. **Identifiants calculés** pour ce que deux appareils peuvent créer séparément : un solde déclaré (compte et date).
8. **Aucun nombre à virgule.** Le pourcentage d'une dette s'enregistre en centièmes de pour-cent, comme celui d'une redistribution ; mêmes arrondis.
9. **Aucune nouvelle bibliothèque.** La courbe est dessinée par l'app.
10. **Aucune donnée réelle dans le repo** : les exemples et les jeux d'essai sont inventés.

## Règles de calcul

Toutes les dates s'entendent en fin de journée.

- **Points de solde d'un compte** : ses soldes déclarés ; et, s'il a des relevés, le solde initial du premier, la veille de son début.
- **Mouvements d'un compte** : le montant des transactions du compte, et l'opposé de celui des transferts dont il est la contrepartie, validés ou proposés.
- **Solde à une date** : aucun avant le premier point (le compte n'est pas dans la fortune) ; ensuite, le dernier point à cette date ou avant, plus les mouvements datés après ce point, jusqu'à la date comprise.
- **Variation de valeur** d'un point, à partir du deuxième : son montant moins le solde attendu ce jour-là.
- **Dettes ouvertes à une date** : somme signée des totaux des dettes qui comptent ce jour-là (H5). Un compte de type « Dettes » n'a pas de solde propre.
- **Fortune à une date** : soldes des comptes qui en ont un, plus dettes ouvertes.

Tableau d'explication de l'année A :

| Ligne | Calcul |
|---|---|
| Résultat économique | Revenus moins dépenses de la vue économique de A |
| + Décalages de période | Payé en A pour d'autres années, moins payé d'autres années pour A (phase 4) |
| = Résultat de trésorerie | Revenus moins dépenses de la vue trésorerie de A |
| + Variations de valeur | Par compte : variations des points datés en A |
| + Comptes ajoutés | Par compte : montant du premier point, s'il est daté en A |
| + Variation des dettes ouvertes | Dettes ouvertes fin A moins fin A−1, moins les mouvements de A sur les comptes « Dettes » |
| + Non classé | « Non classé » de la vue annuelle de A |
| + Hors fortune (H3) | L'opposé des mouvements de A sur des comptes qui n'ont pas encore de solde, ou qui n'existent plus |
| = Variation de la fortune | Fortune fin A moins fortune fin A−1 |

Une année sans vue annuelle, antérieure au premier arbre, a ses trois premières lignes à zéro ; ses paiements hors transferts, s'il en reste après une fusion, y sont « Non classé ».

### Exemple de référence

Fin 2025 : le premier relevé du compte privé (détaillé) commence le 1.1.2026 avec 5'000.00 ; « Épargne » est déclarée à 10'000.00 au 31.12.2025. Fortune : 15'000.00.

En 2026, sur le compte privé : 60'000.00 de salaire ; 48'000.00 de dépenses, dont 2'100.00 de loyer payés le 1.9.2026 pour le 1.9.2026 – 31.8.2027, et 200.00 de restaurant avancés pour deux ; 6'000.00 virés vers « Épargne » ; 7'056.00 virés le 15.1 vers « 3e pilier », qui n'a pas encore de solde ; une ligne de −35.00 restée à compléter. « Épargne » est déclarée à 16'250.00 au 31.12.2026. « 3e pilier » reçoit son premier solde, 7'100.00, le 30.6.2026. Une dette « on me doit 100.00 » (200.00 à 50 %) est ouverte.

| Ligne | Montant |
|---|---|
| Résultat économique | 13'400.00 |
| + Décalages de période | −1'400.00 |
| = Résultat de trésorerie | 12'000.00 |
| + Variations de valeur (Épargne) | 250.00 |
| + Comptes ajoutés (3e pilier) | 7'100.00 |
| + Variation des dettes ouvertes | 100.00 |
| + Non classé | −35.00 |
| + Hors fortune (3e pilier) | −7'056.00 |
| = Variation de la fortune | 12'359.00 |

Fin 2026 : compte privé 3'909.00, « Épargne » 16'250.00, « 3e pilier » 7'100.00, dettes 100.00. Fortune : 27'359.00, soit 15'000.00 + 12'359.00.

## Étapes

Chaque étape est une branche locale et un commit, avec ses tests.

### 5.0 Préparation

- Reprise 1 : pour chaque transaction hors transfert, la vue annuelle compte exactement son montant. L'écart entre ce montant et ses lignes, possible seulement après une fusion, compte en « Non classé », où il se voit et se corrige en réenregistrant la transaction. Test : pour chaque année, résultat de trésorerie plus « Non classé » égale la somme des paiements hors transferts, y compris avec de tels écarts.
- Test : une base de la version 0.5.0 (règles de redistribution, remboursement rattaché, réponse à une part) s'ouvre avec la nouvelle version, données conservées.

### 5.1 Domaine : soldes déclarés

Dart pur, dans ses propres fichiers, comme la vue annuelle.

- Entité « solde déclaré » : compte, date, montant. Identifiant calculé à partir du compte et de la date : déclarer deux fois le même jour remplace.
- Déclarer, modifier, supprimer. Refusé, avec le motif : compte inconnu, compte détaillé, compte « Dettes », date dans le futur.
- Points de solde, mouvements, solde à une date, solde attendu et variation de valeur de chaque solde déclaré, selon les règles de calcul.
- Historique d'un compte : ses points, avec pour chacun le solde attendu, la variation et les mouvements depuis le point précédent.
- Suppression d'un compte selon H4.
- Tests : le critère de la spécification (écart en variation de valeur, vue annuelle inchangée) ; mouvement le jour d'un solde ; compte sans solde ; solde négatif ; transfert proposé ; solde resté sur un compte devenu détaillé ; deux appareils déclarant le même compte le même jour.

### 5.2 Domaine : dettes

- Entité « dette » : sens, personne, montant, pourcentage en centièmes de pour-cent, date de l'événement, date de la facture, date de la demande, date de réception, description, remboursé ; plus le jour de la saisie et le jour où elle a été cochée, écrits par l'app.
- Créer, modifier, supprimer, cocher et décocher, scinder (H6). Refus motivés : personne vide, montant nul ou négatif, pourcentage hors bornes, réception avant l'événement, part à scinder hors du total.
- Total d'une dette ; dettes ouvertes à une date (H5) ; totaux « on me doit », « je dois » et net.
- Tests : le critère de la spécification (le compte « Dettes » égale la somme des dettes non remboursées, à toute date) ; arrondi du total ; chaque borne de date ; scission au centime ; chaque refus. La scission d'une même dette sur deux appareils hors ligne est une limite connue, à consigner dans `docs/decisions.md`.

### 5.3 Domaine : fortune et tableau d'explication

- Fortune à une date : par compte, par type, total ; date du dernier point de chaque compte ; comptes sans solde.
- Série mensuelle (H8).
- Tableau d'explication d'une année, ligne par ligne, avec le détail par compte des variations de valeur, des comptes ajoutés et du « Hors fortune » ; années proposées (H8).
- Soldes anciens à une date donnée (H7).
- Tests : l'exemple de référence, ligne par ligne ; un prêt pur (transfert vers puis depuis « Dettes », dette ouverte puis cochée) laisse la fortune et la ligne des dettes à zéro ; une dépense avancée puis remboursée ; puis, sur des données tirées au hasard (comptes déclarés ou non, soldes, dettes, transferts vers « Dettes », transferts proposés, écarts de fusion), pour chaque année : la somme des lignes égale la variation de la fortune, et la série mensuelle égale la fortune calculée date par date.
- Mesure, avec les données de la phase 4 complétées de 12 comptes, 100 soldes déclarés et 200 dettes : rechargement après une écriture, chiffres clés de l'accueil compris, et calcul de l'écran « Fortune » (comptes, courbe de soixante mois, tableau d'une année). Consignée dans `docs/decisions.md`.

### 5.4 App : écran « Fortune » et comptes

- L'entrée « Fortune » de la navigation : fortune nette du jour et sa variation depuis le 31 décembre ; comptes par type, avec leur solde et la date de leur dernier solde ; marque « ancien » ; comptes sans solde, hors fortune ; ligne « Dettes ».
- Courbe mensuelle ; un point donne son mois et son montant.
- Tableau d'explication : choix de l'année ; les lignes par compte se déplient ; « Non classé » mène à la validation, les résultats à l'écran « Année ».
- Écran d'un compte : historique des soldes avec solde attendu et variation, mouvements ; « Déclarer un solde » (montant, date du jour par défaut), modifier, supprimer. Après la saisie, la variation de valeur s'affiche. Pour le compte détaillé : solde tiré des relevés, sans saisie.
- Accueil : tâche des soldes anciens (H7) ; la fortune nette rejoint les chiffres clés (décision H8 de la phase 4).
- Formats suisses.
- Tests d'interface : déclarer un solde et voir la variation ; l'écran « Fortune » avec ses comptes, sa courbe et le tableau de l'exemple de référence ; un solde de plus de 6 mois devient une tâche.

### 5.5 App : tableau des dettes

- Depuis « Fortune » : liste des dettes, ouvertes d'abord, avec personne, sens, total et dates ; totaux « on me doit », « je dois » et net.
- Formulaire : tous les champs de la spécification, total calculé à l'écran.
- Cocher « remboursé », décocher, scinder, supprimer.
- Tests d'interface : saisir une dette, la scinder, cocher une part ; la ligne « Dettes » de la fortune suit.

### 5.6 Documentation et version

- En anglais : `docs/wealth.md` (soldes, variations de valeur, dettes, tableau d'explication, avec l'exemple de référence) ; mise à jour de `batz-web/docs/architecture.md` et de `README.md` ; décisions prises en route dans `docs/decisions.md`.
- App et serveur en version 0.6.0 ; le serveur exige l'app 0.6.0.

## Critères d'acceptation

### Vérifiables par une commande sur la machine de développement

| Critère | Commande |
|---|---|
| Sur un compte déclaré, l'écart avec le solde attendu apparaît en variation de valeur ; les revenus, les dépenses et tous les montants de la vue annuelle sont les mêmes avant et après la déclaration. | `flutter test`, test des soldes |
| Solde déclaré de 10'000 le 31.12.2025, 500 reçus le 15.3.2026, solde déclaré de 10'800 le 30.6.2026 : solde de 10'500 du 15.3 au 29.6, variation de valeur de 300 datée du 30.6. | `flutter test`, test des soldes |
| Un solde est refusé sur le compte détaillé, sur un compte « Dettes » et dans le futur, avec son motif. | `flutter test`, test des soldes |
| Le total des dettes ouvertes est, à toute date, la somme des dettes non remboursées qui comptent ce jour-là ; une dette de 200 à 50 % vaut 100. | `flutter test`, test des dettes |
| Scinder une dette donne deux lignes dont les totaux font le total d'origine, au centime. | `flutter test`, test des dettes |
| L'exemple de référence du plan donne chaque ligne du tableau, et 12'359.00 de variation de la fortune. | `flutter test`, test de la fortune |
| Le tableau d'explication tombe juste au centime pour chaque année, sur des données tirées au hasard ; aucune ligne n'est calculée par différence. | `flutter test`, test de la fortune |
| Un prêt pur ne change ni la fortune ni la ligne des dettes ; une dépense avancée puis remboursée s'explique à chaque étape. | `flutter test`, test de la fortune |
| La fortune de chaque fin de mois de la courbe égale la fortune calculée à cette date. | `flutter test`, test de la fortune |
| Pour chaque année, résultat de trésorerie plus « Non classé » égale la somme des paiements hors transferts, écarts de fusion compris. | `flutter test`, test des vues |
| Soldes et dettes saisis sur un appareil arrivent sur un autre ; deux appareils déclarant le même compte le même jour écrivent un seul solde ; le test de convergence comprend les nouvelles opérations. | `flutter test`, tests de bout en bout |
| Avec 10 000 transactions sur cinq ans, 12 comptes, 100 soldes et 200 dettes : rechargement après une écriture en moins de 300 ms, calcul de l'écran « Fortune » en moins de 100 ms. | `flutter test`, test de performance |
| Une base de la version 0.5.0 s'ouvre avec la nouvelle version. | `flutter test`, test d'ouverture |
| Les parcours de l'écran « Fortune », de la déclaration d'un solde, du rappel d'un solde ancien et du tableau des dettes fonctionnent dans l'interface. | `flutter test`, tests d'interface |
| L'app ne présente aucun défaut d'analyse et tous ses tests passent. | `flutter analyze && flutter test` dans `batz-ui` |
| Le serveur passe ses tests et refuse une app 0.5. | `go vet ./... && go test -race ./...` dans `batz-web/src` |
| La version Ubuntu, l'APK et l'image du serveur se fabriquent. | `flutter build linux`, `flutter build apk`, `docker build` |
| Aucun fichier personnel ni terme personnel n'est suivi par git. | `scripts/check-personal-files.sh` |

### Vérifiables sur GitHub, après le push

- Tous les contrôles de la CI sont au vert, compilation Windows comprise.
- La publication de la version 0.6.0 produit l'APK signé, les versions Ubuntu et Windows et l'image du serveur.

### À vérifier par l'utilisateur, après installation de la version 0.6.0

- Le solde du compte bancaire affiché par « Fortune » est le solde final du dernier relevé importé.
- Les soldes réels des autres comptes, déclarés au 31.12.2025 puis à une date de 2026 : la variation de valeur s'affiche, et les dépenses de l'année ne changent pas.
- Le tableau d'explication de 2026 tombe juste, et chaque ligne se comprend.
- Une dette réelle saisie, scindée, puis cochée : la ligne « Dettes » suit.
- La courbe, sur le téléphone et sur l'ordinateur.
- Après le déploiement du serveur 0.6.0 sur le NAS : une app 0.5 est refusée, les apps 0.6.0 se synchronisent.

## Hors de cette phase

- Fiche salaire, diagramme de flux, impôts, vacances, électricité, abonnements : phase 6.
- Export, verrou Android, installation par Obtainium documentée : phase 7.
- Lien entre dettes et transactions, historique antérieur à 2026, comparaison entre années, deuxième compte détaillé : plus tard, sans engagement.

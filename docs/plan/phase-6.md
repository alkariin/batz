# Plan de la phase 6 — Modules

Référence : [specification.md](../specification.md), chapitres 3 (user story 11), 4.1, 4.6, 4.7, 6, 11, 13 et 14 ; règles de conception dans [decisions.md](../decisions.md) ; calcul de la vue annuelle dans [year-view.md](../year-view.md) ; calcul de la fortune dans [wealth.md](../wealth.md).

But de la phase : les écrans sur mesure de la spécification. Fiche salaire annuelle, diagramme de flux, impôts, vacances, électricité, abonnements. Le tableau des dettes, septième module de la spécification, est fait depuis la phase 5.

## État de départ

Contrôle de la phase 5 fait le 21 novembre 2026 :

- Analyse sans défaut et 423 tests de l'app au vert ; tests du serveur au vert avec le détecteur d'accès concurrents ; garde-fou des données personnelles au vert (fichiers suivis, textes des PDF et messages de commit) ; `main` local identique à GitHub ; CI au vert ; version 0.6.0 publiée avec ses quatre fichiers. Le déploiement du serveur 0.6.0 sur le NAS est consigné par la session d'implémentation ; il n'a pas été revérifié ici.
- Relus : le calcul des soldes, les dettes, la fortune et son tableau d'explication, les changements du grand livre et de la vue annuelle, `docs/wealth.md` et les décisions 5.0 à 5.6. Ils sont conformes au plan de la phase 5, à ses principes et aux décisions H1 à H8. L'égalité du tableau d'explication a été redémontrée à la main à partir du code. Les écrans n'ont pas été relus en détail ni lancés ; des tests, seuls les intitulés ont été relus.

Un point à reprendre, placé dans l'étape 6.0 :

1. **Un compte archivé dont le solde est 0 reste listé dans « Fortune ».** La décision H4 de la phase 5 dit qu'un solde de 0 sort un compte archivé de la fortune. Le total est juste, mais la ligne à 0.00 reste affichée pour toujours.

## Décisions de l'utilisateur pour cette phase

Validées le 21 novembre 2026. La spécification ne tranchait pas ces points ; aucune décision ne s'écarte de sa lettre.

| N° | Point | Décision |
|---|---|---|
| H1 | Catégorie liée à un module | Un nom par module, le même pour toutes les années (spécification). Noms par défaut : « Salaire », « Impôts », « Vacances », « Électricité ». Comparaison sans majuscules ni accents, comme entre années. La catégorie désignée peut être **un groupe** : le module prend alors tout ce qu'il contient. Si l'arbre d'une année n'a pas ce nom, le module le dit pour cette année, sans erreur. Un module compte les lignes comme la vue annuelle : une ligne à valider compte dès que ses règles la proposent, un remboursement rattaché suit sa dépense. La **redistribution ne s'applique pas** aux modules impôts, vacances et électricité : ils lisent les transactions classées dans la catégorie. |
| H2 | Fiche salaire | **Une fiche par année** ; avec deux employeurs, on additionne. À la création, les déductions proposées reprennent les libellés de la fiche de l'année précédente, à défaut AVS, AC et LPP. Écart = brut − déductions − net, affiché s'il n'est pas nul ; il n'empêche pas d'enregistrer. |
| H3 | Diagramme de flux | Il suit la bascule Trésorerie / Économique de l'écran « Année » et montre ses montants, redistribution comprise. À gauche : le salaire, puis un nœud par groupe de revenus de premier niveau. À droite : « Impôts », un nœud par **groupe de dépenses de premier niveau**, « Épargne ». Avec la fiche de l'année : « Salaire brut » se partage entre chaque déduction et le net. Dépenses supérieures aux revenus : un nœud « Puisé dans la fortune » à gauche, pas d'« Épargne ». « Non classé » n'entre pas dans le diagramme ; l'écran le rappelle. |
| H4 | Impôts | Cinq lignes fixes par année fiscale. Chaque ligne de revenu a sa base ; les deux lignes de fortune utilisent la fortune imposable, saisie une fois. Taux de base en pour-cent, 4 décimales au plus ; coefficient en pour-cent, 2 décimales au plus, 100 par défaut. Montant = base × taux de base × coefficient, **arrondi une seule fois**, au centime. Part du brut et du net : par rapport au **brut et au net de la fiche salaire** de la même année ; sans fiche, elles ne sont pas affichées. Contrôle : « payé pour l'année » est ce que la vue économique de l'année compte dans « Impôts » (acomptes, solde payé l'année suivante avec la période de l'année, remboursements en moins). Une année antérieure au premier arbre (2025) se saisit, sans contrôle. |
| H5 | Vacances : regroupement | Toutes les lignes de la catégorie, toutes années confondues. Deux lignes sont dans le même voyage si **l'écart entre leurs périodes est de 15 jours ou moins**, de proche en proche (du 24.7 au 8.8 : même voyage ; au 9.8 : un autre). Date du voyage : le premier jour de sa plus ancienne période. Montant : la somme de ses lignes entières, remboursements en moins. Un voyage à cheval sur deux années reste un voyage, rangé dans l'année de sa date. |
| H6 | Vacances : ce qui est saisi | Lieu, jours, date et montant remplacés sont gardés sur une **fiche accrochée à la première ligne du voyage**, qu'elle suit. Un montant remplacé reste fixe si d'autres transactions rejoignent le voyage ; la valeur automatique s'affiche à côté et « Rétablir » y revient. Si deux fiches se retrouvent sur un même voyage (une transaction arrivée entre deux voyages, ou deux appareils), celle de la ligne la plus ancienne s'applique ; l'autre est signalée et se supprime. Une fiche dont la ligne a quitté la catégorie est listée à part. Ligne manuelle : date et montant obligatoires. Prix par jour = montant ÷ jours. |
| H7 | Électricité | kWh saisis dans l'écran du module, ligne par ligne. Par année : prix total = total de la catégorie dans la vue économique ; les kWh d'une facture se répartissent entre les années **comme son montant** ; les jours sont ceux de l'année **couverts par au moins une période** (un acompte et un décompte sur les mêmes jours ne comptent qu'une fois). CHF par jour = prix ÷ jours ; CHF par kWh = prix ÷ kWh, 4 décimales ; kWh par jour = kWh ÷ jours, 2 décimales. L'écran indique le nombre de lignes sans kWh : s'il en manque, le CHF par kWh est surestimé. |
| H8 | Abonnements | Coût mensuel d'une tranche annuelle = montant ÷ 12, au centime ; coût annuel d'une tranche mensuelle = montant × 12. Les totaux sont la somme des coûts affichés. « En cours » : une tranche couvre aujourd'hui. Les tranches d'un abonnement ne se chevauchent pas ; ajouter une tranche ferme la précédente la veille, si elle n'avait pas de fin. Ordre : en cours, à venir, terminés. |

**Commits** : même régime qu'en phases 0 à 5. Commits locaux sur des branches, un par étape, sans push. Messages en anglais, au format Conventional Commits, sujet de 50 caractères au plus, sans ligne `Co-Authored-By`. Le push, la version 0.7.0 et le déploiement sur le NAS se font à la fin, avec l'accord de l'utilisateur. Le serveur ne change que de version : il refusera ensuite les apps 0.6, qui garderaient les saisies des modules sans les montrer. Les apps 0.7.0 fonctionnent avec le serveur 0.6 en attendant.

## Principes

1. **Un module lit, il ne recalcule pas.** Le classement d'une ligne (catégorie, proposition, remboursement rattaché, correspondance entre années) et sa répartition par mois viennent de la vue annuelle. Aucun module ne refait l'un ou l'autre.
2. **Seul ce qui est saisi s'enregistre.** Le journal reçoit les fiches salaire et leurs déductions, les années fiscales et leurs lignes, les fiches de voyage, les kWh, les abonnements et leurs tranches, les noms de catégories liées. Voyages, totaux, ratios, contrôle des impôts et diagramme sont recalculés.
3. **Aucun effet sur les comptes.** Aucun module n'écrit de transaction ni ne change un montant de la vue annuelle ou de la fortune.
4. **Rien ne bloque.** Catégorie introuvable, fiche de voyage dont la ligne a disparu, kWh restés sur une ligne sortie de la catégorie : l'écran le signale, sans erreur.
5. **Identifiants calculés** pour ce que deux appareils peuvent créer séparément : fiche salaire (année), année fiscale (année), ligne d'impôt (année et impôt), réglage (module), kWh (ligne), fiche de voyage (ligne d'accroche). Déductions, lignes manuelles de vacances, abonnements et tranches ont un identifiant tiré au hasard.
6. **Aucun nombre à virgule.** Montants en centimes, taux de base en dix-millièmes de pour-cent, coefficients et TMI en centièmes de pour-cent, énergie en Wh. Un seul arrondi par résultat, les moitiés à l'opposé de zéro.
7. **Aucune nouvelle bibliothèque.** Le diagramme est dessiné par l'app.
8. **Les modules se calculent à l'ouverture de leur écran**, pas à chaque rechargement.
9. **Aucune donnée réelle dans le repo** : les exemples et les jeux d'essai sont inventés.

## Règles de calcul

### Catégorie liée

Le nom désigné se cherche dans l'arbre de chaque année. La catégorie trouvée compte avec tout ce qu'elle contient. Selon le module :

- **dans une année** (impôts, électricité) : les montants que la vue économique de l'année place dans la catégorie, avant redistribution ;
- **toutes années confondues** (vacances) : les lignes classées dans la catégorie de l'arbre de leur année de paiement.

### Fiche salaire

Écart de la fiche = brut − somme des déductions − net.

Exemple : brut 96'000.00 ; AVS 5'088.00, AC 1'056.00, LPP 6'000.00, soit 12'144.00 de déductions ; net 83'856.00. Écart : 0.00. Avec un net saisi de 83'800.00, écart de 56.00.

### Diagramme de flux

Pour une année et la vue affichée. Chaque nœud a un montant positif ; un montant nul ne donne pas de nœud.

- **Montants** : ceux de l'écran « Année ». Une catégorie désignée vaut ce qu'elle pèse dans le total de son groupe, lignes de redistribution comprises ; son groupe est montré pour le reste, sous le nom « Groupe hors Catégorie ».
- **À droite** : « Impôts » ; chaque groupe de dépenses de premier niveau ; « À classer » des dépenses ; « Épargne » si les revenus dépassent les dépenses.
- **À gauche** : le salaire ; chaque groupe de revenus de premier niveau ; « À classer » des revenus ; « Puisé dans la fortune » si les dépenses dépassent les revenus.
- **Départ du brut** : quand la fiche de l'année existe et que la catégorie de salaire est trouvée, le nœud « Salaire brut » vaut le net reçu dans la catégorie plus les déductions de la fiche ; il se partage entre chaque déduction, à droite, et le net. Sinon le diagramme part du net.
- **Écart signalé** : net reçu plus déductions, moins le brut saisi.
- **Signes** : un groupe de dépenses dont le total est un gain passe à gauche ; un revenu négatif passe à droite.
- « Épargne » et « Puisé dans la fortune » viennent de la vue (revenus moins dépenses), pas d'un reste du diagramme. Les deux côtés ont le même total : les tests le vérifient.

Exemple, année 2026 : le groupe « Revenus » contient « Salaire » (83'856.00 reçus) et « Intérêts » (144.00). Dépenses : « Logement » 24'000.00, « Quotidien » 18'000.00, « Obligations » 21'000.00 dont « Impôts » 15'000.00. Revenus 84'000.00, dépenses 63'000.00, épargne 21'000.00.

| Côté | Avec la fiche de l'exemple | Sans fiche |
|---|---|---|
| Gauche | Salaire brut 96'000.00 ; Revenus hors Salaire 144.00 | Salaire 83'856.00 ; Revenus hors Salaire 144.00 |
| Droite | AVS 5'088.00 ; AC 1'056.00 ; LPP 6'000.00 ; Impôts 15'000.00 ; Logement 24'000.00 ; Quotidien 18'000.00 ; Obligations hors Impôts 6'000.00 ; Épargne 21'000.00 | Impôts 15'000.00 ; Logement 24'000.00 ; Quotidien 18'000.00 ; Obligations hors Impôts 6'000.00 ; Épargne 21'000.00 |
| Total de chaque côté | 96'144.00 | 84'000.00 |

Si 83'000.00 seulement ont été reçus dans « Salaire », le brut du diagramme vaut 95'144.00 et l'écart avec le brut saisi, −856.00, est signalé.

### Impôts

Pour une année fiscale :

- Lignes : revenu fédéral, revenu cantonal, revenu communal, fortune cantonale, fortune communale.
- Taux total d'une ligne = taux de base × coefficient, affiché avec 4 décimales.
- Montant d'une ligne = base × taux de base × coefficient, arrondi au centime. La base des deux lignes de fortune est la fortune imposable de l'année. Une ligne incomplète vaut 0.
- Total = somme des cinq montants.
- Part du brut = total ÷ brut de la fiche salaire de l'année ; part du net = total ÷ net de la fiche ; en pour-cent, 2 décimales.
- Payé pour l'année = ce que la vue économique de l'année compte dans la catégorie liée. Écart = total − payé : « reste à payer » ou « payé en trop ».

Exemple, année fiscale 2026, avec la fiche salaire de l'exemple :

| Ligne | Base | Taux de base | Coefficient | Taux total | Montant |
|---|---|---|---|---|---|
| Revenu fédéral | 80'000.00 | 2.5000 % | 100.00 % | 2.5000 % | 2'000.00 |
| Revenu cantonal | 78'000.00 | 6.5000 % | 155.00 % | 10.0750 % | 7'858.50 |
| Revenu communal | 78'000.00 | 6.5000 % | 79.00 % | 5.1350 % | 4'005.30 |
| Fortune cantonale | 200'000.00 | 0.2500 % | 155.00 % | 0.3875 % | 775.00 |
| Fortune communale | 200'000.00 | 0.2500 % | 79.00 % | 0.1975 % | 395.00 |
| **Total** | | | | | **15'033.80** |

Part du brut : 15.66 %. Part du net : 17.93 %.

Contrôle : dix acomptes de 1'200.00 payés en 2026 pour 2026 ; 3'000.00 payés le 15.4.2027 avec la période 2026 ; 2'500.00 payés en 2026 avec la période 2025. Payé pour 2026 : 15'000.00. Écart : 33.80, reste à payer. La vue trésorerie de 2026 montre 14'500.00 : le contrôle ne l'utilise pas.

### Vacances

- **Écart entre deux lignes** : le nombre de jours de la fin de la période de l'une au début de la période de l'autre ; 0 si les périodes se touchent ou se chevauchent.
- **Voyage** : un ensemble de lignes reliées de proche en proche par des écarts de 15 jours ou moins. Chaque ligne de la catégorie est dans un voyage et un seul.
- **Date automatique** : le premier jour de la plus ancienne période. **Montant automatique** : l'opposé de la somme des lignes.
- **Fiche d'un voyage** : celle dont la ligne d'accroche est dans le voyage ; s'il y en a plusieurs, celle dont la ligne est la plus ancienne. Elle donne le lieu, les jours, et s'ils sont remplacés, la date et le montant.
- **Prix par jour** = montant ÷ jours, au centime ; aucun sans jours.
- Une ligne manuelle est un voyage à elle seule.

Exemple : un billet d'avion de 640.00 payé le 12.3.2026 pour le 10.7 – 24.7.2026 ; un hôtel de 1'200.00 payé le 11.7 ; un restaurant de 85.00 payé le 20.7 ; 100.00 remboursés le 5.8 et rattachés à l'hôtel ; 300.00 payés le 9.8. Deux voyages : le premier du 10.7.2026, 1'825.00 ; avec 14 jours saisis, 130.36 par jour. Le second du 9.8.2026, 300.00, à 16 jours du premier. Sans sa période, le billet d'avion formerait un voyage du 12.3.2026.

### Électricité

Pour une année :

- **Prix total** : le total de la catégorie liée dans la vue économique de l'année.
- **kWh** : les kWh de chaque ligne sont répartis par mois comme son montant (même règle, la dernière part reçoit le reliquat) ; l'année reçoit les mois où le montant lui revient.
- **Jours** : le nombre de jours de l'année couverts par la période d'au moins une ligne.
- CHF par jour = prix ÷ jours ; CHF par kWh = prix ÷ kWh ; kWh par jour = kWh ÷ jours. Un ratio dont le diviseur est nul n'est pas affiché.

Exemple :

| Facture | Payée le | Période | Montant | kWh |
|---|---|---|---|---|
| 1 | 15.5.2026 | 1.1 – 30.4.2026 | 480.00 | 1'900 |
| 2 | 15.11.2026 | 1.5 – 31.10.2026 | 540.00 | 2'000 |
| 3 | 20.1.2027 | 1.11.2026 – 31.1.2027 | 300.00 | 1'200 |

| Année | Prix total | kWh | Jours | CHF par jour | CHF par kWh | kWh par jour |
|---|---|---|---|---|---|---|
| 2026 | 1'220.00 | 4'700 | 365 | 3.34 | 0.2596 | 12.88 |
| 2027 | 100.00 | 400 | 31 | 3.23 | 0.2500 | 12.90 |

La vue trésorerie de 2026 montre 1'020.00 : le module ne l'utilise pas.

### Abonnements

- Coût mensuel d'une tranche : son montant si elle est mensuelle, son montant ÷ 12 au centime si elle est annuelle. Coût annuel : son montant × 12 si elle est mensuelle, son montant si elle est annuelle.
- Un abonnement est en cours si une de ses tranches a commencé et n'est pas finie ; son coût est celui de cette tranche.
- Totaux : somme des coûts mensuels affichés, somme des coûts annuels affichés, abonnements en cours seulement.

Exemple, vu le 21.11.2026 : « Streaming », 12.90 par mois du 1.3.2025 au 31.12.2025 puis 14.90 par mois dès le 1.1.2026 ; « Assurance vélo », 95.00 par an dès le 1.6.2024 ; « Salle de sport », terminé le 30.9.2025.

| Abonnement | Par mois | Par an |
|---|---|---|
| Streaming | 14.90 | 178.80 |
| Assurance vélo | 7.92 | 95.00 |
| **Total** | **22.82** | **273.80** |

## Étapes

Chaque étape est une branche locale et un commit, avec ses tests. Le domaine est en Dart pur, dans ses propres fichiers, comme la vue annuelle et la fortune.

### 6.0 Préparation

- Reprise 1 : un compte archivé dont le solde est 0 n'est plus listé dans « Fortune ». Il reste accessible par les réglages des comptes.
- La vue annuelle donne en lecture ce dont les modules ont besoin, sans changer aucun montant : pour une catégorie d'une année et ce qu'elle contient, les lignes qui y comptent, avec leur montant, leur période et leurs parts par mois ; pour une catégorie désignée par son nom, les lignes classées dedans dans l'arbre de leur année de paiement.
- Entité « réglage de module » : module, nom de catégorie. Noms par défaut, recherche du nom dans l'arbre d'une année (H1).
- Test : une base de la version 0.6.0 (soldes déclarés, dettes dont une scindée) s'ouvre avec la nouvelle version, données conservées.

### 6.1 Fiche salaire

- Entités « fiche salaire » (année, brut, net) et « déduction » (fiche, libellé, montant, rang).
- Créer, modifier, supprimer ; ajouter, modifier et retirer une déduction. Refus motivés : brut nul ou négatif, net négatif, libellé vide, déduction négative.
- Écart de la fiche (H2).
- App : « Plus » gagne une section « Analyses », avant les réglages existants. Écran « Fiche salaire » : les années, le formulaire, l'écart ; le réglage de la catégorie de salaire.
- Tests : l'exemple ; chaque refus ; deux appareils créant la fiche de la même année ; les vues et la fortune inchangées.

### 6.2 Diagramme de flux

- Domaine : les nœuds des deux côtés, le départ du brut ou du net, l'écart signalé, selon les règles de calcul.
- App : bouton « Flux » sur l'écran « Année », pour l'année et la vue affichées ; l'écran du diagramme garde la bascule. Des bandes de gauche à droite, d'épaisseur proportionnelle au montant ; chaque nœud porte son nom et son montant ; sous le dessin, la liste des nœuds et de leurs montants. Lisible sur téléphone et sur ordinateur, thèmes clair et sombre.
- Tests : l'exemple, avec et sans fiche ; l'écart signalé ; dépenses supérieures aux revenus ; un groupe de dépenses en gain ; catégorie de salaire ou d'impôts introuvable ; sur des données tirées au hasard, pour chaque année et chaque vue, les deux côtés ont le même total et les nœuds redonnent les revenus, les dépenses et l'épargne de la vue.

### 6.3 Impôts

- Entités « année fiscale » (année, fortune imposable, TMI) et « ligne d'impôt » (année, impôt, base, taux de base, coefficient).
- Saisir, modifier, supprimer une année. Refus motivés : base négative, taux hors de 0 à 100 %, coefficient négatif, TMI hors de 0 à 100 %.
- Taux total, montants, total, parts du brut et du net, contrôle (H4).
- App : écran « Impôts » : choix de l'année fiscale, les cinq lignes, le total et ses parts, le TMI, le contrôle ; le récapitulatif par année (total, parts, TMI, payé, écart) ; le réglage de la catégorie.
- Tests : l'exemple, ligne par ligne ; le total égale la somme des lignes sur des données tirées au hasard ; le contrôle de l'exemple ; arrondis aux moitiés ; année sans fiche salaire ; année sans arbre ; deux appareils saisissant la même année.

### 6.4 Vacances

- Entité « fiche de voyage » : ligne d'accroche, lieu, jours, date et montant remplacés ; sans ligne d'accroche, c'est une ligne manuelle.
- Regroupement en voyages (H5) ; fiche qui s'applique, fiches en trop, fiches sans transaction (H6).
- Saisir le lieu et les jours ; remplacer et rétablir la date et le montant ; ajouter, modifier, supprimer une ligne manuelle. Refus motivés : jours inférieurs à 1, ligne manuelle sans date ou sans montant.
- App : écran « Vacances » : les voyages par année, les plus récents d'abord, avec date, lieu, jours, montant, prix par jour et le total de l'année ; le détail d'un voyage mène à ses transactions ; le réglage de la catégorie.
- Tests : l'exemple ; le billet d'avion avec et sans sa période ; 15 et 16 jours ; une transaction arrivée entre deux voyages les réunit ; une période ou une catégorie modifiée change l'affectation ; remplacer puis rétablir ; deux fiches sur un voyage ; sur des données tirées au hasard, chaque ligne de la catégorie est dans un voyage et un seul, et la somme des montants automatiques égale la somme des lignes.

### 6.5 Électricité

- Entité « relevé d'électricité » : ligne, énergie en Wh.
- Saisir, modifier, effacer les kWh d'une ligne. Refus motivé : kWh négatifs.
- Par année : prix total, kWh, jours et les trois ratios (H7) ; lignes sans kWh.
- App : écran « Électricité » : le tableau par année ; les lignes d'une année avec date, période, jours, montant et kWh ; le réglage de la catégorie.
- Tests : l'exemple, année par année ; un acompte et un décompte sur les mêmes jours ; une ligne sans kWh ; sur des données tirées au hasard, pour chaque année, le prix total égale le total de la catégorie dans la vue économique, et les kWh répartis font les kWh saisis.

### 6.6 Abonnements

- Entités « abonnement » (nom, note) et « tranche » (abonnement, montant, fréquence, début, fin).
- Créer, modifier, supprimer un abonnement et ses tranches. Refus motivés : nom vide, montant nul ou négatif, fin avant le début, tranches qui se chevauchent. Une nouvelle tranche ferme la précédente (H8).
- Coûts, état et totaux à une date.
- App : « Plus » → « Abonnements » : en cours, à venir, terminés ; coût par mois et par an ; les totaux ; le formulaire.
- Tests : l'exemple ; chaque refus ; changement de prix ; reprise après une fin ; deux tranches laissées en chevauchement par une fusion.

### 6.7 Documentation et version

- Mesure, avec les données de la phase 5 complétées de 300 lignes de vacances, 60 factures d'électricité avec kWh, 5 fiches salaire, 5 années fiscales et 40 abonnements de 3 tranches : rechargement après une écriture ; calcul de chaque écran de module et du diagramme. Consignée dans `docs/decisions.md`.
- Synchronisation : les saisies des modules passent par un vrai serveur ; le test de convergence comprend les nouvelles opérations.
- En anglais : `docs/modules.md` (règles de chaque module, avec les exemples) ; mise à jour de `batz-web/docs/architecture.md` et de `README.md` ; décisions prises en route dans `docs/decisions.md`.
- App et serveur en version 0.7.0 ; le serveur exige l'app 0.7.0.

## Critères d'acceptation

### Vérifiables par une commande sur la machine de développement

| Critère | Commande |
|---|---|
| La fiche salaire de l'exemple a un écart de 0.00 ; avec un net de 83'800.00, de 56.00. Une seule fiche par année, même saisie sur deux appareils. | `flutter test`, test de la fiche salaire |
| Le diagramme part du brut quand la fiche existe, du net sinon : l'exemple donne chaque nœud, 96'144.00 puis 84'000.00 de chaque côté. | `flutter test`, test du diagramme |
| L'écart avec le brut saisi est signalé ; des dépenses supérieures aux revenus donnent « Puisé dans la fortune ». | `flutter test`, test du diagramme |
| Sur des données tirées au hasard, pour chaque année et chaque vue, les deux côtés du diagramme ont le même total, et ses nœuds redonnent les revenus, les dépenses et l'épargne de la vue. | `flutter test`, test du diagramme |
| Le total d'impôts est égal à la somme des lignes ; l'exemple donne chaque ligne, 15'033.80, 15.66 % du brut et 17.93 % du net. | `flutter test`, test des impôts |
| Le contrôle utilise la période et non la date de paiement : 15'000.00 payés pour 2026, écart de 33.80. | `flutter test`, test des impôts |
| Un billet d'avion dont la période est celle du voyage rejoint ce voyage ; sans elle, il forme un autre voyage. L'exemple donne 1'825.00 et 130.36 par jour. | `flutter test`, test des vacances |
| Un écart de 15 jours réunit, 16 jours séparent ; l'affectation suit un changement de période ou de catégorie ; date et montant se remplacent et se rétablissent. | `flutter test`, test des vacances |
| Sur des données tirées au hasard, chaque ligne de la catégorie est dans un voyage et un seul. | `flutter test`, test des vacances |
| Le prix annuel de l'électricité est égal à celui de la vue économique, pour chaque année, sur des données tirées au hasard. | `flutter test`, test de l'électricité |
| L'exemple d'électricité donne, pour 2026 : 1'220.00, 4'700 kWh, 365 jours, 3.34, 0.2596 et 12.88 ; pour 2027 : 100.00, 400 kWh et 31 jours. Un acompte et un décompte sur les mêmes jours ne les comptent qu'une fois. | `flutter test`, test de l'électricité |
| L'exemple d'abonnements donne 22.82 par mois et 273.80 par an ; une tranche qui en chevauche une autre est refusée ; une nouvelle tranche ferme la précédente. | `flutter test`, test des abonnements |
| Le nom d'une catégorie liée se modifie et le module suit ; un groupe désigné compte avec ce qu'il contient ; un nom absent d'une année est signalé, sans erreur. | `flutter test`, test des réglages des modules |
| Aucune saisie d'un module ne change la vue annuelle ni la fortune. | `flutter test`, tests des modules |
| Les saisies des modules faites sur un appareil arrivent sur un autre ; deux appareils saisissant la même fiche salaire, la même année fiscale ou les kWh de la même ligne écrivent un seul enregistrement ; le test de convergence comprend les nouvelles opérations. | `flutter test`, tests de bout en bout |
| Avec 10 000 transactions sur cinq ans et les données de l'étape 6.7 : rechargement après une écriture en moins de 300 ms ; chaque écran de module et le diagramme calculés en moins de 100 ms. | `flutter test`, test de performance |
| Une base de la version 0.6.0 s'ouvre avec la nouvelle version. | `flutter test`, test d'ouverture |
| Les parcours de la fiche salaire, du diagramme, des impôts, des vacances, de l'électricité et des abonnements fonctionnent dans l'interface ; le diagramme s'affiche à la taille d'un téléphone et d'un ordinateur. | `flutter test`, tests d'interface |
| L'app ne présente aucun défaut d'analyse et tous ses tests passent. | `flutter analyze && flutter test` dans `batz-ui` |
| Le serveur passe ses tests et refuse une app 0.6. | `go vet ./... && go test -race ./...` dans `batz-web/src` |
| La version Ubuntu, l'APK et l'image du serveur se fabriquent. | `flutter build linux`, `flutter build apk`, `docker build` |
| Aucun fichier personnel ni terme personnel n'est suivi par git. | `scripts/check-personal-files.sh` |

### Vérifiables sur GitHub, après le push

- Tous les contrôles de la CI sont au vert, compilation Windows comprise.
- La publication de la version 0.7.0 produit l'APK signé, les versions Ubuntu et Windows et l'image du serveur.

### À vérifier par l'utilisateur, après installation de la version 0.7.0

- La fiche salaire réelle de l'année : l'écart est nul, ou s'explique.
- Le diagramme de 2026, sur le téléphone et sur l'ordinateur : il part du brut, et ses montants sont ceux de l'écran « Année ».
- Une année fiscale réelle : le total est proche de la décision de taxation, et le contrôle se comprend.
- Les voyages de 2026 : chaque transaction est dans le bon voyage, après correction des périodes au besoin.
- Les factures d'électricité réelles avec leurs kWh : le prix de l'année est celui de l'écran « Année ».
- Les abonnements réels : les totaux par mois et par an.
- Après le déploiement du serveur 0.7.0 sur le NAS : une app 0.6 est refusée, les apps 0.7.0 se synchronisent.

## Hors de cette phase

- Export, verrou Android, installation par Obtainium documentée : phase 7.
- Séparer ou réunir des voyages à la main, déplier un groupe dans le diagramme, plusieurs fiches salaire par année, lien entre abonnements et transactions, comparaison entre années : plus tard, sans engagement.
- Calcul d'impôt par barèmes officiels : exclu par la spécification.

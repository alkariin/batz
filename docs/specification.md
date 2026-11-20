# Spécification de batz

Statut : cahier des charges et architecture technique validés par le porteur du projet le 20 novembre 2026, à l'issue de la phase de découverte.

Ce document est la référence fonctionnelle et technique du projet. Il ne contient aucune donnée personnelle. Les textes de l'interface sont en français ; le code, les commentaires, les commits et la documentation technique écrite pendant le développement sont en anglais.

## 1. Vision et objectifs

batz est une app de comptabilité personnelle pour un seul utilisateur. Elle répond à trois questions : où va mon argent, combien me coûte réellement chaque année, et comment évolue ma fortune.

- **Deux dimensions par transaction** : la trésorerie (date et montant payés) et la période économique concernée.
- **Parcours principal** : importer chaque mois le relevé PDF de la banque, puis valider les transactions préclassées. La saisie manuelle est secondaire (espèces, autre carte).
- **Principes** : minimalisme, aucun écart inexpliqué avec la banque, aucun double comptage, fonctionnement complet hors ligne.
- **Cadre** : Android, Windows et Ubuntu, avec toutes les fonctions disponibles sur le téléphone ; serveur auto-hébergé sur le réseau domestique ; code public sous licence MIT ; aucun coût récurrent ; jamais sur un store.
- **Autres utilisateurs** : une autre personne installe sa propre instance, avec son serveur et ses données. Ce n'est pas un service partagé.

## 2. Cahier des charges fonctionnel

| Périmètre | Contenu |
|---|---|
| **MVP (phases 0 à 5)** | Comptes, arbres de catégories annuels, saisie manuelle, transferts, répartition par mois, synchronisation, import PostFinance, règles de mapping, validation, vue annuelle, vue fortune, dettes. |
| **Version 1.0 (phases 6 et 7)** | Fiche salaire et diagramme de flux, impôts, vacances, électricité, abonnements, export, verrou Android, mise à jour par Obtainium. |
| **Plus tard, sans engagement** | Comparaison entre années, ventilation d'une transaction, appariement de transferts entre comptes importés, historique antérieur à 2026, autres banques, synchronisation en arrière-plan, lien entre dettes et transactions. |
| **Exclu** | Compte commun et deuxième utilisateur (rien n'est préparé), plusieurs monnaies, calcul d'impôt par barèmes officiels, outil générique d'analyse, publication sur un store. |

Monnaie unique : le franc suisse. Un achat à l'étranger est enregistré pour le montant en francs débité par la banque. L'historique commence en janvier 2026.

## 3. User stories et parcours

### User stories

1. J'importe le relevé PDF du mois et je retrouve mes transactions préclassées, pour ne saisir que l'exception.
2. Je confirme en lot les propositions correctes, pour valider un mois en quelques minutes.
3. Je crée une règle depuis une transaction non reconnue, pour qu'elle soit classée seule la prochaine fois.
4. J'indique la période qu'un paiement concerne, pour que son coût soit réparti sur les bonnes années.
5. Je bascule entre vue trésorerie et vue économique, pour distinguer ce que j'ai payé de ce que l'année m'a coûté.
6. Je déclare le solde d'un compte une ou deux fois par an, pour suivre ma fortune sans tout saisir.
7. Je vois pourquoi ma fortune a varié, pour n'avoir aucun écart inexpliqué.
8. Je valide mes transactions dans le train, sans réseau, et je retrouve tout sur mon ordinateur après synchronisation.
9. Je perds mon téléphone : je le révoque, j'associe le nouveau et je récupère tout.
10. Je modifie librement mes catégories chaque année sans altérer les années passées.
11. Je suis mes impôts, mes vacances et mon électricité dans des écrans dédiés.
12. J'exporte toutes mes données dans un format lisible sans l'app.

### Parcours

- **Import mensuel** (à la maison, serveur allumé) : synchronisation, choix du compte et du PDF, extraction et vérifications, lignes « à valider ». La validation peut ensuite se faire n'importe où.
- **Mise à jour de la fortune** : saisie d'un solde et de sa date sur un compte ; la variation de valeur s'affiche.
- **Dépense en espèces** : saisie manuelle sur le compte « Espèces ».
- **Nouvelle année** : l'arbre est copié à la première transaction de l'année ; l'app interroge l'utilisateur si une part reportée n'a plus de catégorie.
- **Nouvel appareil ou serveur perdu** : association par code, puis récupération ou reconstruction complète.

## 4. Spécifications détaillées

### 4.1 Catégories

- Un arbre par année, créé par copie de l'année précédente (catégories, règles de mapping, règles de redistribution) à la première transaction datée de cette année. Il reste ensuite librement modifiable, sans effet sur les autres années.
- Un nom est unique dans tout l'arbre d'une année. Chaque groupe de premier niveau porte une nature : revenus ou dépenses.
- Entre années, deux catégories se correspondent si elles ont le même nom, quelle que soit leur position. Cette règle unique vaut pour les parts reportées, les modules et les comparaisons.
- La catégorie d'une transaction se choisit dans l'arbre de l'année de son paiement.
- Il n'existe pas de catégorie « Ignorer » : chaque ligne importée est classée dans une catégorie ou marquée comme transfert.
- L'épargne n'est pas une catégorie : elle est calculée (revenus moins dépenses). Le 3e pilier est un compte.
- Redistribution : une règle (source, cible, pourcentage) déplace dans les totaux, mois par mois, une part de la source vers la cible, sur une ligne distincte. Plusieurs règles possibles. Une catégorie cible ne peut pas être la source d'une autre règle. Exemple : 10 % de « Nourriture » vers « Entretien ménage ».

### 4.2 Transactions et périodes

- Champs : compte, date de paiement, montant signé, texte brut de la banque, description, note, statut (à compléter, proposée, validée), puis une ligne portant catégorie et période.
- Le modèle accepte plusieurs lignes par transaction ; l'app n'en gère qu'une.
- Le type se déduit, il n'est jamais saisi :
  - montant négatif dans une catégorie de dépense : dépense ;
  - montant positif dans une catégorie de dépense : remboursement, qui diminue la catégorie à sa propre date ;
  - catégorie de revenu : revenu ;
  - compte de contrepartie : transfert, sans catégorie.
- Un remboursement peut être rattaché à une dépense : il en reprend la catégorie et la période, et la dépense affiche son coût net.
- Le revenu enregistré est le salaire net reçu.
- Période par défaut : la date de paiement. Elle reste modifiable.
- **Répartition** : chaque mois de la période pèse 1, un mois entamé pèse sa fraction de jours. Les parts mensuelles sont arrondies au centime, la dernière reçoit le reliquat. La somme des parts est toujours égale au montant payé.
- **Vue trésorerie** : tout le montant à la date de paiement.
- **Vue économique** : les parts mensuelles, classées dans la catégorie de même nom de l'année concernée. Si elle n'existe pas, l'app demande où classer la part et mémorise la réponse.
- Saisie manuelle : montant, date (aujourd'hui par défaut), compte, catégorie, description.

### 4.3 Comptes

- Types : compte privé, épargne, 3e pilier, 2e pilier, investissements, véhicule, garantie de loyer, espèces, dettes, autre. Plusieurs comptes par type ; archivage possible sans perte d'historique.
- **Compte détaillé** : un compte est détaillé si et seulement si l'import y est activé. Un seul compte peut l'être dans le MVP. Ses transactions viennent uniquement des relevés : pas de saisie manuelle ni de suppression. La catégorie, la période, la description et la note sont modifiables ; le montant, la date, le compte et le texte brut sont immuables.
- **Compte au solde déclaré** (tous les autres) : soldes datés saisis librement ; mouvements facultatifs (transferts reçus d'un compte détaillé, saisies manuelles) ; dernier solde connu reporté. Le compte entre dans la fortune à son premier solde déclaré.
- **Variation de valeur** : l'écart entre un solde déclaré et le solde attendu (solde déclaré précédent, plus les entrées, moins les sorties). Elle n'entre jamais dans les revenus ni dans les dépenses.
- Un retrait d'espèces est un transfert vers le compte « Espèces ». Un achat de véhicule est un transfert vers son compte.
- Compte « Dettes » : somme des dettes non remboursées, non modifiable ailleurs que dans le tableau des dettes.

### 4.4 Import et validation

- L'import commence par une synchronisation. Le serveur extrait le PDF et vérifie sa cohérence interne : solde initial, mouvements, solde final, totaux imprimés. Il refuse un relevé déjà importé. Juste avant d'intégrer un import, il écrit une copie datée de sa base.
- L'app vérifie la continuité avec le relevé précédent : le solde initial est égal au solde final précédent, sans trou. Le premier relevé fixe le solde de départ du compte.
- Tout échec refuse le relevé entier, avec le motif. Rien n'est importé à moitié.
- Les lignes entrent dans le compte avec le statut « à valider ». Les lignes proposées comptent déjà dans leur catégorie ; les autres apparaissent en « Non classé ». Un indicateur rappelle le nombre de lignes à valider.
- Validation : les lignes « à compléter » une par une, les « proposées » corrigées si besoin puis confirmées en lot. Elle fonctionne hors ligne et peut être interrompue.
- Le PDF d'origine reste sur le serveur. Le texte brut de la banque est conservé ; la description modifiable en est une copie. Les pieds de page sont retirés des libellés.
- Chaque format de relevé est un module de code du serveur. Le seul format est PostFinance, en PDF et en français.

### 4.5 Règles de mapping

- Mots-clés tous requis, insensibles aux majuscules et aux accents ; un mot-clé peut être une expression régulière.
- Cible : une catégorie ou un transfert vers un compte.
- Modèle de période facultatif : mois précédent ou suivant, N mois après ou avant le paiement, année civile en cours ou précédente.
- Priorité : la règle qui a le plus de mots-clés gagne. En cas d'égalité, la ligne passe en « à compléter » avec les règles en concurrence.
- Les règles sont appliquées par l'app. Une règle se crée depuis l'écran de validation ; un écran dédié liste celles de l'année.
- Une règle créée ou modifiée se réapplique aux lignes non validées uniquement.

### 4.6 Vues

Navigation : cinq entrées, en barre inférieure sur téléphone et en menu latéral sur ordinateur.

- **Accueil** : tâches à faire (lignes à valider, règles en conflit, soldes déclarés anciens), état de la synchronisation (date de la dernière, modifications en attente), chiffres clés de l'année.
- **Transactions** : import, validation, saisie manuelle, liste avec recherche et filtres par texte, compte, catégorie, période et statut.
- **Année** : arbre avec montants, bascule Trésorerie / Économique, détail par mois (douze colonnes sur ordinateur, détail dépliable sur téléphone), accès aux transactions d'une catégorie, revenus, dépenses et épargne. Diagramme de flux.
- **Fortune** : fortune nette et comptes par type avec la date de chaque solde ; courbe mensuelle ; tableau d'explication de l'année ; tableau des dettes.
- **Plus** : analyses, abonnements, réglages (comptes, catégories et règles, synchronisation, export).

Tableau d'explication d'une année :

| Ligne | Contenu |
|---|---|
| Résultat économique | Revenus moins dépenses, selon les périodes concernées |
| + Décalages de période | Payé cette année pour d'autres années, moins payé d'autres années pour celle-ci |
| = Résultat de trésorerie | Revenus moins dépenses, selon les dates de paiement |
| + Variations de valeur | Compte par compte |
| + Comptes ajoutés | Premier solde déclaré d'un compte pendant l'année |
| + Variation des dettes ouvertes | Variation du total des dettes, moins les transferts nets vers « Dettes » |
| + Non classé | Tant qu'il reste des lignes à compléter |
| = Variation de la fortune | Fortune au 31 décembre moins fortune au 31 décembre précédent |

Style : Material 3, thèmes clair et sombre suivant l'appareil, une couleur d'accent. Formats suisses : 1'234.50 et 31.12.2026.

### 4.7 Modules

Chaque module est un écran sur mesure. Un nouveau sujet demande un développement. Les modules liés à une catégorie la désignent par son nom, modifiable dans leurs réglages.

- **Fiche salaire annuelle** : brut, liste libre de déductions (AVS, AC et LPP par défaut), net. L'app affiche l'écart si le brut moins les déductions ne donne pas le net. Aucun effet sur les comptes.
- **Diagramme de flux** : du revenu vers les impôts, les dépenses et l'épargne. Il part du brut : le net est le total reçu dans la catégorie de salaire désignée, les déductions s'y ajoutent, et un écart avec le brut saisi est signalé. Il part du net tant que la fiche n'est pas saisie.
- **Impôts** : par année fiscale, lignes revenu (fédéral, cantonal, communal) et fortune (cantonal, communal). L'utilisateur saisit les bases imposables, les taux de base et les coefficients ; la fortune imposable est saisie une fois. L'app calcule le taux total (taux de base multiplié par coefficient), les montants, le total et sa part du brut et du net. Le TMI est saisi. Le contrôle compare le total aux paiements de la catégorie « Impôts » dont la période est l'année fiscale. Un récapitulatif reprend les chiffres clés par année.
- **Vacances** : transactions de la catégorie liée, regroupées selon leur période concernée ; une transaction rejoint un voyage si elle est à 15 jours ou moins d'une autre transaction de ce voyage. La date et le montant sont automatiques, remplaçables à la main et rétablissables ; le lieu et le nombre de jours sont saisis ; le prix par jour est calculé. Les remboursements diminuent le montant. Des lignes entièrement manuelles sont possibles. L'affectation d'une transaction est recalculée quand sa période ou sa catégorie change.
- **Électricité** : kWh saisis de façon facultative par transaction ; jours déduits de la période. Une facture à cheval sur deux années est répartie au prorata de sa période (montant, kWh, jours). Par année : prix total, CHF par jour, CHF par kWh, kWh par jour. Le prix total est celui de la vue économique.
- **Dettes** : sens (on me doit, je dois), personne, montant, pourcentage, total, date de l'événement, date de la facture, date de la demande, date de réception, description, remboursé ou non. Le tableau est indépendant des transactions. Pas de remboursement partiel : la ligne est scindée. Une dette compte dans la fortune de la date de l'événement (à défaut, de sa saisie) à la date de réception (à défaut, du jour où elle est cochée). Une dépense avancée est une dépense normale suivie d'un remboursement ; un prêt pur est un transfert vers puis depuis « Dettes ».
- **Abonnements** : informatif, sans lien avec le reste. Nom, note, tranches (montant, mensuel ou annuel, début, fin facultative). Un changement de prix ou une reprise est une nouvelle tranche. L'écran affiche d'abord les abonnements en cours, avec leur coût ramené au mois et à l'année, et le total.

### 4.8 Export

Un ZIP de fichiers CSV couvrant toutes les données (transactions, comptes et soldes, arbres et règles, modules), produit à la demande sur n'importe quel appareil, hors ligne, sans réimport.

## 5. Architecture technique et justification

| Choix | Justification |
|---|---|
| **App Flutter**, avec Bloc et Dio | Une base de code pour trois plateformes ; conventions du projet homl. |
| **Base locale SQLite**, chiffrée sur Android | Calculs hors ligne sur toutes les données ; copie complète par appareil. |
| **Tous les calculs dans l'app** | Le serveur n'est allumé que par intermittence ; une seule implémentation des règles. |
| **Serveur Go**, avec Gin, en un seul conteneur | Léger pour un NAS modeste ; conventions du projet homl. |
| **SQLite côté serveur** | Un fichier, pas de serveur de base à faire tourner. |
| **Journal de modifications** | Conflits résolus champ par champ ; traçabilité ; serveur reconstructible. |
| **HTTPS à certificat auto-généré** | Chiffrement sur le réseau domestique sans nom de domaine. |
| **Montants en centimes entiers** | Aucune erreur d'arrondi liée aux nombres à virgule. |
| **Identifiants générés sur l'appareil** | Création hors ligne sans identifiants temporaires. |

Le serveur n'a que trois tâches : extraire et vérifier un relevé PDF, conserver la copie de référence du journal, stocker les PDF d'origine.

Synchronisation :
- Chaque modification est une entrée de journal : tel champ de tel enregistrement a pris telle valeur, à tel moment, sur tel appareil.
- Lors d'une synchronisation, l'appareil envoie ses nouvelles entrées et reçoit celles des autres.
- Conflit : champ par champ, la modification la plus récente gagne. Une suppression est une entrée comme une autre.
- Déclenchement : automatique quand l'app est ouverte et le serveur joignable, et par un bouton. Pas de synchronisation en arrière-plan.
- Le serveur peut être reconstruit à partir de n'importe quel appareil.

## 6. Schéma de données

| Entité | Champs principaux | Relations |
|---|---|---|
| Account | nom, type, format d'import, archivé | |
| BalanceDeclaration | date, montant | Account |
| Category | année, nom, nature, position | parent Category |
| Rule | année, mots-clés, modèle de période | cible Category ou Account |
| RedistributionRule | année, pourcentage | source et cible Category |
| Statement | période, soldes initial et final, empreinte du fichier | Account |
| Transaction | date, montant, texte brut, description, note, statut | Account, Statement, compte de contrepartie |
| TransactionLine | montant, début et fin de période | Transaction, Category, ligne remboursée |
| LineYearCategory | année | TransactionLine, Category |
| Debt | sens, personne, montant, pourcentage, quatre dates, remboursé | |
| Subscription, SubscriptionTranche | nom, note ; montant, fréquence, début, fin | |
| SalarySheet, SalaryDeduction | année, brut, net ; libellé, montant | |
| TaxYear, TaxLine | année, fortune imposable, TMI ; impôt, base, taux, coefficient | |
| Trip | lieu, jours, valeurs remplacées | TransactionLine |
| ElectricityReading | kWh | TransactionLine |
| ModuleSetting | module, nom de catégorie | |
| Change (journal) | entité, champ, valeur, horodatage, appareil | |
| Device (serveur) | nom, clé hachée, révoqué | |

## 7. Architecture de l'app et du serveur

**App**
- `domain` : Dart pur, sans dépendance à Flutter. Répartition, règles, totaux, fortune, modules.
- `data` : base locale, journal, moteur de synchronisation, client du serveur.
- `pages` et `components` : écrans et cubits, composants partagés.

**Serveur**, en couches
- `domain` : appareil, entrée de journal, relevé.
- `application` : association, synchronisation, import.
- `infrastructure` : routes HTTP, stockage SQLite, extraction (un module par format), certificat.

## 8. API et intégrations

| Route | Rôle |
|---|---|
| `GET /healthz` | État, version, version minimale de l'app. |
| `POST /api/v1/pairing` | Échange un code contre une clé d'appareil. |
| `GET` et `DELETE /api/v1/devices` | Lister et révoquer les appareils. |
| `POST /api/v1/sync` | Envoyer ses entrées de journal, recevoir celles des autres. |
| `POST /api/v1/imports` | Envoyer un PDF, recevoir les lignes extraites et vérifiées. |
| `GET /api/v1/imports/{id}/pdf` | Récupérer le PDF d'origine. |

Seule intégration externe : `pdftotext`, embarqué dans l'image du serveur. Aucun service tiers.

## 9. Sécurité et permissions

- Un seul utilisateur, pas de login. Chaque appareil est associé une fois par un code et reçoit sa propre clé, révocable.
- Échanges chiffrés en HTTPS. Le serveur crée son certificat ; l'app mémorise son empreinte à l'association et refuse tout autre certificat. L'app se connecte par adresse IP, modifiable dans les réglages.
- Android : verrou par empreinte ou code de l'appareil, base locale chiffrée, clé gardée par le système. Ordinateurs : protection du système.
- Serveur non exposé à Internet. Conteneur sans privilèges.
- Aucun secret ni donnée personnelle dans le repo. La clé de signature Android est dans les secrets GitHub.
- La perte des PDF d'origine est acceptable ; aucune sauvegarde hors du domicile n'est exigée.

## 10. Arborescence prévisionnelle

```
batz/
├── batz-ui/
│   ├── lib/
│   │   ├── domain/
│   │   ├── data/
│   │   ├── pages/
│   │   ├── components/
│   │   ├── helpers/
│   │   └── l10n/
│   ├── test/
│   ├── integration_test/
│   └── android/  linux/  windows/
├── batz-web/
│   ├── src/
│   │   ├── main.go
│   │   └── internal/
│   │       ├── domain/
│   │       ├── application/
│   │       └── infrastructure/
│   │           ├── web/
│   │           ├── persistence/
│   │           ├── extraction/postfinance/
│   │           └── tlscert/
│   ├── db/migrations/
│   ├── scripts/deploy-nas.sh
│   ├── docs/
│   ├── Dockerfile
│   └── docker-compose.example.yml
├── .github/workflows/
├── docs/specification.md
├── LICENSE
└── README.md
```

Les scripts Python d'origine servent de référence pour l'extraction, puis sortent du repo. Les relevés et les fichiers de configuration personnels restent hors versionnement.

Nom affiché : batz. Identifiant Android : `dev.batz.app`.

## 11. Stratégie de tests

1. **Calculs** : tests exhaustifs ; chaque règle du chapitre 4 est un test, avec ses cas limites.
2. **Extraction** : relevés fictifs dans le repo ; vérification locale sur les vrais relevés, jamais versionnés.
3. **Synchronisation** : plusieurs appareils simulés, conflits, suppressions, reconstruction du serveur.
4. **Interface** : parcours principal uniquement.
5. **Automatisation** : tous les tests à chaque modification.

## 12. Phases et déploiement

| Phase | Contenu |
|---|---|
| 0. Socle | Repo, tests automatiques, squelettes, base locale, journal, association en HTTPS. |
| 1. Comptes et catégories | Comptes, arbres annuels, saisie manuelle, transferts, répartition. |
| 2. Synchronisation | Échange du journal, conflits, révocation, reconstruction. |
| 3. Import et validation | Extraction, vérifications, règles, validation en lot. |
| 4. Vue annuelle | Arbre, bascule, détail par mois, redistribution, remboursements. |
| 5. Fortune | Soldes déclarés, variations, dettes, vue fortune. **Fin du MVP.** |
| 6. Modules | Fiche salaire, flux, impôts, vacances, électricité, abonnements. |
| 7. Finitions | Export, verrou Android, Obtainium, documentation. **Version 1.0.** |

Fabrication : GitHub Actions lance les tests à chaque modification et fabrique, à chaque version, l'APK signé et les versions Windows et Ubuntu. L'image du serveur est publiée sous forme de fichier ; un script la copie sur le NAS par SSH et la charge. L'app vérifie à chaque synchronisation que sa version et celle du serveur sont compatibles. Les mises à jour sont manuelles.

Amendement validé le 20 novembre 2026 : la signature de l'APK est mise en place dès la phase 0, pour que toutes les versions installées sur le téléphone portent la même clé.

## 13. Critères d'acceptation

**Phase 0**
- L'app s'installe sur Android, Windows et Ubuntu et affiche les cinq entrées.
- Un appareil s'associe au serveur par code ; un appareil révoqué est refusé.
- Un serveur qui présente un autre certificat est refusé.
- Les tests tournent automatiquement à chaque modification.

**Phase 1**
- 2'100 CHF du 1.9.2026 au 31.8.2027 donnent 700 en 2026 et 1'400 en 2027.
- Une période du 14 mars au 13 mars suivant totalise exactement douze mois.
- La somme des parts est toujours égale au montant payé.
- Deux catégories de même nom dans une année sont refusées.
- Un transfert n'apparaît ni en revenu ni en dépense.

**Phase 2**
- Deux modifications de champs différents d'une même transaction, faites hors ligne sur deux appareils, sont toutes deux conservées.
- Deux modifications du même champ : la plus récente gagne sur tous les appareils.
- Une suppression se propage.
- Un serveur vide est reconstruit depuis un appareil, et un autre appareil s'y resynchronise sans perte.

**Phase 3**
- Les relevés réels de 2026 s'importent, avec des soldes identiques à ceux imprimés.
- Un relevé incohérent, déjà importé ou non contigu est refusé en entier, avec son motif.
- Une règle à deux mots-clés l'emporte sur une règle à un mot-clé ; une égalité est signalée.
- Une règle créée pendant la validation classe aussitôt les autres lignes non validées, sans toucher aux lignes validées.
- La validation fonctionne hors ligne.

**Phase 4**
- Pour une même année, les deux vues ne diffèrent que par les décalages de période.
- 10 % de « Nourriture » apparaît dans « Entretien ménage », mois par mois, sur une ligne distincte.
- Un remboursement rattaché réduit le coût de sa dépense, dans la période de celle-ci.
- Une part reportée sans catégorie de même nom déclenche une question.

**Phase 5**
- Sur un compte déclaré, l'écart avec le solde attendu apparaît en variation de valeur et jamais en dépense.
- Le tableau d'explication tombe juste au centime pour chaque année.
- Le compte « Dettes » est égal à la somme des dettes non remboursées.

**Phase 6**
- Le total d'impôts est égal à la somme des lignes ; le contrôle utilise la période et non la date de paiement.
- Un billet d'avion dont la période est celle du voyage rejoint ce voyage.
- Le prix annuel de l'électricité est égal à celui de la vue économique.
- Le diagramme part du brut quand la fiche existe, du net sinon.

**Phase 7**
- L'export s'ouvre dans un tableur et contient toutes les données.
- L'app Android exige le déverrouillage à l'ouverture.
- Une nouvelle version s'installe par-dessus la précédente sans perte.

## 14. Points à vérifier, risques et valeurs par défaut

**À vérifier en phase 0, avant d'aller plus loin**
- Une même bibliothèque de base fonctionnant chiffrée sur Android et en clair sur les ordinateurs.
- Le pilote SQLite sans dépendance système côté Go, compatible avec golang-migrate.
- La gratuité de GitHub Actions pour un repo public, machines Windows comprises.

**Risques connus**
- Le diagramme de flux est à dessiner sur mesure.
- L'ordre des modifications dépend de l'heure des appareils.
- La mise en page du relevé PostFinance peut changer.

**Valeurs par défaut**
- 12 copies de la base du serveur conservées.
- Un solde déclaré est signalé comme ancien après 6 mois.
- Code d'association valable 10 minutes.
- Certificat du serveur valable 10 ans.

**Question laissée ouverte** : un compte commun ou un deuxième utilisateur dans le ménage. Rien n'est construit ni préparé pour cela.

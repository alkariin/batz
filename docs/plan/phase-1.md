# Plan de la phase 1 — Comptes et catégories

Référence : [specification.md](../specification.md), chapitres 4.1 à 4.3, 6, 11 et 13.

But de la phase : l'app devient utilisable seule, sur un appareil. On y crée ses comptes, son arbre de catégories de l'année, des dépenses et revenus saisis à la main, des transferts, et on indique la période qu'un paiement concerne. Rien ne se synchronise encore et rien ne s'importe : phases 2 et 3.

Le serveur n'est pas modifié dans cette phase.

## État de départ

Contrôle de la phase 0 fait le 20 novembre 2026 :

- Tests du serveur et de l'app au vert sur la machine de développement, CI au vert sur `main`, compilation Windows comprise.
- Serveur du NAS joignable en HTTPS.
- Installation, association et révocation vérifiées par l'utilisateur sur Ubuntu et sur Windows.
- **Reste ouvert, par choix de l'utilisateur** : l'installation sur le téléphone Android, reportée à la première version publiée sur GitHub. D'ici là, la base chiffrée n'a tourné sur aucun appareil réel, et aucun test automatique ne peut la couvrir. Cela ne bloque pas la phase 1.

## Décisions de l'utilisateur pour cette phase

Validées le 20 novembre 2026. La spécification ne tranchait pas les points H1 à H6.

| N° | Point | Décision |
|---|---|---|
| H1 | Comparaison des noms de catégories | Sans tenir compte des majuscules, des accents ni des espaces autour : « Impôts » et « impots » sont le même nom. La même comparaison sert à la correspondance entre années. |
| H2 | Où se classe une transaction | Uniquement dans une catégorie sans enfant. Un groupe additionne ses enfants et ne reçoit rien directement. Ajouter un enfant à une catégorie qui porte déjà des transactions est refusé, avec le motif. |
| H3 | Signe d'une saisie manuelle | Le montant se saisit sans signe. Il sort du compte par défaut dans une catégorie de dépense, il y entre par défaut dans une catégorie de revenu. Un interrupteur « Entrée / Sortie » inverse le sens : c'est ainsi qu'on saisit un remboursement. |
| H4 | Premier arbre | L'arbre de 2026 part de deux groupes vides, « Revenus » et « Dépenses », à compléter à la main. |
| H5 | Suppression | Un compte ou une catégorie ne se supprime que si aucune transaction ne l'utilise. Sinon, le compte s'archive et la suppression de la catégorie est refusée, avec le nombre de transactions concernées. |
| H6 | Année source de la copie | L'arbre d'une année est copié depuis l'année antérieure la plus proche qui en possède un. L'écran des catégories permet aussi de créer à la main l'arbre de l'année suivante, par la même copie. |

**Commits** : même régime qu'en phase 0. Commits locaux sur des branches, un par étape, sans push. Messages en anglais, au format Conventional Commits, sujet de 50 caractères au plus, sans ligne `Co-Authored-By`. Le push se fait à la fin de la phase, avec l'accord de l'utilisateur ; la compilation Windows n'est vérifiée par la CI qu'à ce moment-là.

## Règles de conception de cette phase

Elles découlent du journal mis en place en phase 0 et valent pour toutes les phases suivantes.

1. **Les tables dérivées n'ont aucune contrainte** d'unicité, de clé étrangère ou de valeur obligatoire. Les règles métier sont vérifiées par le domaine au moment de la saisie. Raison : à partir de la phase 2, les entrées d'un autre appareil arrivent champ par champ, dans n'importe quel ordre ; leur intégration ne doit jamais échouer.
2. **Un enregistrement incomplet est ignoré à la lecture**, sans erreur.
3. **Les tables dérivées ne migrent pas** : à chaque changement de schéma, elles sont supprimées, recréées, puis recalculées depuis le journal. Seules les tables du journal ont de vraies migrations.
4. **La copie d'un arbre donne des identifiants calculés** à partir de la catégorie d'origine et de l'année cible. Deux appareils qui copient le même arbre hors ligne produisent ainsi les mêmes enregistrements, et non deux arbres en double.
5. **Les dates sont des dates de calendrier**, enregistrées en texte `AAAA-MM-JJ`, sans heure ni fuseau.
6. **Aucun nombre à virgule dans les calculs** : montants en centimes entiers, poids des mois en fractions exactes.

## Étapes

Chaque étape est une branche locale et un commit, avec ses tests.

### 1.0 Reprises de la phase 0

- Horloge logique : quand le compteur est plein, elle passe à la milliseconde suivante au lieu d'échouer. Aujourd'hui, un appareil dont l'horloge avance de beaucoup pourrait, après synchronisation, finir par bloquer les écritures des autres.
- Mise en place de la règle 3 : recalcul des tables dérivées à chaque changement de schéma.
- Test : une base créée par la version 0.1.0 s'ouvre avec la nouvelle version, identifiant d'appareil conservé.

### 1.1 Répartition

Domaine, Dart pur. Fonction : montant, début et fin de période → parts mensuelles.

- Chaque mois complet pèse 1 ; un mois entamé pèse ses jours couverts divisés par ses jours.
- Parts arrondies au centime, la dernière reçoit le reliquat.
- Un montant négatif donne l'opposé exact des parts du montant positif.
- Une fin antérieure au début est refusée.
- Tests : les deux exemples de la spécification, un seul jour, un mois entamé, février d'une année bissextile, 1 centime sur douze mois, et la somme des parts sur des montants et des périodes tirés au hasard.

### 1.2 Comptes

- Champs : nom, type (les dix types de la spécification), format d'import, archivé.
- Un compte est détaillé si l'import y est activé ; un seul compte peut l'être.
- Écran « Comptes » dans « Plus » : liste, création, modification, archivage, suppression selon H5.

### 1.3 Catégories et arbres annuels

- Champs : année, nom, parent, nature (groupes de premier niveau), position.
- Règles : nom unique dans l'arbre de l'année (H1) ; nature héritée du groupe de premier niveau ; un déplacement ne peut pas créer de boucle.
- Copie de l'arbre à la première transaction datée d'une année sans arbre (H6, règle 4). Les règles de mapping et de redistribution s'ajouteront à la copie en phases 3 et 4.
- Écran « Catégories » dans « Plus » : choix de l'année, arbre, ajout, renommage, déplacement, ordre, suppression selon H5.

### 1.4 Transactions et transferts

- Transaction : compte, date de paiement, montant signé, compte de contrepartie, description, note, statut. Ligne : catégorie, montant, début et fin de période. Une ligne par transaction dans l'app.
- Type déduit, jamais enregistré : dépense, remboursement, revenu, transfert.
- Une saisie manuelle est enregistrée « validée ». Elle est refusée sur le compte détaillé et sur un compte de type « dettes », conséquence du chapitre 4.3.
- Transfert : un seul enregistrement, sur le compte de départ, avec le compte d'arrivée en contrepartie ; pas de catégorie ; deux comptes différents.
- Totaux de trésorerie par catégorie pour une année, dans le domaine : ils servent au critère « un transfert n'apparaît ni en revenu ni en dépense » et seront repris par la vue annuelle en phase 4.

### 1.5 Écran « Transactions »

- Liste par date décroissante, avec le type et la catégorie ; filtre par compte et par année.
- Saisie d'une dépense ou d'un revenu : montant, sens (H3), date (aujourd'hui par défaut), compte, catégorie de l'année de la date, description, note.
- Saisie d'un transfert : montant, date, compte de départ, compte d'arrivée.
- Période : par défaut la date de paiement ; modifiable par un début et une fin. Le détail affiche les parts par mois et le total par année.
- Modification et suppression d'une saisie manuelle.
- Test d'interface du parcours principal : créer un compte, une catégorie, une dépense, et la retrouver dans la liste.

### 1.6 Documentation et version

- En anglais : mise à jour de `README.md` et de `batz-web/docs/architecture.md` ; règles de conception ci-dessus et décisions prises en route dans `docs/decisions.md`.
- Version de l'app portée à 0.2.0.

## Critères d'acceptation

### Vérifiables par une commande sur la machine de développement

| Critère | Commande |
|---|---|
| 2'100 CHF du 1.9.2026 au 31.8.2027 donnent 700 en 2026 et 1'400 en 2027. | `flutter test`, test de répartition |
| Une période du 14 mars au 13 mars suivant totalise exactement douze mois. | `flutter test`, test de répartition |
| La somme des parts est égale au montant payé, sur des montants et des périodes tirés au hasard, positifs et négatifs. | `flutter test`, test de répartition |
| Deux catégories de même nom dans une année sont refusées, selon H1. | `flutter test`, test des catégories |
| Deux copies du même arbre, faites sur deux appareils simulés, donnent les mêmes enregistrements après fusion des journaux. | `flutter test`, test des catégories |
| Un transfert n'apparaît ni en revenu ni en dépense. | `flutter test`, test des totaux |
| Une saisie manuelle sur le compte détaillé est refusée ; un deuxième compte détaillé est refusé. | `flutter test`, tests des comptes et des transactions |
| Après recalcul depuis le journal, les tables des comptes, catégories et transactions sont identiques. | `flutter test`, test du journal |
| Une base de la version 0.1.0 s'ouvre avec la nouvelle version. | `flutter test`, test d'ouverture |
| Le parcours principal fonctionne dans l'interface. | `flutter test`, test d'interface |
| L'app ne présente aucun défaut d'analyse et tous ses tests passent. | `flutter analyze && flutter test` dans `batz-ui` |
| Le serveur, non modifié, passe toujours ses tests. | `go vet ./... && go test -race ./...` dans `batz-web/src` |
| La version Ubuntu et l'APK se compilent. | `flutter build linux`, `flutter build apk` |
| Aucun fichier personnel n'est suivi par git. | `scripts/check-personal-files.sh` |

### Vérifiables sur GitHub, après le push

- Tous les contrôles de la CI sont au vert, compilation Windows comprise.

### À vérifier par l'utilisateur

- Sur Ubuntu et sur Windows, la nouvelle version s'installe par-dessus la précédente, sans refaire l'association au serveur.
- Créer le compte « Espèces », l'arbre 2026, une dépense en espèces, un transfert.
- Un paiement réparti sur deux années affiche ses parts par mois et son total par année.
- Sur le téléphone : les mêmes vérifications, dès qu'une version est publiée.

## Hors de cette phase

- Synchronisation entre appareils : phase 2. Jusque-là, chaque appareil garde ses propres données ; ce qui est saisi pendant la phase 1 sera envoyé au serveur à la première synchronisation.
- Import, texte brut de la banque, statuts « à compléter » et « proposée », règles de mapping : phase 3.
- Vue annuelle, vue économique entre années, redistribution, rattachement d'un remboursement à sa dépense : phase 4.
- Soldes déclarés, variations de valeur, dettes, vue fortune : phase 5.

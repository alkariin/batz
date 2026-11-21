# Plan de la phase 7 — Finitions

Référence : [specification.md](../specification.md), chapitres 2, 3 (user stories 9 et 12), 4.6, 4.8, 9, 12 et 13 ; règles de conception dans [decisions.md](../decisions.md) ; installation et mise à jour dans [deployment.md](../../batz-web/docs/deployment.md).

But de la phase : les finitions que la spécification prévoit pour la version 1.0. Export de toutes les données, verrou de l'app Android, mise à jour par Obtainium vérifiée et documentée, documentation pour qui installe sa propre instance. Elles sont publiées en version **0.8.0-alpha** : la version 1.0.0 attendra les modifications que l'utilisateur prévoit encore (H6).

## État de départ

Contrôle de la phase 6 fait le 21 novembre 2026 :

- Analyse sans défaut et 489 tests de l'app au vert ; tests du serveur au vert avec le détecteur d'accès concurrents ; garde-fou des données personnelles au vert (fichiers suivis, textes des PDF et messages de commit) ; `main` local identique à GitHub ; CI et publication au vert ; version 0.7.0 publiée avec ses quatre fichiers. Le serveur du NAS répond en version 0.7.0 et exige l'app 0.7.0 (lecture de `/healthz`).
- Relus : les calculs des six modules, ce que la vue annuelle leur donne en lecture, la lecture des nouvelles tables, `docs/modules.md` et les décisions 6.0 à 6.7. Ils sont conformes au plan de la phase 6, à ses principes et aux décisions H1 à H8. Recalculés à la main : le diagramme de l'exemple (96'144.00 de chaque côté), une ligne d'impôt, l'électricité des deux années, les abonnements. Les écrans n'ont pas été relus en détail ni lancés ; des tests, seuls les intitulés ont été relus.

Aucun point à reprendre. Trois constats pour cette phase :

1. **L'app porte l'icône par défaut de Flutter**, sur Android et sur Windows.
2. **L'app n'affiche nulle part sa propre version.** Après une mise à jour, rien ne dit laquelle est installée.
3. **Le verrou ne peut pas être essayé sur la machine de développement.** Elle n'a pas la virtualisation matérielle qu'un émulateur Android demande. La logique du verrou est testée avec un téléphone simulé ; le comportement réel se vérifie sur le téléphone, après installation. Un défaut se corrigerait par une version 0.8.1-alpha, comme la 0.4.1 l'a fait pour la permission réseau.

## Décisions de l'utilisateur pour cette phase

Validées le 21 novembre 2026. La spécification ne tranchait pas ces points. Une seule décision s'écarte de sa lettre, à la demande de l'utilisateur : H6, puisque la spécification nomme cette phase « Version 1.0 ».

| N° | Point | Décision |
|---|---|---|
| H1 | Export : contenu | Tout ce qui est saisi ou importé, dans son état du jour : comptes, soldes déclarés, relevés, arbres, règles de mapping et de redistribution, transactions et leurs lignes, réponses aux parts reportées, dettes, saisies des six modules. **Rien de calculé** : ni vue annuelle, ni fortune, ni courbe, ni diagramme. Seules exceptions, pour qu'une ligne se lise seule : le chemin d'une catégorie (« Logement > Loyer »), le type d'une transaction, le total d'une dette, le montant d'une ligne d'impôt, et les voyages tels que l'écran les regroupe. Hors export : l'historique des modifications, ce qui est supprimé, les PDF d'origine (ils restent sur le serveur), l'association au serveur. |
| H2 | Export : format | Un fichier `batz-export-AAAA-MM-JJ.zip`, enregistré par la fenêtre du système. Dedans : un fichier CSV par sujet et un `LISEZMOI.txt`. Noms de fichiers, en-têtes et valeurs **en français**, comme dans l'app. UTF-8 avec marque d'ordre des octets ; séparateur **point-virgule**. Montants `-1234.50` : point décimal, pas de séparateur de milliers. Dates `2026-12-31`. Oui / non. Un texte qui commence par `=`, `+`, `-` ou `@` est précédé d'une apostrophe, pour qu'un tableur ne le prenne pas pour une formule. Le tableur de l'utilisateur est **Excel** : le format est choisi pour lui. |
| H3 | Verrou : quand | Sur Android seulement (spécification). À l'ouverture, et au retour quand l'app a quitté l'écran **plus d'une minute**. Par la fenêtre d'Android : empreinte, visage ou code de l'appareil. Toujours actif, sans réglage pour le désactiver. |
| H4 | Verrou : cas limites | Téléphone sans verrouillage d'écran : l'app s'ouvre, et l'accueil affiche un avertissement tant que c'est le cas. Déverrouillage annulé ou refusé : l'app reste verrouillée, avec un bouton « Déverrouiller ». Erreur inattendue : l'app reste verrouillée et affiche l'erreur, avec « Réessayer ». |
| H5 | Aperçu des apps récentes | Masqué : la liste des apps récentes d'Android ne montre pas le dernier écran. Les captures d'écran restent possibles. Cela demande Android 13 ou plus récent, ce qu'a le téléphone de l'utilisateur ; sur un téléphone plus ancien, l'aperçu reste visible. |
| H6 | Versions | App et serveur passent en **0.8.0-alpha**, pas en 1.0.0 : d'autres modifications suivront, et l'utilisateur décidera plus tard de la 1.0.0. Le suffixe est dans le nom de version de l'app et dans le tag (`v0.8.0-alpha`) : Obtainium lit ainsi la même version dans le tag et dans l'app installée. Les versions suivantes le gardent jusqu'à la 1.0.0. Sur GitHub, la version reste une version normale, non marquée « préversion » : Obtainium ignore les préversions par défaut. Le serveur ne change que de numéro : il continue d'accepter les apps 0.7.0, puisque cette phase n'ajoute rien au journal. Aucun ordre de mise à jour n'est imposé. « Plus » affiche la version de l'app. |
| H7 | Documentation | En anglais, comme le reste du repo. Le `README.md` est refait pour qui découvre le projet ou installe sa propre instance : présentation, quatre captures d'écran faites avec des données inventées, installation du serveur et des apps (Obtainium compris), premiers pas, mise à jour, perte d'un appareil ou du serveur, export. S'y ajoutent `docs/export.md` (chaque fichier et ses colonnes) et `docs/security.md` (ce qui protège quoi, et ce qui n'est pas protégé). Pas de manuel en français. |
| H8 | Icône | L'icône par défaut de Flutter est remplacée par un « b » blanc sur le vert de l'app (`#2E7D5B`), sur Android, Windows et Ubuntu. |

**Bibliothèques** : cette phase en ajoute deux. `archive` écrit le ZIP ; elle est en Dart pur. `local_auth` ouvre la fenêtre de déverrouillage d'Android ; elle est maintenue par l'équipe Flutter. L'étape 7.0 vérifie leur licence et ce qu'elles demandent.

**Commits** : même régime qu'en phases 0 à 6. Commits locaux sur des branches, un par étape, sans push. Messages en anglais, au format Conventional Commits, sujet de 50 caractères au plus, sans ligne `Co-Authored-By`. Le push, la version 0.8.0-alpha et le déploiement sur le NAS se font à la fin, avec l'accord de l'utilisateur. Les apps 0.8.0-alpha fonctionnent avec le serveur 0.7.0 en attendant.

## Principes

1. **L'export lit, il n'écrit rien.** Il ne crée aucune entrée de journal, ne passe pas par le serveur et fonctionne hors ligne, sur chaque appareil.
2. **L'export suit le schéma.** Chaque entité du journal et chacun de ses champs est exporté, ou figure dans une liste d'exclusions avec son motif. Un test échoue si une entité ou un champ ajouté plus tard est oublié.
3. **Mêmes données, mêmes fichiers.** Les lignes sont triées selon un ordre fixe : deux appareils synchronisés produisent des fichiers CSV identiques à l'octet près.
4. **Aucun nombre à virgule.** Les montants s'écrivent à partir des centimes, les taux et les kWh à partir de leurs entiers.
5. **Le verrou est une porte devant l'écran.** Tant que l'app est verrouillée, aucun de ses écrans n'est dessiné. La base reste chiffrée par une clé gardée par le système, comme depuis la phase 0 : le verrou n'y change rien.
6. **Le verrou ne perd rien.** Au retour, après le déverrouillage, l'écran en cours et une saisie commencée sont retrouvés tels quels.
7. **Rien ne change pour le journal ni pour le serveur.** Pas de nouvelle entité, pas de migration, pas de route. Le verrou et l'export sont propres à chaque appareil.
8. **Aucune donnée réelle dans le repo.** Les exemples, les jeux d'essai et les captures d'écran sont inventés. Un export n'entre jamais dans le repo : `.gitignore` et le garde-fou le refusent.

## Règles

### Fichiers de l'export

| Fichier | Une ligne par | Colonnes principales |
|---|---|---|
| `comptes.csv` | compte | nom, type, format d'import, archivé |
| `soldes.csv` | solde déclaré | compte, date, montant |
| `releves.csv` | relevé importé | compte, format, IBAN, début et fin de période, soldes initial et final, empreinte du fichier |
| `categories.csv` | catégorie d'une année | année, chemin, nom, nature, groupe parent, position |
| `regles.csv` | règle de mapping | année, mots-clés, catégorie ou compte cible, modèle de période |
| `redistributions.csv` | règle de redistribution | année, catégorie source, catégorie cible, pourcentage |
| `transactions.csv` | ligne de transaction | date, compte, montant, texte de la banque, description, note, statut, type, catégorie, début et fin de période, compte de contrepartie, relevé, ligne remboursée |
| `parts-reportees.csv` | réponse pour une part reportée | transaction, année, catégorie choisie, catégorie d'origine |
| `dettes.csv` | dette | sens, personne, montant, pourcentage, total, les quatre dates, description, remboursé, jour de saisie, jour où elle a été cochée |
| `fiches-salaire.csv` | fiche salaire | année, brut, net |
| `deductions-salaire.csv` | déduction | année, rang, libellé, montant |
| `annees-fiscales.csv` | année fiscale | année, fortune imposable, TMI |
| `impots.csv` | ligne d'impôt | année, impôt, base, taux de base, coefficient, montant |
| `voyages.csv` | voyage | date, lieu, jours, montant, montant automatique, date et montant remplacés ou non, nombre de transactions, ligne manuelle ou non |
| `electricite.csv` | ligne qui porte des kWh | date de paiement, description, début et fin de période, montant, kWh |
| `abonnements.csv` | tranche d'abonnement | abonnement, note, montant, fréquence, début, fin |
| `reglages-modules.csv` | module | module, nom de la catégorie liée |
| `LISEZMOI.txt` | — | date de l'export, version de l'app, liste des fichiers avec leur nombre de lignes, conventions de format |

- Une transaction sans ligne (un transfert, une ligne à valider) a une ligne dans `transactions.csv`, sans catégorie ni période. La proposition des règles n'est pas exportée : elle est calculée.
- Chaque fichier garde les identifiants, dans des colonnes `id…` placées à la fin, pour relier les fichiers entre eux. À côté, le nom se lit en clair : un compte par son nom, une catégorie par son chemin.
- Une saisie dont la transaction a disparu (kWh, fiche de voyage) est exportée quand même, sans les colonnes de la transaction. Une fiche de voyage en trop ou sans transaction a sa ligne dans `voyages.csv`, signalée comme telle.
- Un fichier sans donnée contient sa ligne d'en-têtes.

### Format des fichiers CSV

- UTF-8, précédé de la marque d'ordre des octets. Fins de ligne CR LF. Première ligne : les en-têtes.
- Séparateur point-virgule. Une valeur qui contient un point-virgule, un guillemet ou un retour à la ligne est entre guillemets ; un guillemet y est doublé.
- Montant : `1234.50`, `-85.00`, `0.00`. Pourcentage : `50.00`. Taux de base : `2.5000`. kWh : `1900`, `1900.5`. Date : `2026-12-31`. Oui ou non : `oui`, `non`. Valeur absente : vide.
- Un texte saisi ou venu de la banque qui commence par `=`, `+`, `-` ou `@` est précédé d'une apostrophe. Un montant négatif n'est pas un texte : il reste `-85.00`.

Exemple, trois lignes de `transactions.csv` (colonnes réduites) :

```
Date;Compte;Montant;Texte de la banque;Description;Statut;Type;Catégorie;Début de période;Fin de période
2026-09-01;Compte privé;-2100.00;;Loyer annuel;validée;dépense;Logement > Loyer;2026-09-01;2027-08-31
2026-09-03;Compte privé;-85.00;"ACHAT; AUBERGE ""DU LAC""";Restaurant;validée;dépense;Quotidien > Restaurant;2026-09-03;2026-09-03
2026-09-05;Compte privé;-500.00;;Vers l'épargne;validée;transfert;;;
```

Un texte de banque `=A1+1` s'écrit `'=A1+1`.

### Verrou

- L'app Android démarre verrouillée. La fenêtre de déverrouillage d'Android s'ouvre seule ; une fois le déverrouillage réussi, l'accueil s'affiche.
- Quand l'app quitte l'écran, elle note l'heure. Au retour, si **plus de 60 secondes** ont passé, elle se verrouille. Si l'heure du téléphone a reculé entre-temps, elle se verrouille aussi.
- Les fenêtres du système que l'app ouvre elle-même (choisir un PDF, enregistrer un export, la fenêtre de déverrouillage) suivent la même règle : revenir en moins d'une minute ne verrouille pas.
- Une app fermée par Android en arrière-plan redémarre verrouillée.
- La synchronisation continue pendant que l'app est verrouillée : rien n'est affiché.
- Sur Windows et Ubuntu, il n'y a pas de verrou.

Exemple :

| Heure | Événement | État |
|---|---|---|
| 08:00:00 | Ouverture de l'app | Verrouillée, puis accueil après l'empreinte |
| 08:05:00 → 08:05:59 | L'app quitte l'écran 59 secondes | Pas de verrou |
| 08:10:00 → 08:11:00 | 60 secondes | Pas de verrou |
| 08:20:00 → 08:21:01 | 61 secondes, pendant une saisie | Verrouillée ; après le déverrouillage, la saisie est retrouvée |
| 08:30:00 → 08:29:00 | L'heure du téléphone a reculé | Verrouillée |

### Versions

- App `0.8.0-alpha`, numéro de build 9. Serveur `0.8.0-alpha`, version minimale de l'app inchangée : `0.7.0`.
- Le tag d'une version est `v` suivi du nom de version de l'app, suffixe compris ; la publication le vérifie.
- Le suffixe ne compte pas dans la comparaison des versions entre l'app et le serveur : `0.8.0-alpha` vaut `0.8.0`.
- Le numéro de build d'une version est toujours supérieur à celui de la version publiée avant elle : sinon le téléphone refuse la mise à jour.
- Une base locale de chaque version publiée, de 0.1.0 à 0.7.0, s'ouvre avec la 0.8.0-alpha.

## Étapes

Chaque étape est une branche locale et un commit, avec ses tests.

### 7.0 Préparation

- Vérifier `archive` et `local_auth` à la version retenue : licence, plateformes, et ce que `local_auth` demande à l'app Android (activité, permission, thème). Consigné dans `docs/decisions.md`.
- Base de la version 0.7.0, écrite par le code de la 0.7.0, avec une saisie dans chaque module ; test : elle s'ouvre avec la nouvelle version, données conservées.
- Script `scripts/check-build-number.sh` : le numéro de build est supérieur à celui de la dernière version publiée ; lancé par la CI.
- Nom de version à suffixe (`0.8.0-alpha+9`) : la publication l'accepte et le compare au tag ; les fabrications Ubuntu et Android l'acceptent. Celle de Windows ne se vérifie que par la CI, après le push.
- `.gitignore` et garde-fou : un fichier `batz-export-*.zip` n'est jamais suivi par git.

### 7.1 Export : les fichiers

- Domaine en Dart pur : pour un grand livre, la liste des fichiers, leurs en-têtes et leurs lignes triées (H1) ; l'écriture CSV (H2).
- Complétude : la table qui relie chaque entité et chaque champ à sa colonne, et la liste des exclusions motivées (principe 2).
- Tests : un grand livre d'exemple qui contient chaque sorte de donnée, comparé à ses fichiers attendus ; chaque règle de format ; sur des données tirées au hasard, chaque enregistrement non supprimé se retrouve dans son fichier avec ses valeurs, et un enregistrement supprimé n'y est pas ; relu par un lecteur CSV, chaque fichier redonne les valeurs écrites.

### 7.2 Export : le ZIP et l'écran

- Le ZIP, son `LISEZMOI.txt`, son nom daté ; l'enregistrement par la fenêtre du système, sur les trois plateformes.
- App : « Plus » → « Réglages » → « Exporter les données ». L'écran dit ce que l'export contient et que **le fichier n'est pas chiffré** ; après l'enregistrement, il indique le nombre de fichiers et de transactions. Une annulation ne laisse rien.
- Tests : le ZIP se relit par la bibliothèque et par `unzip -t` ; l'export ne crée aucune entrée de journal ; deux appareils synchronisés par un vrai serveur produisent les mêmes fichiers CSV ; le parcours de l'écran, enregistrement et annulation ; mesure avec 10 000 transactions.

### 7.3 Verrou Android

- Accès au déverrouillage de l'appareil : disponible ou non, déverrouiller. Une version simulée pour les tests et pour les ordinateurs.
- La porte : états verrouillé et déverrouillé, délai de 60 secondes, heure qui recule, cas limites (H3, H4). Une horloge injectable.
- App Android : activité et permission demandées par `local_auth` ; aperçu masqué dans les apps récentes (H5).
- Accueil : l'avertissement « ce téléphone n'a pas de verrouillage d'écran ».
- Tests, avec un téléphone simulé : l'exemple, ligne par ligne ; rien de l'app n'est dessiné tant qu'elle est verrouillée ; annulation, refus, erreur ; téléphone sans verrouillage d'écran ; aucun verrou sur ordinateur ; le fichier de l'app Android déclare la permission et la bonne activité.

### 7.4 Version affichée et icône

- « Plus » affiche la version de l'app, en bas de l'écran.
- Icône (H8) : un seul dessin, dont un outil du repo tire les fichiers d'Android (icône adaptative comprise), de Windows et d'Ubuntu.
- Tests : la version affichée est celle de `pubspec.yaml` ; les fichiers d'icône sont ceux que l'outil produit.

### 7.5 Documentation et version 0.8.0-alpha

- En anglais : `README.md` refait (H7), qui dit que le projet est en version alpha, avec quatre captures d'écran produites par une commande à partir de données inventées (« Année », « Fortune », le diagramme de flux, la validation) ; `docs/export.md` ; `docs/security.md` ; `batz-web/docs/deployment.md` : installation et mise à jour de l'app Android par Obtainium, passage à la 0.8.0-alpha ; décisions prises en route dans `docs/decisions.md`.
- App et serveur en version 0.8.0-alpha ; le serveur accepte toujours l'app 0.7.0.

## Critères d'acceptation

### Vérifiables par une commande sur la machine de développement

| Critère | Commande |
|---|---|
| L'export contient toutes les données : chaque entité du journal et chacun de ses champs est exporté ou exclu avec son motif ; le test échoue si l'on en retire un. | `flutter test`, test de complétude de l'export |
| Sur des données tirées au hasard, chaque enregistrement non supprimé se retrouve dans son fichier avec ses valeurs ; un enregistrement supprimé n'y est pas. | `flutter test`, test de l'export |
| Le grand livre d'exemple donne exactement ses fichiers attendus, les trois lignes de l'exemple du plan comprises. | `flutter test`, test de l'export |
| Le format est celui de H2 : marque d'ordre des octets, point-virgule, guillemets doublés, montants, dates, oui et non, apostrophe devant `=`, `+`, `-` et `@`. Relu par un lecteur CSV, chaque fichier redonne les valeurs écrites. | `flutter test`, test du format |
| Le ZIP contient les dix-sept fichiers CSV et `LISEZMOI.txt`, porte son nom daté, et se relit par un autre outil. | `flutter test`, test du ZIP (`unzip -t`) |
| L'export ne crée aucune entrée de journal ; deux appareils synchronisés produisent les mêmes fichiers CSV. | `flutter test`, tests de bout en bout |
| Avec 10 000 transactions sur cinq ans et les données de la phase 6, l'export se fabrique en moins de 2 secondes. | `flutter test`, test de performance |
| L'app Android démarre verrouillée et rien de ses écrans n'est dessiné avant le déverrouillage ; l'exemple du verrou donne chaque état, à 59, 60 et 61 secondes, et quand l'heure recule. | `flutter test`, test du verrou |
| Après un verrouillage au retour, l'écran en cours et la saisie commencée sont retrouvés. | `flutter test`, test du verrou |
| Annulation, refus et erreur laissent l'app verrouillée ; un téléphone sans verrouillage d'écran ouvre l'app avec un avertissement ; un ordinateur n'a pas de verrou. | `flutter test`, test du verrou |
| Le fichier de l'app Android déclare ce que le verrou demande, pour la version publiée comprise. | `flutter test`, test du manifeste |
| Une base de la version 0.7.0 s'ouvre avec la nouvelle version, comme celles des versions précédentes. | `flutter test`, test d'ouverture |
| Le numéro de build est supérieur à celui de la version 0.7.0. | `scripts/check-build-number.sh` |
| « Plus » affiche la version 0.8.0-alpha ; le parcours de l'export fonctionne dans l'interface. | `flutter test`, tests d'interface |
| L'app ne présente aucun défaut d'analyse et tous ses tests passent. | `flutter analyze && flutter test` dans `batz-ui` |
| Le serveur passe ses tests, accepte une app 0.7.0 et une app 0.8.0-alpha, et refuse une app 0.6. | `go vet ./... && go test -race ./...` dans `batz-web/src` |
| La publication compare le tag au nom de version, suffixe compris : `v0.8.0-alpha` est accepté, `v0.8.0` est refusé. | commande de vérification de `release.yml`, lancée à la main |
| La version Ubuntu, l'APK et l'image du serveur se fabriquent. | `flutter build linux`, `flutter build apk`, `docker build` |
| Aucun fichier personnel, aucun terme personnel ni aucun export n'est suivi par git. | `scripts/check-personal-files.sh` |

### Vérifiables sur GitHub, après le push

- Tous les contrôles de la CI sont au vert, compilation Windows comprise, avec le nom de version à suffixe.
- La publication de la version 0.8.0-alpha produit l'APK signé, les versions Ubuntu et Windows et l'image du serveur.

### À vérifier par l'utilisateur, après installation de la version 0.8.0-alpha

- Sur le téléphone, Obtainium propose la 0.8.0-alpha et l'installe par-dessus la 0.7.0 : les données et l'association au serveur sont conservées. Une fois installée, Obtainium ne la propose plus.
- Sur le téléphone, l'app exige le déverrouillage à l'ouverture, par l'empreinte et par le code ; elle l'exige de nouveau après plus d'une minute hors de l'écran, et pas au retour du choix d'un PDF.
- Sur le téléphone, la liste des apps récentes ne montre pas le dernier écran ; l'icône est la nouvelle.
- Sur Windows et sur Ubuntu, la 0.8.0-alpha remplace la 0.7.0 : les données sont conservées, sans verrou.
- L'export fait sur chaque appareil s'ouvre dans ton tableur : les accents sont justes, les montants sont des nombres, les dates sont des dates, et le nombre de transactions est celui de l'app.
- Après le déploiement du serveur 0.8.0-alpha sur le NAS : les apps 0.8.0-alpha se synchronisent.

## Hors de cette phase

- Publier la version 1.0.0 : l'utilisateur le décidera, après ses modifications.
- Réimporter un export, chiffrer l'export, l'exporter automatiquement, exporter la vue annuelle ou la fortune : non prévus.
- Verrou sur Windows et Ubuntu, délai réglable, clé de la base liée au déverrouillage, test de l'app sur un émulateur Android dans la CI : plus tard, sans engagement.
- Ce que la spécification range dans « Plus tard, sans engagement » : comparaison entre années, ventilation d'une transaction, appariement de transferts, historique antérieur à 2026, autres banques, synchronisation en arrière-plan, lien entre dettes et transactions.
- Compte commun et deuxième utilisateur : exclus par la spécification.

Cette phase est la dernière de la spécification. La suite, version 1.0.0 comprise, se décide après la 0.8.0-alpha.

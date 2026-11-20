# Plan de la phase 0 — Socle

Référence : [specification.md](../specification.md), chapitres 5 à 13.

But de la phase : un squelette qui traverse toute l'architecture. À la fin, l'app s'installe sur les trois plateformes, garde ses données dans une base locale pilotée par le journal, et s'associe au serveur en HTTPS. Aucune fonction comptable n'est encore présente.

## Prérequis

Constat sur la machine de développement Ubuntu au 20 novembre 2026 :

| Outil | État |
|---|---|
| Go 1.27, Docker, `pdftotext`, `gh`, git | Présents. |
| Flutter 3.47.7 | Présent dans `~/.local/flutter`, hors du `PATH` par défaut. |
| SDK Android | Présent dans `~/.local/android-sdk` ; toutes les licences sont acceptées. |
| Outils de compilation Linux pour Flutter | Présents : `clang`, `cmake`, `ninja`, `pkg-config`, `libgtk-3-dev`. |

Actions qui demandent l'utilisateur :

1. Autoriser la création du repo GitHub public `batz` et le premier push.
2. Créer la clé de signature Android et l'enregistrer dans les secrets GitHub (voir l'étape 0.7).
3. Allumer le NAS pour l'étape 0.8.

## Décisions de l'utilisateur pour cette phase

Validées le 20 novembre 2026 :

- **Commits** : autorisés en local, sur des branches, un commit par étape, sans push. Messages en anglais, au format Conventional Commits, sujet de 50 caractères au plus, sans ligne `Co-Authored-By`.
- **Signature Android** : mise en place dès cette phase.

## Étapes

Chaque étape est une branche locale et un commit, avec ses tests. Les pull requests commenceront une fois le repo GitHub créé.

### 0.1 Mise en place du repo

- `git init`, branche `main`, licence MIT, `README.md`.
- `.gitignore` : relevés personnels, fichiers `config-*.yaml*`, sorties de compilation, secrets (`*.jks`, `key.properties`, `.env`).
- Scripts Python d'origine déplacés dans `legacy/`, comme référence pour la phase 3.
- Vérification : `git ls-files` ne liste aucun fichier personnel ; un contrôle de la CI échoue si un tel fichier est suivi.

### 0.2 Vérifications techniques préalables

Trois points de la spécification (chapitre 14) sont à trancher avant de construire dessus. Le résultat de chacun est consigné dans `docs/decisions.md`.

- **Base locale** : une bibliothèque qui fonctionne chiffrée sur Android et en clair sur Windows et Ubuntu. Piste : Drift, avec SQLCipher sur Android.
- **SQLite côté Go** : un pilote sans dépendance système, compatible avec golang-migrate. Piste : `modernc.org/sqlite`.
- **GitHub Actions** : confirmer dans la documentation officielle la gratuité pour un repo public, machines Windows comprises.

Si une piste échoue, l'étape s'arrête et l'alternative est soumise à l'utilisateur avant de continuer.

### 0.3 Squelette du serveur (`batz-web`)

- Module Go, couches `domain`, `application`, `infrastructure`, configuration lue une seule fois (dossier de données, port).
- Base SQLite et migrations : appareils, codes d'association.
- `GET /healthz` : état, version, version minimale de l'app.
- Certificat créé au premier démarrage et conservé dans le dossier de données ; écoute en HTTPS uniquement.
- Association : un code à usage unique, valable 10 minutes, produit par une commande du serveur. `POST /api/v1/pairing` renvoie l'identifiant et la clé de l'appareil. La clé est conservée hachée.
- Authentification par clé d'appareil ; `GET` et `DELETE /api/v1/devices`.
- `Dockerfile` (utilisateur sans privilèges, contrôle de santé) et `docker-compose.example.yml`.
- Tests unitaires et tests HTTP.

### 0.4 Squelette de l'app (`batz-ui`)

- Projet Flutter pour Android, Linux et Windows ; identifiant `dev.batz.app`.
- Thème Material 3, clair et sombre suivant l'appareil.
- Textes en français, séparés du code.
- Navigation : cinq entrées, barre inférieure sur écran étroit, menu latéral sur écran large ; pages vides.
- Formats suisses pour les montants et les dates, avec leurs tests.

### 0.5 Base locale et journal

- Schéma initial : table du journal et mécanisme de tables dérivées.
- Horloge logique hybride, en Dart pur, pour ordonner les modifications.
- Toute écriture passe par le journal : une modification est un ensemble d'entrées appliquées en une seule opération.
- Fonction d'application « champ par champ, la plus récente gagne », avec départage par identifiant d'appareil.
- Identifiant d'appareil créé au premier lancement.
- Android : base chiffrée, clé créée au premier lancement et gardée par le système.
- Tests : ordre, égalités, suppression, reprise après redémarrage.

### 0.6 Association depuis l'app

- Écran « Serveur » dans les réglages : adresse, code d'association, nom de l'appareil.
- L'empreinte du certificat est mémorisée à l'association ; toute requête ultérieure refuse un autre certificat.
- Clé d'appareil et empreinte conservées dans le stockage sécurisé du système.
- Affichage de l'état : associé ou non, version du serveur, avertissement d'incompatibilité.
- Liste des appareils, révocation, dissociation.
- Test de bout en bout contre un vrai serveur lancé localement.

### 0.7 Intégration continue et versions

- `ci.yml` : serveur (compilation, `go vet`, tests), app (analyse, tests), bout en bout, compilation Linux, Windows et Android.
- `release.yml` : APK signé, versions Windows et Ubuntu, image du serveur sous forme de fichier, attachés à la version GitHub.
- **Ajustement validé par rapport au tableau des phases** : la signature Android est mise en place dès cette phase et non en phase 7. Un APK signé avec une autre clé ne peut pas remplacer l'app installée ; changer de clé plus tard obligerait à désinstaller l'app du téléphone.

### 0.8 Déploiement sur le NAS

- `scripts/deploy-nas.sh` : copie le fichier image par SSH, le charge, démarre le conteneur avec son dossier de données sur le volume, puis interroge `/healthz`.
- Le script ajoute `/usr/local/bin` au `PATH` distant, où se trouve `docker` sur Synology.
- Cette étape modifie le NAS : elle n'est lancée qu'avec l'accord de l'utilisateur.

### 0.9 Documentation

En anglais : `README.md`, `batz-web/docs/architecture.md`, `api.md`, `deployment.md`.

## Critères d'acceptation

### Vérifiables par une commande sur la machine de développement

| Critère | Commande |
|---|---|
| Le serveur compile et ses tests passent. | `go vet ./... && go test -race ./...` dans `batz-web/src` |
| L'app ne présente aucun défaut d'analyse et ses tests passent. | `flutter analyze && flutter test` dans `batz-ui` |
| Un appareil s'associe avec un code valide ; un code expiré, déjà utilisé ou faux est refusé. | Test de bout en bout |
| Une requête sans clé et une requête d'appareil révoqué sont refusées. | Test de bout en bout |
| Un serveur présentant un autre certificat est refusé par l'app. | Test de bout en bout |
| Le journal applique « champ par champ, la plus récente gagne » et survit à un redémarrage. | `flutter test` |
| La version Ubuntu se compile. | `flutter build linux` |
| L'APK se compile. | `flutter build apk` |
| L'image du serveur se construit, démarre et répond en HTTPS. | `docker build`, puis appel de `/healthz` |
| Aucun fichier personnel n'est suivi par git. | `git ls-files` |

### Vérifiables sur GitHub, après le premier push

- Tous les contrôles de la CI sont au vert, compilation Windows comprise.

### À vérifier par l'utilisateur

- L'app s'installe sur le téléphone Android, sur Windows et sur Ubuntu, et affiche les cinq entrées.
- Chacun des trois appareils s'associe au serveur du NAS.
- Un appareil révoqué depuis un autre est refusé.

## Hors de cette phase

Comptes, catégories, transactions, synchronisation du journal avec le serveur, import : phases 1 à 3.

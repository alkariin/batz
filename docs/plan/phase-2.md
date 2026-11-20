# Plan de la phase 2 — Synchronisation

Référence : [specification.md](../specification.md), chapitres 4.6, 5, 8, 9, 11 et 13 ; règles de conception dans [decisions.md](../decisions.md).

But de la phase : les appareils échangent leur journal par le serveur. Ce qui est saisi sur l'un apparaît sur les autres, les modifications faites hors ligne se combinent champ par champ, un appareil perdu se révoque, et un serveur perdu se reconstruit depuis n'importe quel appareil.

## État de départ

Contrôle de la phase 1 fait le 20 novembre 2026 :

- Analyse sans défaut et 161 tests de l'app au vert, tests du serveur au vert, CI au vert sur `main`, version 0.2.0 publiée.
- Le domaine et le journal sont conformes à la spécification et aux décisions H1 à H6 de la phase 1.

Deux points à reprendre, placés dans l'étape 2.0 :

1. **Chaque modification réécrit tous les champs de l'enregistrement.** Sans conséquence sur un seul appareil. Avec la synchronisation, la modification la plus récente écraserait aussi les champs que l'autre appareil a changés : la note corrigée sur le téléphone serait perdue parce que la catégorie a été changée ensuite sur l'ordinateur. C'est le premier critère d'acceptation de cette phase.
2. **Une catégorie détachée de l'arbre est invisible.** Deux déplacements faits en même temps sur deux appareils peuvent former une boucle ; les catégories concernées disparaissent alors de tous les écrans, sans moyen de les replacer.

## Décisions de l'utilisateur pour cette phase

Validées le 20 novembre 2026. La spécification ne tranchait pas les points H1 à H6.

| N° | Point | Décision |
|---|---|---|
| H1 | Premier échange d'un appareil qui a déjà des données avec un serveur qui en a d'autres, sans rien en commun | L'app pose la question : **fusionner** les deux jeux de données, ou **remplacer** les données de l'appareil par celles du serveur. C'est le cas des appareils utilisés séparément pendant la phase 1. Le remplacement reste disponible ensuite dans les réglages, après confirmation ; il efface les modifications non envoyées de l'appareil. |
| H2 | Moments de la synchronisation automatique | À l'ouverture de l'app, à son retour au premier plan, quelques secondes après une modification, et toutes les cinq minutes tant qu'elle est affichée. Plus le bouton. Un serveur injoignable ne produit aucun message d'erreur, seulement l'état « hors ligne ». |
| H3 | Copie d'arbre faite sur deux appareils hors ligne | Limite acceptée. Si un appareil copie l'arbre d'une année puis y renomme ou déplace une catégorie, et qu'un autre appareil, pas encore synchronisé, copie le même arbre plus tard, le renommage est annulé après synchronisation. Les deux appareils affichent le même arbre ; rien n'est en double ni supprimé. |
| H4 | Incohérences après fusion : deux catégories de même nom dans une année, deux comptes détaillés, catégories détachées | Jamais bloquantes. Elles apparaissent dans les tâches de l'accueil et se corrigent par les écrans habituels. Les catégories détachées sont listées dans l'écran des catégories, sous « À replacer ». |
| H5 | Horloge d'un appareil déréglée | L'app avertit quand son horloge s'écarte de plus de cinq minutes de celle du serveur. Elle ne bloque pas la synchronisation. |
| H6 | Appareil révoqué | La synchronisation s'arrête avec un message clair. Les données restent sur l'appareil. S'il est associé de nouveau, ses modifications non envoyées partent au premier échange. |

**Commits** : même régime qu'en phases 0 et 1. Commits locaux sur des branches, un par étape, sans push. Messages en anglais, au format Conventional Commits, sujet de 50 caractères au plus, sans ligne `Co-Authored-By`. Le push, la version 0.3.0 et le déploiement sur le NAS se font à la fin, avec l'accord de l'utilisateur.

## Principe de l'échange

1. **Le serveur conserve, il n'interprète pas.** Il garde les entrées du journal telles quelles. Les conflits sont résolus par l'app, avec la règle en place depuis la phase 0 : champ par champ, la plus récente gagne.
2. **État connu.** Chaque exemplaire du journal (appareil ou serveur) sait, pour chaque appareil d'origine, jusqu'à quel horodatage il possède ses entrées. Lors d'un échange, chacun envoie à l'autre ce qui lui manque, **toutes origines confondues**.
3. **Un seul mécanisme.** Il n'y a ni curseur ni mode de reprise. Un nouvel appareil, un serveur vide ou un serveur restauré depuis une copie ancienne sont des échanges ordinaires : l'état connu de l'autre côté est simplement plus court. C'est ce qui permet de reconstruire le serveur depuis n'importe quel appareil.
4. **Invariant.** Pour chaque appareil d'origine, tout exemplaire détient ses entrées depuis la première, sans trou. Pour le garantir : un envoi est trié par horodatage, appliqué en une seule opération, et une page ne coupe jamais une modification.
5. **Une seule route**, `POST /api/v1/sync`, appelée en boucle. Chaque appel porte l'état connu de l'appareil et une page d'entrées pour le serveur ; la réponse porte l'état connu du serveur, son heure et une page d'entrées pour l'appareil. La boucle s'arrête quand plus rien ne reste à échanger.
6. **Rejouer est sans effet.** Une entrée déjà connue est ignorée. Un échange interrompu reprend au suivant, sans perte ni doublon.
7. **Contrôles du serveur.** Appareil authentifié et non révoqué, numéro de protocole, forme de chaque entrée, taille de la page. Une page incorrecte est refusée en entier.

## Étapes

Chaque étape est une branche locale et un commit, avec ses tests.

### 2.0 Reprises de la phase 1

- Une modification n'écrit que les champs dont la valeur change. La règle est posée dans le journal, pour valoir aussi pour les entités des phases suivantes.
- L'arbre d'une année expose ses catégories détachées (boucle, parent absent ou d'une autre année, groupe sans nature). L'écran des catégories les liste sous « À replacer », avec l'action de déplacement.
- Test : une base de la version 0.2.0 s'ouvre avec la nouvelle version, données conservées.

### 2.1 Serveur : journal et route d'échange

- Migration : table du journal, indexée par appareil d'origine et horodatage.
- Domaine : entrée de journal et ses contrôles de forme. Application : état connu, entrées manquantes par page, intégration en une opération.
- Route `POST /api/v1/sync`, avec sa propre limite de taille.
- Tests unitaires, tests HTTP, et test de bout en bout avec deux appareils simulés.

### 2.2 App : moteur d'échange

- Dans `data` : calcul de l'état connu, pages, boucle d'échange, intégration des entrées reçues en une opération, reprise après coupure.
- Mémorisation du dernier état connu du serveur et de la date du dernier échange réussi, pour afficher les modifications en attente.
- Tests contre un vrai serveur lancé localement, avec plusieurs appareils simulés : conflits, suppressions, coupure entre deux pages.
- Test de convergence : plusieurs appareils, des opérations et des ordres d'échange tirés au hasard ; à la fin, toutes les tables sont identiques.
- Durée d'un premier échange de 20 000 entrées mesurée sur la machine de développement et consignée.

### 2.3 Déclenchement et état

- Déclenchement selon H2. Un seul échange à la fois.
- États : jamais synchronisé, en cours, à jour, hors ligne, appareil révoqué, versions incompatibles, erreur.
- Après un échange qui a reçu des entrées, les écrans se rechargent.
- Accueil : état de la synchronisation, date de la dernière, nombre de modifications en attente, bouton.
- « Plus » → « Serveur » : les mêmes informations.
- Versions : l'app refuse l'échange si le serveur exige une app plus récente, ou si le serveur est trop ancien pour elle, avec le motif.
- Avertissement d'horloge selon H5.

### 2.4 Premier échange et remplacement

- Question de H1 quand l'appareil et le serveur ont chacun des données sans origine commune.
- Action « Remplacer les données de cet appareil par celles du serveur » dans les réglages, après confirmation. L'appareil prend ensuite un nouvel identifiant de journal.

### 2.5 Révocation et reconstruction

- Appareil révoqué : arrêt des échanges et message, selon H6.
- Serveur perdu : l'app signale que le serveur a changé (autre certificat ou appareil inconnu) et invite à associer de nouveau. L'échange ordinaire fait le reste.
- Test de bout en bout du quatrième critère de la spécification.

### 2.6 Cohérence après fusion

- Détection, dans le domaine, des incohérences de H4.
- Affichage dans les tâches de l'accueil, avec accès à l'écran qui permet de corriger.

### 2.7 Documentation et version

- En anglais : `batz-web/docs/sync.md` (principe, invariant, protocole), mise à jour de `api.md`, `architecture.md`, `deployment.md` et `README.md` ; décisions prises en route dans `docs/decisions.md`.
- Version de l'app et du serveur portée à 0.3.0.

## Critères d'acceptation

### Vérifiables par une commande sur la machine de développement

| Critère | Commande |
|---|---|
| Sur deux appareils hors ligne, l'un corrige la note d'une transaction, l'autre change sa catégorie, par les opérations de l'app : après échange, les deux modifications sont présentes sur les deux. | `flutter test`, test de bout en bout |
| Deux modifications du même champ : la plus récente gagne sur tous les appareils, quel que soit l'ordre des échanges. | `flutter test`, test de bout en bout |
| Une suppression se propage, et une modification plus ancienne arrivée ensuite ne fait pas réapparaître l'enregistrement. | `flutter test`, test de bout en bout |
| Un serveur vide est reconstruit depuis un appareil ; un autre appareil s'y associe de nouveau et s'y resynchronise sans perte, modifications non envoyées comprises. | `flutter test`, test de bout en bout |
| Convergence : opérations et ordres d'échange tirés au hasard, tables identiques à la fin sur tous les appareils. | `flutter test`, test de convergence |
| Un échange coupé entre deux pages reprend sans perte ni doublon. | `flutter test`, test de bout en bout |
| Un appareil révoqué est refusé ; ses données locales sont intactes. | `flutter test`, test de bout en bout |
| Des versions incompatibles refusent l'échange, avec le motif. | `flutter test` |
| Remplacement (H1) : l'appareil contient ensuite exactement les données du serveur. | `flutter test`, test de bout en bout |
| Les incohérences de H4 sont détectées, et une catégorie détachée peut être replacée. | `flutter test` |
| Une base de la version 0.2.0 s'ouvre avec la nouvelle version. | `flutter test`, test d'ouverture |
| Le serveur refuse en entier une page incorrecte, et accepte deux fois la même page sans doublon. | `go test`, tests de la route |
| L'app ne présente aucun défaut d'analyse et tous ses tests passent. | `flutter analyze && flutter test` dans `batz-ui` |
| Le serveur compile et ses tests passent. | `go vet ./... && go test -race ./...` dans `batz-web/src` |
| La version Ubuntu et l'APK se compilent ; l'image du serveur se construit et répond. | `flutter build linux`, `flutter build apk`, `docker build` puis `/healthz` |
| Aucun fichier personnel n'est suivi par git. | `scripts/check-personal-files.sh` |

### Vérifiables sur GitHub, après le push

- Tous les contrôles de la CI sont au vert, compilation Windows comprise.

### À vérifier par l'utilisateur, après déploiement du serveur 0.3.0 sur le NAS

- Ubuntu et Windows se synchronisent par le NAS ; le premier échange du second appareil pose la question de H1.
- Une saisie faite sur l'un apparaît sur l'autre.
- NAS éteint : l'app reste utilisable, affiche « hors ligne » et le nombre de modifications en attente ; elles partent quand le NAS est rallumé.
- Un appareil révoqué depuis l'autre ne se synchronise plus.
- Sur le téléphone : les mêmes vérifications, dès qu'il est installé.

## Hors de cette phase

- Synchronisation en arrière-plan, app fermée : plus tard, sans engagement.
- Import, copie datée de la base du serveur avant un import, conservation des PDF : phase 3.
- Allègement du journal au fil des années : non prévu ; le volume d'une personne reste modeste.

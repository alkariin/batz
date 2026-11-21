# Plan de la phase 3 — Import et validation

Référence : [specification.md](../specification.md), chapitres 3, 4.1 à 4.6, 5 à 9, 11 et 13 ; règles de conception dans [decisions.md](../decisions.md) ; échange du journal dans [sync.md](../../batz-web/docs/sync.md).

But de la phase : le parcours principal de l'app. L'utilisateur envoie le relevé PDF du mois, le serveur l'extrait et le vérifie, les lignes entrent dans le compte déjà préclassées par les règles, et il ne reste qu'à compléter les exceptions et confirmer le reste, y compris hors ligne.

## État de départ

Contrôle de la phase 2 fait le 21 novembre 2026 :

- Analyse sans défaut et 248 tests de l'app au vert ; tests du serveur au vert avec le détecteur d'accès concurrents ; CI au vert sur `main` ; version 0.3.0 publiée.
- Relus : le journal, le moteur d'échange et son déclenchement côté app ; le domaine, l'application et le stockage côté serveur. Ils sont conformes au plan de la phase 2 et aux décisions H1 à H6. Les écrans n'ont pas été relus en détail.

Deux points à reprendre, placés dans l'étape 3.0 :

1. **Une modification s'écrit champ par champ**, avec plusieurs requêtes par champ. Sans effet jusqu'ici, où une modification porte une dizaine de champs. Un import en écrit un millier, une validation en lot autant. D'après la mesure consignée en phase 2 (quelques millisecondes par champ), cela ferait plusieurs secondes d'attente, davantage sur le téléphone. C'est une estimation : à mesurer, puis à corriger.
2. **Une erreur de rechargement des écrans après un échange réussi s'affiche comme une erreur de synchronisation.** Mineur.

## Décisions de l'utilisateur pour cette phase

Validées le 21 novembre 2026. La spécification ne tranchait pas ces points ; H1 et H3 s'écartent de sa lettre, avec l'accord de l'utilisateur.

| N° | Point | Décision |
|---|---|---|
| H1 | Qui refuse un relevé déjà importé | **L'app, d'après le journal**, après la synchronisation qui ouvre l'import. La spécification (4.4) dit « le serveur ». Le résultat visible est le même. Deux raisons : après une reconstruction du serveur, sa liste de fichiers est vide alors que le journal sait toujours ce qui a été importé ; et un import interrompu entre l'extraction et l'écriture doit pouvoir être relancé, ce qu'un refus du serveur empêcherait. |
| H2 | Date d'une transaction importée | La **date de comptabilisation** (colonne « Date » du relevé), comme dans les scripts d'origine. La date de valeur et la date d'achat écrite dans le libellé ne sont pas reprises comme champs ; la seconde reste lisible dans le texte brut. Un achat du 31 décembre comptabilisé le 2 janvier compte donc dans la nouvelle année, sauf si sa période est modifiée. |
| H3 | Description initiale d'une ligne importée | Un **libellé court** : le texte de la banque sans ses lignes génériques (type d'opération et sa date, numéro de carte, IBAN du bénéficiaire), quand le module les reconnaît ; sinon le texte entier. La spécification (4.4) dit « une copie ». Avec une copie, toutes les lignes d'achat par carte commencent par les mêmes quarante caractères et les listes deviennent illisibles sur le téléphone. Le texte brut reste entier, immuable, affiché à la validation et dans le détail ; les règles ne lisent que lui. |
| H4 | Corriger une ligne proposée | La correction **valide la ligne** du même coup. La confirmation en lot porte sur les propositions restantes. Une ligne validée reste modifiable (catégorie, période, description, note). |
| H5 | Égalité entre deux règles qui donnent le même résultat | Même cible et même modèle de période : **pas de conflit**, la ligne est proposée. Seules deux règles à égalité de résultats différents font passer la ligne en « à compléter ». |
| H6 | Sens exact des modèles de période | Voir le tableau ci-dessous. Lecture retenue pour « N mois » : une **durée** de N mois qui commence ou finit au paiement, et non « le mois situé N mois plus tard ». |
| H7 | Premier relevé d'un compte | L'app demande confirmation : ce relevé fixe le solde de départ, et **aucun relevé antérieur ne pourra être importé ensuite**. |
| H8 | Annuler un import | Action « **Supprimer le dernier relevé** » : elle retire le dernier relevé du compte et toutes ses lignes, après confirmation. Seul le dernier peut l'être, pour garder la continuité. Non prévue par la spécification, qui interdit de supprimer une ligne isolée d'un compte détaillé ; cette interdiction reste. La copie datée de la base du serveur ne remplit pas ce rôle : elle protège le serveur, mais après une restauration les appareils lui renvoient ce qui manque. |

Modèles de période (H6), pour un paiement le 14 mars 2026 :

| Modèle | Période | Exemple |
|---|---|---|
| Mois précédent | Le mois civil avant celui du paiement | 1.2.2026 – 28.2.2026 |
| Mois suivant | Le mois civil après celui du paiement | 1.4.2026 – 30.4.2026 |
| N mois après le paiement | N mois à partir du jour du paiement | N = 12 : 14.3.2026 – 13.3.2027 |
| N mois avant le paiement | N mois qui finissent la veille du paiement | N = 3 : 14.12.2025 – 13.3.2026 |
| Année civile en cours | Du 1er janvier au 31 décembre de l'année du paiement | 2026 |
| Année civile précédente | L'année d'avant | 2025 |

**Commits** : même régime qu'en phases 0 à 2. Commits locaux sur des branches, un par étape, sans push. Messages en anglais, au format Conventional Commits, sujet de 50 caractères au plus, sans ligne `Co-Authored-By`. Le push, la version 0.4.0 et le déploiement sur le NAS se font à la fin, avec l'accord de l'utilisateur.

## Principes

1. **Le serveur extrait et vérifie, l'app intègre.** Le serveur lit le PDF, contrôle sa cohérence interne, garde le fichier et renvoie les lignes. Il n'écrit rien dans le journal. L'app contrôle la continuité, puis écrit le relevé et toutes ses lignes en **une seule modification** : tout ou rien. Les règles du domaine restent dans l'app, en un seul exemplaire.
2. **Importer deux fois ne peut pas compter deux fois.** Les identifiants du relevé et de ses lignes sont calculés à partir du compte, de l'empreinte du fichier et du rang de la ligne, comme ceux des copies d'arbre. Deux appareils qui importent le même relevé en même temps produisent les mêmes enregistrements.
3. **Une proposition se calcule, elle ne s'enregistre pas.** Le journal ne retient que deux états : à valider, ou validée. Pour une ligne à valider, la catégorie, le transfert et la période affichés et comptés dans les totaux sont le résultat des règles de l'année appliquées à son texte brut, recalculé à chaque chargement. Créer, modifier ou supprimer une règle n'écrit donc que la règle : toutes les lignes non validées suivent aussitôt, sur tous les appareils, sans conflit possible, et les lignes validées ne bougent jamais. « Proposée » et « à compléter » se déduisent : une règle gagnante, ou aucune.
4. **Valider, c'est écrire le résultat.** La validation inscrit dans le journal la catégorie ou le compte de contrepartie, la période et l'état validé.
5. **Copie datée de la base du serveur.** Quand le serveur accepte un relevé qu'il ne connaissait pas, il écrit d'abord une copie de sa base, puis range le PDF. Il garde les 12 dernières. Renvoyer le même fichier ne crée pas de nouvelle copie.
6. **Le PDF est rangé sous son empreinte.** L'empreinte figure dans le relevé du journal ; elle suffit à retrouver le fichier. Un serveur reconstruit n'a plus les PDF : l'app le dit, sans erreur.
7. **Aucune donnée réelle dans le repo.** Les relevés réels servent à vérifier l'extraction sur la machine de développement, jamais ailleurs. Aucune de leurs lignes, aucun nom, aucune adresse, aucun numéro de compte ou de carte n'entre dans le code, les tests, les jeux d'essai, la documentation ou les messages de commit. Seules les formules propres à la banque, identiques pour tous ses clients, peuvent être reprises. Les relevés fictifs sont inventés de toutes pièces.

## Étapes

Chaque étape est une branche locale et un commit, avec ses tests.

### 3.0 Préparation

- Reprises de la phase 2 : mesurer l'écriture d'une modification de 1 000 champs, puis l'écrire par lots comme l'intégration des entrées reçues ; sortir le rechargement des écrans du traitement d'erreur de l'échange.
- Vérifications techniques, consignées dans `docs/decisions.md` : `pdftotext` dans l'image du serveur (paquet, version, taille de l'image, conteneur en lecture seule) ; même extraction avec la version de la machine de développement et celle de l'image ; bibliothèque de choix et d'enregistrement de fichier sur Android, Windows et Ubuntu ; envoi d'un fichier avec Dio.
- Garde-fou des données personnelles : `scripts/check-personal-files.sh` contrôle aussi le contenu des fichiers suivis, texte des PDF compris, contre une liste locale de termes personnels, hors versionnement (`personal/terms.txt`). Sans cette liste, comme en CI, ce contrôle est sauté et le dit.
- Générateur de relevés fictifs : un outil de test qui produit des PDF à la mise en page des relevés réels (positions mesurées sur ceux-ci, contenu inventé). Jeu d'essai versionné : trois mois consécutifs, un saut de page au milieu d'une journée, un montant séparé de son libellé par un pied de page, des libellés sur plusieurs lignes, un relevé d'un autre compte, des relevés incohérents (montant, total ou solde modifié), un fichier qui n'est pas un relevé.
- Test : une base de la version 0.3.0 s'ouvre avec la nouvelle version, données conservées.

### 3.1 Serveur : extraction PostFinance

- Domaine `statement` : relevé extrait (compte, monnaie, période, soldes, totaux, lignes avec date, montant signé en centimes, texte brut, libellé court) et ses contrôles : solde initial plus mouvements égale solde final ; chaque solde imprimé en cours de relevé ; totaux imprimés des crédits et des débits ; dates dans la période et dans l'ordre ; monnaie CHF. Aucun nombre à virgule.
- Infrastructure `extraction/postfinance` : appel de `pdftotext` sans interpréteur de commandes, avec durée limitée ; lecture du texte. Point de départ : la méthode du script d'origine (`-layout`), éprouvée sur les relevés réels ; passage aux coordonnées des mots (`-bbox-layout`) si les deux versions de `pdftotext` divergent. Pieds de page retirés des libellés ; libellé court selon H3.
- Commande `batz-web extract <fichier>` : affiche le résultat de l'extraction ou le motif du refus. Elle sert aux tests dans l'image et à la vérification locale.
- `scripts/check-real-statements.sh` : extrait chaque relevé réel présent à la racine et n'affiche, par fichier, que le verdict et le nombre de lignes. Pour les relevés qui ont un CSV du script d'origine, les dates et les montants sont comparés.
- Les journaux du serveur ne contiennent aucun texte de relevé.

### 3.2 Serveur : route d'import, PDF et copies de la base

- `POST /api/v1/imports` : reçoit le PDF, renvoie le relevé extrait et son empreinte ; refus avec un code et un motif (fichier illisible ou d'un autre format, relevé incohérent avec le contrôle en cause, fichier trop gros). Même fichier, même réponse.
- `GET /api/v1/imports/{empreinte}/pdf`.
- Copie datée de la base selon le principe 5, dans le dossier des données ; nombre de copies réglable, 12 par défaut.
- `/healthz` annonce les formats d'import ; l'app s'en sert pour dire qu'un serveur est trop ancien pour importer.
- L'image embarque `pdftotext`. La CI extrait le jeu d'essai dans l'image construite et compare aux résultats attendus.

### 3.3 App : relevés et lignes importées

- Entité « relevé » (compte, période, soldes, empreinte, IBAN) ; champs ajoutés aux transactions : texte brut, relevé, rang dans le relevé ; état « à valider ».
- Opération d'import du domaine, en une modification : relevé, lignes, et copie de l'arbre si une ligne ouvre une année. Refus, sans rien écrire, avec le motif : compte non détaillé ; relevé d'un autre compte (IBAN différent des relevés précédents) ; déjà importé (H1) ; non contigu (date de début ou solde initial attendus, et ceux trouvés) ; somme des lignes différente de l'écart des soldes.
- Compte détaillé : montant, date, compte et texte brut immuables ; ni saisie ni suppression d'une ligne. Catégorie, période, description et note modifiables.
- Suppression du dernier relevé (H8) ; un relevé supprimé peut être importé de nouveau.
- Un transfert importé garde le signe du relevé : négatif, l'argent part vers le compte de contrepartie ; positif, il en vient.

### 3.4 App : règles et propositions

- Entité « règle » de l'année : mots-clés, cible (catégorie ou transfert vers un compte), modèle de période. Création, modification, suppression. Les règles suivent la copie de l'arbre, avec des identifiants calculés et des cibles transposées.
- Correspondance : tous les mots-clés requis, sans tenir compte des majuscules, des accents ni des espaces multiples ; un mot-clé peut être une expression régulière, refusée à la saisie si elle est invalide. La règle lit le texte brut, jamais la description.
- Priorité : le plus grand nombre de mots-clés gagne ; égalité selon H5.
- Modèles de période selon H6.
- Propositions calculées selon le principe 3 ; les totaux de l'année en tiennent compte, les lignes sans proposition comptent en « Non classé ».
- Validation : classer une ligne (catégorie ou transfert, période) ; confirmer un lot en une modification.
- Une règle dont la cible n'est plus utilisable (catégorie supprimée, détachée ou devenue un groupe ; compte archivé) ne propose rien et apparaît dans les tâches. Une catégorie visée par une règle ne se supprime pas.
- Chaque règle des chapitres 4.4 et 4.5 de la spécification est un test, avec ses cas limites.

### 3.5 App : parcours d'import

- « Transactions » → « Importer un relevé » : synchronisation, choix du compte et du PDF, envoi, contrôles, puis le résultat (période, nombre de lignes, proposées, à compléter) ou le refus avec son motif. Sans serveur joignable ou sans synchronisation aboutie, l'import ne commence pas et le dit.
- Confirmation du premier relevé (H7).
- Liste des relevés du compte : période, soldes, nombre de lignes ; « Enregistrer le PDF d'origine » ; « Supprimer le dernier relevé ».
- Tests de bout en bout contre un vrai serveur, avec les relevés fictifs.

### 3.6 App : validation

- Indicateur du nombre de lignes à valider dans « Transactions » ; tâches de l'accueil : lignes à valider, lignes dont les règles sont en concurrence.
- Écran de validation, en deux parties. « À compléter » : chaque ligne avec son texte brut entier, son montant et sa date ; choix d'une catégorie de l'année ou d'un transfert, période, description, note ; règles en concurrence affichées ; « Créer une règle », qui montre combien de lignes non validées la règle classerait. « Proposées » : chaque ligne avec sa proposition et la règle qui la donne ; correction selon H4 ; « Confirmer les propositions ».
- Tout fonctionne hors ligne et peut être interrompu.
- Écran des règles de l'année, dans « Plus » → réglages.
- Liste des transactions : recherche par texte ; filtres par compte, catégorie, période et statut.

### 3.7 Documentation et version

- En anglais : `batz-web/docs/import.md` (parcours, contrôles, motifs de refus, format PostFinance, copies de la base et leur restauration) ; mise à jour de `api.md`, `architecture.md`, `deployment.md` et `README.md` ; décisions prises en route dans `docs/decisions.md`.
- Les scripts d'origine (`legacy/`) sortent du repo, comme le prévoit la spécification.
- Version de l'app et du serveur portée à 0.4.0 ; version minimale de l'app exigée par le serveur : 0.4.0.

## Critères d'acceptation

### Vérifiables par une commande sur la machine de développement

| Critère | Commande |
|---|---|
| Les relevés fictifs s'importent ; les soldes calculés sont ceux imprimés, à chaque solde du relevé. | `go test`, puis `flutter test`, test de bout en bout |
| Chaque relevé réel présent à la racine passe tous les contrôles ; dates et montants identiques à ceux des scripts d'origine. | `scripts/check-real-statements.sh` |
| Un relevé incohérent est refusé en entier, avec le contrôle en cause ; un fichier qui n'est pas un relevé aussi. | `go test`, tests de l'extraction et de la route |
| Un relevé déjà importé, non contigu ou d'un autre compte est refusé avec son motif ; le journal n'a pas changé. | `flutter test`, test de bout en bout |
| Une règle à deux mots-clés l'emporte sur une règle à un mot-clé ; une égalité de résultats différents est signalée, avec les règles en concurrence. | `flutter test` |
| Une règle créée pendant la validation classe aussitôt les autres lignes non validées ; les lignes validées ne changent pas. | `flutter test` |
| Chaque modèle de période donne la période du tableau H6, fins de mois et années bissextiles comprises. | `flutter test` |
| Serveur arrêté : les lignes se valident, en lot et une par une ; serveur relancé, un autre appareil les reçoit validées. | `flutter test`, test de bout en bout |
| Deux appareils importent le même relevé : aucune ligne en double après échange. | `flutter test`, test de bout en bout |
| Sur le compte détaillé, modifier un montant, une date ou un texte brut, saisir ou supprimer une ligne est refusé. | `flutter test` |
| Le dernier relevé se supprime avec ses lignes ; un relevé antérieur ne se supprime pas ; le relevé supprimé s'importe de nouveau. | `flutter test` |
| Le serveur écrit une copie de sa base avant de ranger un nouveau relevé, en garde 12, et n'en écrit pas pour un fichier déjà reçu. | `go test` |
| Le PDF d'origine se récupère par son empreinte ; son absence est signalée sans erreur. | `go test`, `flutter test` |
| L'import de 100 lignes et la confirmation de 500 propositions s'écrivent chacun en moins d'une seconde. | `flutter test`, mesure consignée |
| Une base de la version 0.3.0 s'ouvre avec la nouvelle version. | `flutter test`, test d'ouverture |
| L'app ne présente aucun défaut d'analyse et tous ses tests passent. | `flutter analyze && flutter test` dans `batz-ui` |
| Le serveur compile et ses tests passent. | `go vet ./... && go test -race ./...` dans `batz-web/src` |
| La version Ubuntu et l'APK se compilent ; l'image du serveur se construit, répond, et extrait le jeu d'essai comme attendu. | `flutter build linux`, `flutter build apk`, `docker build`, `/healthz`, `docker run … extract` |
| Aucun fichier personnel n'est suivi par git, et aucun terme personnel ne figure dans un fichier suivi. | `scripts/check-personal-files.sh` |

### Vérifiables sur GitHub, après le push

- Tous les contrôles de la CI sont au vert, compilation Windows et extraction dans l'image comprises.

### À vérifier par l'utilisateur, après déploiement du serveur 0.4.0 sur le NAS

- Les relevés réels de 2026 s'importent dans l'ordre, depuis janvier ; chaque solde final est celui imprimé.
- Un relevé réimporté est refusé ; un mois sauté est refusé, avec son motif.
- Une règle créée pendant la validation classe aussitôt les autres lignes.
- NAS éteint : la validation continue ; NAS rallumé, l'autre appareil reçoit les lignes validées.
- Le PDF d'origine se récupère depuis l'app.
- Une copie datée de la base est présente dans le dossier des données du NAS après un import.

## Hors de cette phase

- Remboursement rattaché à une dépense, redistribution, vue annuelle : phase 4.
- Solde du compte détaillé dans la fortune, soldes déclarés : phase 5.
- Reprise du fichier de règles des scripts d'origine : non prévue. Il contient une dizaine de règles, plus vite recréées pendant la validation des premiers relevés.
- Ventilation d'une ligne, autres banques, appariement de transferts entre comptes importés, historique antérieur à 2026 : plus tard, sans engagement.

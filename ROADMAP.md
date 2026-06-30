# ROADMAP — SnapStash (fil rouge DevOps)

> Projet fil rouge unique pour ma reconversion DevOps/SRE.
> Un seul projet, qui grossit brique par brique, du local jusqu'au cloud orchestré.
> Chaque brique = un module KodeKloud rendu *réel* dans ce projet.
>
> **SnapStash** = un service d'upload de photos avec génération de miniatures en arrière-plan.
> (Le nom n'a aucune importance, renomme-le si tu veux. Ce qui compte c'est l'architecture qu'il m'oblige à construire.)

---

## Pourquoi ce projet précis

Une appli d'upload d'images a besoin, *sans rien forcer*, de toutes les couches DevOps :

```
        Utilisateurs
             │
       Load Balancer        ← répartir le trafic (scaling)
             │
     Serveurs applicatifs   ← l'API qui reçoit l'upload (EC2 / conteneurs)
             │
       File de messages      ← « génère la miniature » envoyé en asynchrone (SQS)
             │
         Workers             ← consomment la file, créent les miniatures
             │
        Base de données      ← métadonnées des images (RDS / Postgres)
             │
       Stockage objet        ← les fichiers images eux-mêmes (S3)

   + Supervision (CloudWatch / Prometheus)
   + Infrastructure as Code (Terraform)
```

Chaque besoin du projet introduit naturellement un outil. C'est ça, le fil conducteur.

---

## Les règles du jeu (à ne JAMAIS enfreindre)

1. **Je ne commit jamais quelque chose que je ne peux pas expliquer moi-même.** Si je ne sais pas pourquoi une ligne est là, je l'apprends *avant* de la garder. C'est la règle anti-copier-coller.
2. **Je détruis toutes mes ressources cloud à la fin de chaque session.** `terraform destroy`, ou suppression manuelle. Un load balancer ou une base RDS oubliés un week-end = facture salée. Le cloud n'est pas un lab gratuit.
3. **Alertes de facturation AWS configurées AVANT de lancer quoi que ce soit** (voir Phase 3, brique 1). Non négociable.
4. **Tout est versionné dans Git.** Code, Dockerfile, manifests, Terraform. Si ce n'est pas dans le repo, ça n'existe pas.
5. **Une brique = une branche + une Pull Request.** Même seul. Ça construit le réflexe pro et ça documente ma progression.
6. **Je note « j'ai réussi quand… » et je ne passe à la brique suivante qu'une fois le critère atteint.**

> Note budget : le « free tier » AWS existe mais certains services (NAT Gateway, Application Load Balancer, RDS au-delà des petites instances) le dépassent vite, et les conditions du free tier changent régulièrement. Vérifie les conditions *actuelles* sur le site AWS au moment où tu commences, et garde la règle n°2 sacrée. Pour les phases 1 et 2 (local), et même certaines expérimentations Linux, ma VM GCP e2-micro déjà en place peut servir de bac à sable gratuit.

---

## Comment lire chaque brique

Chaque brique suit toujours la même structure :

- **KodeKloud** : le cours qui te donne la théorie.
- **Niveau** : *Découverte* / *Intermédiaire* / *Avancé* — pour suivre la montée en complexité.
- **Le concept** : l'idée expliquée simplement, avec une analogie.
- **Tu construis** : l'action concrète dans SnapStash.
- **Réussi quand** : le critère de validation.
- **Piège** : l'erreur classique à éviter (quand il y en a une).
- **IA** : comment utiliser Claude / Claude Code sur cette brique précise.

---
---

# PHASE 0 — Préparation et état d'esprit

**Objectif : poser les fondations de travail avant d'écrire une ligne.**

### B0.1 — Le dépôt et la discipline
- **Niveau** : Découverte
- **Le concept** : un projet DevOps vit dans *un* dépôt Git. Le dépôt est la source de vérité unique. Tout part de là.
- **Tu construis** : un repo GitHub `snapstash`. Un `README.md` qui décrit le projet en 3 lignes. Ce fichier `ROADMAP.md` à la racine. Un `.gitignore` Python.
- **Réussi quand** : le repo existe, je sais cloner/commit/push, ce fichier y est.
- **IA** : demande à Claude de te générer un `.gitignore` Python solide et de t'expliquer chaque catégorie qu'il ignore (pourquoi on n'envoie jamais `__pycache__`, `.env`, etc.).

### B0.2 — Le concept « 12 Factor App »
- **KodeKloud** : *12 Factor App* (0h45)
- **Niveau** : Découverte
- **Le concept** : 12 principes pour écrire une appli « cloud-ready ». Le plus important pour toi : **la configuration (mots de passe, URLs de base de données) vit dans des variables d'environnement, JAMAIS dans le code.** Analogie : ton code est une recette publique ; tes secrets sont les clés de ta maison. On ne tape pas les clés dans la recette.
- **Tu construis** : rien encore, mais tu lis les 12 facteurs et tu notes ceux que tu reconnais.
- **Réussi quand** : je peux expliquer pourquoi un mot de passe ne doit jamais être écrit en dur dans le code.
- **IA** : « Quiz-moi sur les 12 facteurs avec des exemples concrets tirés d'une appli d'upload d'images. »

---
---

# PHASE 1 — Fondations (local, vendor-neutral)

**Objectif : l'appli SnapStash tourne sur ma machine, son code est propre et versionné.**
**Ces outils marchent partout (AWS, GCP, Azure). C'est le socle.**

### B1.1 — Linux
- **KodeKloud** : *Linux for Beginners* (5h15) — déjà fait ✓
- **Niveau** : Découverte
- **Le concept** : un serveur cloud n'est qu'une machine Linux distante. Tout le DevOps repose sur le fait d'être à l'aise dans un terminal Linux : naviguer, lire des logs, gérer des permissions, des processus, des services.
- **Tu construis** : rien de spécifique, mais tu seras dans un terminal en permanence à partir de maintenant.
- **Réussi quand** : je suis à l'aise avec `cd`, `ls`, `cat`, `grep`, les permissions (`chmod`/`chown`), les processus (`ps`, `kill`), et `systemd` (`systemctl`).
- **IA** : utilise Claude comme « générateur de pannes » — « Décris-moi un symptôme Linux (un service qui ne démarre pas) et laisse-moi diagnostiquer étape par étape, corrige-moi si je me trompe. »

### B1.2 — Shell scripting
- **KodeKloud** : *Shell Scripts for Beginners* (2h)
- **Niveau** : Découverte
- **Le concept** : automatiser des suites de commandes. Le DevOps, c'est « ne jamais faire deux fois à la main ce qu'un script peut faire ». Tu connais déjà ça via tes `dlr-ffg()` en bash.
- **Tu construis** : un script `scripts/dev-setup.sh` qui installe les dépendances Python du projet en une commande.
- **Réussi quand** : `./scripts/dev-setup.sh` prépare mon environnement de dev sans que je tape la moindre commande de plus.
- **IA** : fais relire ton script par Claude pour les bonnes pratiques (`set -euo pipefail`, gestion des erreurs) et demande-lui d'expliquer *pourquoi* chacune.

### B1.3 — Git et GitHub (workflow pro)
- **KodeKloud** : *Git for Beginners* (1h15)
- **Niveau** : Découverte → Intermédiaire
- **Le concept** : Git suit l'historique de ton code ; GitHub l'héberge et permet la collaboration. Le workflow pro : on ne code jamais directement sur `main`. On crée une *branche*, on fait ses modifs, on ouvre une *Pull Request* (demande de fusion), on relit, on fusionne. Analogie : `main` est la version officielle publiée ; une branche est un brouillon que tu valides avant de l'intégrer.
- **Tu construis** : à partir de maintenant, **chaque brique = une branche + une PR.**
- **Réussi quand** : je maîtrise branche → commit → push → PR → merge, et je sais résoudre un conflit de merge sans paniquer.
- **IA** : quand tu as un conflit de merge, ne demande pas à Claude de le résoudre. Demande-lui de t'expliquer *ce que dit* le conflit, puis résous-le toi-même.

### B1.4 — Python (rafraîchissement léger)
- **KodeKloud** : *Python Basics Course* (1h30) — survol rapide, tu connais déjà
- **Niveau** : Découverte
- **Le concept** : ici Python est un *moyen*, pas le but. L'objectif n'est pas de devenir développeur mais d'avoir une appli à déployer. (C'est pour ça qu'on choisit Python que tu maîtrises déjà, et pas Golang : on ne veut pas que le code devienne la difficulté.)
- **Tu construis** : la base de SnapStash — une petite API avec **Flask** (framework web Python minimal). Un seul endpoint pour commencer : `GET /health` qui répond `{"status": "ok"}`.
- **Réussi quand** : `flask run` démarre, et `curl localhost:5000/health` me répond OK.
- **IA** : « Explique-moi l'approche d'une API Flask d'upload, puis laisse-moi l'écrire ; je te la ferai relire après. » (pattern *explique puis je fais*).

### B1.5 — SnapStash v0 : l'appli locale complète
- **Niveau** : Intermédiaire
- **Le concept** : une appli « 3-tiers » classique = présentation (frontend) + logique (API) + données (base). Tu assembles les trois.
- **Tu construis** :
  - une API Flask avec `POST /upload` (reçoit une image) et `GET /images` (liste les images) ;
  - le stockage des fichiers dans un dossier local `./uploads/` pour l'instant ;
  - les métadonnées (nom, date, taille) dans une base **PostgreSQL** locale ;
  - une page HTML toute simple pour uploader et voir la galerie ;
  - **toute la config (URL de la base, dossier d'upload) en variables d'environnement** (facteur 12 appliqué !).
- **Réussi quand** : j'uploade une image depuis le navigateur, je la revois dans la galerie, et les métadonnées sont en base. Le tout en local.
- **Piège** : ne passe pas trois semaines sur le CSS. Le frontend doit être *moche et fonctionnel*. Toute la valeur DevOps est dans les couches au-dessus.
- **IA** : Claude Code peut t'aider à scaffolder le frontend HTML basique (c'est du temps perdu de le faire à la main). Mais l'API et la connexion à la base, écris-les toi-même.

**🏁 Jalon Phase 1 : SnapStash tourne en local, code propre sur GitHub avec un historique de PR.**

---
---

# PHASE 2 — Conteneurisation (local)

**Objectif : SnapStash tourne dans des conteneurs, identique partout.**

### B2.1 — Docker
- **KodeKloud** : *Docker for Absolute Beginners* (4h) — déjà fait ✓
- **Niveau** : Intermédiaire
- **Le concept** : un conteneur empaquette ton appli *avec* tout ce dont elle a besoin (Python, bibliothèques, config) dans une boîte qui tourne pareil sur ta machine, sur celle d'un collègue, ou sur un serveur AWS. Analogie : un conteneur maritime — peu importe le bateau ou le port, le contenu et les dimensions sont standardisés. Fini le « ça marche sur ma machine ».
- **Tu construis** : un `Dockerfile` qui transforme ton API Flask en image Docker. Idéalement un **multi-stage build** (une étape pour installer, une étape finale légère) — tu connais déjà le concept.
- **Réussi quand** : `docker build` produit une image, `docker run` lance mon API accessible sur un port.
- **Piège** : ne mets jamais de secret dans le Dockerfile ni dans l'image. La config arrive au *runtime* via variables d'environnement.
- **IA** : fais relire ton Dockerfile pour optimiser la taille de l'image et l'ordre des couches (caching). Demande l'explication de chaque optimisation.

### B2.2 — Docker Compose
- **KodeKloud** : couvert dans *Docker for Absolute Beginners*
- **Niveau** : Intermédiaire
- **Le concept** : ton appli n'est pas seule — elle a besoin d'une base de données. Docker Compose décrit *plusieurs* conteneurs et leurs liens dans un seul fichier `docker-compose.yml`, et les lance ensemble. Analogie : un chef d'orchestre qui démarre tous les musiciens en même temps, accordés.
- **Tu construis** : un `docker-compose.yml` qui lance ensemble (1) ton API, (2) un PostgreSQL, et (3) **MinIO** — un stockage objet compatible S3 qui tourne en local. Ça prépare *exactement* la migration vers S3 en Phase 3, mais gratuitement et hors-ligne.
- **Réussi quand** : `docker compose up` démarre toute la stack ; l'upload écrit dans MinIO ; les métadonnées dans Postgres.
- **Piège** : les conteneurs se parlent par *nom de service*, pas par `localhost`. Comprendre ce point évite 80 % des galères réseau Docker.
- **IA** : quand un conteneur n'arrive pas à joindre la base, demande à Claude de t'expliquer le réseau Docker (DNS interne) plutôt que de te donner le `docker-compose.yml` corrigé tout fait.

**🏁 Jalon Phase 2 : `docker compose up` lance toute la stack SnapStash. Mon appli est portable.**

---
---

# PHASE 3 — Le cloud, premières marches (AWS, à la main)

**Objectif : sortir SnapStash de ma machine et le poser sur de vraies ressources AWS.**
**On fait tout *manuellement* d'abord — pour comprendre. On automatisera en Phase 6.**
**(C'est ici qu'entrent les étapes 1 à 6 du texte Reddit.)**

### B3.1 — Compte AWS, IAM, facturation, CLI
- **Niveau** : Découverte
- **Le concept** : AWS, c'est des centaines de services accessibles via un compte. **IAM** (Identity and Access Management) gère *qui* a le droit de faire *quoi*. Règle d'or de sécurité : on n'utilise JAMAIS le compte « root » au quotidien ; on crée un utilisateur IAM avec juste les droits nécessaires. Analogie : le root est le propriétaire avec le passe-partout ; tu travailles avec un badge d'accès limité.
- **Tu construis** :
  - un compte AWS ;
  - **des alertes de facturation** (AWS Budgets) — par ex. une alerte à 5€, une à 20€. **C'est la première chose, avant tout le reste.**
  - un utilisateur IAM (pas root) avec accès programmatique ;
  - l'**AWS CLI** installée et configurée en local (`aws configure`).
- **Réussi quand** : `aws sts get-caller-identity` me répond avec mon utilisateur IAM, et mes alertes budget sont actives.
- **Piège** : ne génère pas de clés d'accès pour le compte root. Jamais. Et ne commit jamais tes clés AWS dans Git (c'est la fuite n°1 sur GitHub, des bots les scannent en secondes).
- **IA** : « Explique-moi le modèle IAM (users, groups, roles, policies) avec une analogie, et aide-moi à écrire une policy IAM minimale pour ce projet. »

### B3.2 — EC2 : ton premier serveur
- **KodeKloud** : *DevOps Prerequisite course* (bases EC2/Linux/réseau)
- **Niveau** : Intermédiaire
- **Le concept** : **EC2** = louer une machine virtuelle Linux dans le cloud AWS. C'est littéralement un ordinateur distant auquel tu te connectes en SSH. Tu retrouves tout ton Linux de la Phase 1.
- **Tu construis** : lancer une instance EC2 Linux (petite, éligible free tier), générer une *key pair* (clé SSH), te connecter en SSH, installer Docker dessus, et y faire tourner ton conteneur SnapStash.
- **Réussi quand** : mon conteneur SnapStash tourne sur une vraie machine AWS, pas sur mon laptop.
- **Piège** : **éteins/supprime l'instance après chaque session.** (Règle du jeu n°2.)
- **IA** : « Donne-moi les commandes pour installer Docker sur une EC2 Amazon Linux, et explique chaque étape » — puis exécute-les toi-même en comprenant.

### B3.3 — Réseau : VPC, subnets, route tables
- **KodeKloud** : *DevOps Prerequisite course* (networking basics) + section networking de *Docker*
- **Niveau** : Avancé (le réseau est le sujet le plus déroutant au début — c'est normal)
- **Le concept** : un **VPC** (Virtual Private Cloud) est ton réseau privé isolé dans AWS. Dedans, des **subnets** (sous-réseaux) : un *public* (accessible depuis internet) et un *privé* (caché, pour la base de données). Une **route table** dit où va le trafic. Analogie : le VPC est un immeuble ; les subnets sont les étages ; certains étages ont une porte sur la rue (public), d'autres non (privé, plus sûr).
- **Tu construis** : ton propre VPC avec un subnet public (pour l'appli) et un subnet privé (pour la future base RDS), un Internet Gateway pour le public.
- **Réussi quand** : je comprends pourquoi ma base de données doit vivre dans le subnet privé et mon appli dans le public.
- **Piège** : le **NAT Gateway** (qui donne internet au subnet privé) est *payant à l'heure* et hors free tier. Attention au coût ; supprime-le après usage.
- **IA** : c'est la couche la plus abstraite. Demande à Claude des schémas ASCII et des analogies jusqu'à ce que ça clique. « Re-explique-moi avec une autre analogie. »

### B3.4 — Exposer à internet : Security Groups
- **KodeKloud** : *DevOps Prerequisite course* (ips and ports)
- **Niveau** : Intermédiaire
- **Le concept** : un **Security Group** est un pare-feu virtuel autour de ton instance. Il dit quel trafic entre et sort. Analogie : le videur à l'entrée — il ne laisse passer que ce qui est sur la liste. Pour une appli web : SSH (port 22) seulement depuis ton IP, HTTP (80) et HTTPS (443) depuis partout.
- **Tu construis** : un Security Group qui ouvre le port de ton appli, puis tu ouvres l'IP publique de ton EC2 dans ton navigateur.
- **Réussi quand** : SnapStash est accessible depuis internet via l'IP publique de l'instance.
- **Piège** : n'ouvre JAMAIS le port 22 (SSH) à `0.0.0.0/0` (tout internet) en réflexe. Restreins à ton IP. Sinon des bots tenteront de s'y connecter en continu.
- **IA** : « Quelle est la différence entre un Security Group et une Network ACL ? Quand utiliser l'un ou l'autre ? »

### B3.5 — Stockage objet : S3
- **KodeKloud** : (concept générique ; tu as déjà MinIO en local)
- **Niveau** : Intermédiaire
- **Le concept** : **S3** (Simple Storage Service) stocke des fichiers (« objets ») de façon durable et quasi-illimitée, *en dehors* de ton serveur. Pourquoi c'est crucial : si ton serveur meurt, tes images survivent. Analogie : un garde-meuble externe — ta maison (le serveur) peut brûler, tes affaires sont ailleurs en sécurité.
- **Tu construis** : tu *refactorises* SnapStash pour qu'il uploade les images vers un bucket S3 (via le SDK AWS `boto3`) au lieu du dossier local. Comme tu avais MinIO (compatible S3) en Phase 2, le changement de code est minime — c'est la beauté du choix d'architecture.
- **Réussi quand** : mes images uploadées atterrissent dans S3, et l'appli les ressert depuis S3.
- **Piège** : un bucket S3 mal configuré peut être public par accident → fuite de données. Vérifie que l'accès public est bloqué et que l'appli accède via un *rôle IAM*, pas des clés en dur.
- **IA** : « Explique-moi comment donner à mon EC2 le droit d'écrire dans S3 *sans* mettre de clés dans le code (rôle IAM attaché à l'instance). »

### B3.6 — Base de données managée : RDS
- **KodeKloud** : *DevOps Prerequisite course* (database basics)
- **Niveau** : Intermédiaire
- **Le concept** : **RDS** (Relational Database Service) = AWS gère ta base PostgreSQL pour toi (sauvegardes, mises à jour, disponibilité). Tu ne fais plus l'admin de la base, tu l'utilises. Analogie : au lieu de cultiver ton potager (installer/maintenir Postgres toi-même), tu t'abonnes à un service de livraison de légumes.
- **Tu construis** : une instance RDS PostgreSQL dans ton subnet *privé*, et tu reconnectes SnapStash dessus (via variable d'environnement, facteur 12).
- **Réussi quand** : mon appli sur EC2 écrit ses métadonnées dans RDS ; la base n'est PAS accessible depuis internet (subnet privé).
- **Piège** : RDS dépasse vite le free tier selon l'instance. Choisis la plus petite, et supprime après session (avec snapshot si tu veux garder les données).
- **IA** : « Pourquoi place-t-on la base en subnet privé ? Quel Security Group autorise l'EC2 à parler à RDS et rien d'autre ? »

**🏁 Jalon Phase 3 : SnapStash tourne sur AWS, accessible depuis internet, images dans S3, données dans RDS. Tout monté à la main — je comprends chaque pièce.**

---
---

# PHASE 4 — Automatiser le déploiement (CI/CD)

**Objectif : un `git push` construit, teste et publie mon image automatiquement.**

### B4.1 — CI : Intégration Continue
- **KodeKloud** : *Jenkins For Beginners* (4h20)
- **Niveau** : Intermédiaire
- **Le concept** : **CI** = à chaque push, une machine vérifie automatiquement ton code (formatage, tests). Tu connais déjà ça par cœur via ton métier QA — c'est ton terrain. Analogie : un correcteur automatique qui relit chaque copie avant qu'elle ne soit acceptée.
- **Tu construis** : un pipeline qui, à chaque PR, lance le linter et les tests. **Apprends Jenkins (KodeKloud) pour la culture du marché, mais implémente d'abord avec GitHub Actions** que tu as déjà sous la main — c'est plus simple et c'est partout aujourd'hui.
- **Réussi quand** : une PR avec du code cassé est automatiquement bloquée par le pipeline.
- **IA** : ton terrain QA. Demande à Claude de critiquer ta couverture de tests, pas de l'écrire à ta place.

### B4.2 — CD : Livraison Continue
- **KodeKloud** : *Jenkins For Beginners* (pipelines)
- **Niveau** : Avancé
- **Le concept** : **CD** = après les tests, le pipeline *construit l'image Docker et la publie* automatiquement dans un registre. Plus de build manuel. Le registre AWS s'appelle **ECR** (Elastic Container Registry).
- **Tu construis** : le pipeline pousse l'image SnapStash vers ECR (ou GHCR de GitHub) à chaque merge sur `main`.
- **Réussi quand** : un merge sur `main` produit automatiquement une nouvelle image taguée dans le registre, sans que je touche à rien.
- **Piège** : ne mets jamais tes identifiants AWS en clair dans le pipeline. Utilise les *secrets* du CI (GitHub Secrets) ou, mieux, l'authentification OIDC.
- **IA** : « Explique-moi OIDC entre GitHub Actions et AWS : pourquoi c'est plus sûr que des clés d'accès stockées en secret. »

**🏁 Jalon Phase 4 : mon code part en production de façon automatisée et testée. Plus de manipulation manuelle d'images.**

---
---

# PHASE 5 — Scaling et résilience (AWS)

**Objectif : SnapStash supporte la charge et traite les uploads en asynchrone.**
**(Étapes 7 à 10 du texte Reddit. On a volontairement retiré Kafka — trop complexe ici.)**

### B5.1 — Load Balancer
- **Niveau** : Avancé
- **Le concept** : un **Load Balancer** (ALB, Application Load Balancer) répartit le trafic entrant entre plusieurs serveurs. Si l'un tombe, les autres encaissent. Analogie : à la caisse d'un supermarché, plusieurs caisses ouvertes et un agent qui dirige chaque client vers la moins occupée.
- **Tu construis** : 2 instances EC2 identiques faisant tourner SnapStash, derrière un ALB qui distribue les requêtes.
- **Réussi quand** : je peux éteindre une instance et le service reste accessible (l'ALB redirige sur l'autre).
- **Piège** : l'ALB est payant à l'heure, hors free tier. Détruis-le après session.
- **IA** : « Comment l'ALB sait-il qu'une instance est en bonne santé ? Explique-moi les *health checks*. »

### B5.2 — Auto Scaling
- **Niveau** : Avancé
- **Le concept** : **Auto Scaling** ajoute ou retire automatiquement des serveurs selon la charge (ex. CPU > 70 % → ajoute une instance). Tu ne scales plus à la main. Analogie : le supermarché ouvre une caisse de plus quand la file s'allonge, et la ferme quand c'est calme.
- **Tu construis** : un Auto Scaling Group basé sur un *launch template* (modèle d'instance), avec min/max d'instances et une règle de scaling sur le CPU.
- **Réussi quand** : sous charge simulée, AWS crée automatiquement une instance supplémentaire, puis la retire au repos.
- **IA** : demande à Claude de te générer un petit script de test de charge (ex. avec `hey` ou `ab`) pour déclencher le scaling et l'observer.

### B5.3 — Asynchrone : la file SQS et les workers
- **Niveau** : Avancé
- **Le concept** : générer une miniature prend du temps. Si on le fait pendant l'upload, l'utilisateur attend. **SQS** (Simple Queue Service) est une file d'attente : l'API y dépose un message « génère la miniature de l'image X » et répond *immédiatement* à l'utilisateur ; des **workers** séparés consomment la file et font le travail tranquillement. Analogie : au resto, le serveur prend ta commande (rapide) et la met au passe ; la cuisine (les workers) la traite ensuite. Le serveur n'attend pas que le plat soit prêt pour servir les autres tables.
- **Tu construis** :
  - l'API dépose un message dans SQS après chaque upload ;
  - un *worker* (un autre conteneur/processus) lit la file, télécharge l'image depuis S3, génère une miniature, la repose dans S3, met à jour RDS.
- **Réussi quand** : j'uploade une grosse image, la réponse est instantanée, et la miniature apparaît quelques secondes plus tard.
- **Piège** : gère le cas où un worker plante en plein traitement (le message doit pouvoir être re-traité). Découvre la notion de *dead-letter queue*.
- **IA** : « Explique-moi la *visibility timeout* SQS et la *dead-letter queue* : que se passe-t-il si mon worker crashe au milieu ? »
- **Note** : Kafka (mentionné dans le texte Reddit) fait la même famille de choses mais en bien plus complexe. **On le garde pour bien plus tard**, voire jamais à ce stade.

### B5.4 — Supervision : CloudWatch (ta première vraie saveur de SRE)
- **Niveau** : Intermédiaire → Avancé
- **Le concept** : en production, **si tu ne mesures pas, tu es aveugle**. **CloudWatch** collecte les métriques (CPU, mémoire, taux d'erreur, latence), les logs, et déclenche des alertes. C'est le cœur du métier SRE. Analogie : le tableau de bord d'une voiture — sans compteurs, tu roules les yeux fermés.
- **Tu construis** : des dashboards CloudWatch (latence de l'API, taille de la file SQS, erreurs), et une alarme (ex. « taux d'erreur > 5 % » ou « file SQS qui s'accumule »).
- **Réussi quand** : si SnapStash commence à mal tourner, je reçois une alerte *avant* que tout soit cassé.
- **IA** : « Quelles sont les 4 métriques d'or du SRE (latence, trafic, erreurs, saturation) et lesquelles surveiller en priorité sur mon appli ? »

**🏁 Jalon Phase 5 : SnapStash scale tout seul, traite les images en asynchrone, et je le surveille. C'est une vraie archi de production.**

### B5.5 — (Bonus) Cache avec Redis
- **Niveau** : Avancé
- **Le concept** : **Redis** est une base de données qui vit *en mémoire* (RAM), donc extrêmement rapide. On ne s'en sert pas comme base principale mais comme couche d'accélération. Analogie : RDS est la grande bibliothèque bien rangée où il faut marcher jusqu'au rayon ; Redis est la pile de livres sur ton bureau, ceux que tu consultes tout le temps — instantanés, mais moins durables. L'usage clé ici est le **cache** : éviter de retaper la base pour une donnée déjà demandée.
- **Tu construis** : tu mets en cache la route `GET /images`. La première fois, tu lis PostgreSQL et tu ranges le résultat dans Redis ; les fois suivantes, tu sers depuis Redis sans toucher la base (pattern « cache-aside »). Tu gères l'**invalidation** : vider le cache quand une nouvelle image est uploadée, pour ne pas servir une galerie périmée. En local via Docker Compose, puis sur AWS via **ElastiCache** (le Redis managé, comme RDS l'est pour Postgres).
- **Réussi quand** : ma galerie se charge depuis Redis au lieu de taper la base à chaque fois, et le cache se met à jour correctement quand j'ajoute une image.
- **Piège** : l'invalidation de cache est l'un des vrais problèmes difficiles de l'informatique. Un cache mal vidé sert des données fausses ; un cache trop vidé ne sert à rien. Réfléchis bien au *quand* vider.
- **IA** : « Explique-moi le pattern cache-aside et les stratégies d'invalidation. Quand vider mon cache dans SnapStash, et pourquoi ? » — puis implémente toi-même la logique.

---
---

# PHASE 6 — Infrastructure as Code (le moment charnière)

**Objectif : recréer TOUTE l'infra AWS en code, reproductible et versionnée.**
**(Étape 11 du texte Reddit + Terraform de KodeKloud convergent ici. C'est LA brique qui sépare un débutant d'un DevOps.)**

### B6.1 — Terraform : les fondations
- **KodeKloud** : *Terraform for Beginners* (4h45)
- **Niveau** : Avancé
- **Le concept** : jusqu'ici tu as tout cliqué/tapé à la main dans la console AWS. **Terraform** te permet de *décrire* ton infra (VPC, EC2, S3, RDS…) dans des fichiers texte, et de la créer/détruire d'une commande. Plus de clics. Analogie : au lieu de construire un meuble à la main à chaque fois, tu écris le plan une fois ; n'importe qui (ou une machine) peut le reconstruire à l'identique. C'est aussi ce qui rend la règle « détruis tout après session » triviale : `terraform destroy`.
- **Tu construis** : tu réécris ton VPC, ton EC2, ton Security Group, ton S3, ton RDS en Terraform. Tu détruis tout ce que tu avais fait à la main, et tu le recrées avec `terraform apply`.
- **Réussi quand** : `terraform apply` reconstruit toute mon infra SnapStash depuis zéro, et `terraform destroy` la supprime intégralement.
- **Piège** : **ne saute pas cette phase sous prétexte que « ça marche déjà à la main ».** C'est ici qu'est 80 % de la valeur DevOps réelle et ce que les recruteurs veulent voir.
- **IA** : pattern binôme — écris ton premier fichier `.tf`, fais-le relire par Claude Code, demande-lui d'expliquer ce qui cloche plutôt que de te le réécrire.

### B6.2 — Terraform : state et remote state
- **KodeKloud** : *Terraform for Beginners* (terraform state, remote state)
- **Niveau** : Avancé
- **Le concept** : Terraform garde un fichier d'*état* (`state`) qui mémorise ce qu'il a créé. Si tu travailles à plusieurs (ou depuis plusieurs machines), cet état doit être partagé et verrouillé, sinon chaos. On le stocke dans S3 avec un verrou. Analogie : le registre officiel de ce qui existe — il ne doit y en avoir qu'un, et deux personnes ne peuvent pas l'écrire en même temps.
- **Tu construis** : un *remote state* dans un bucket S3 dédié.
- **Réussi quand** : mon état Terraform vit dans S3, pas sur mon laptop.
- **IA** : « Pourquoi ne jamais commit le fichier terraform.tfstate dans Git ? Que contient-il de sensible ? »

### B6.3 — Terraform : modules
- **KodeKloud** : *Terraform for Beginners* (modules, functions)
- **Niveau** : Avancé
- **Le concept** : un **module** est un bloc Terraform réutilisable (ex. « un module réseau », « un module base de données »). Ça évite de copier-coller. Analogie : une fonction en programmation — tu la définis une fois, tu l'appelles partout.
- **Tu construis** : tu refactorises ton Terraform en modules (`network`, `compute`, `database`).
- **Réussi quand** : mon infra est découpée en modules propres et réutilisables.
- **IA** : « Quelle est une bonne structure de dossiers pour un projet Terraform avec environnements dev/prod ? »

### B6.4 — (Bonus) Ansible : la configuration
- **Niveau** : Avancé
- **Le concept** : Terraform *crée* les serveurs ; **Ansible** les *configure* (installe les paquets, déploie l'appli). Les deux sont complémentaires. Analogie : Terraform construit la maison vide, Ansible installe les meubles et la peinture. Tu as déjà touché à Ansible pour ton process avec Dickson Data — c'est l'occasion d'approfondir.
- **Tu construis** : un playbook Ansible qui installe Docker et lance SnapStash sur une instance fraîchement créée par Terraform.
- **Réussi quand** : Terraform crée la VM, Ansible la configure, et SnapStash tourne — sans aucune commande manuelle.
- **IA** : « Quand utiliser Ansible plutôt que le user-data d'EC2 ou un conteneur ? »

**🏁 Jalon Phase 6 : toute mon infrastructure est du code versionné. Je peux tout détruire et tout reconstruire en deux commandes. C'est le tournant DevOps.**

---
---

# PHASE 7 — Orchestration : Kubernetes et au-delà

**Objectif : faire tourner SnapStash sur un cluster Kubernetes, en GitOps.**
**(Le bloc avancé de KodeKloud. On commence en LOCAL — gratuit — avant le cloud.)**

### B7.1 — Kubernetes : les bases
- **KodeKloud** : *Kubernetes for Beginners* (6h) — en cours pour toi
- **Niveau** : Avancé
- **Le concept** : quand tu as beaucoup de conteneurs à faire tourner, surveiller, redémarrer, scaler… le faire à la main devient impossible. **Kubernetes (K8s)** orchestre tout ça automatiquement. Concepts clés : un **pod** (un ou plusieurs conteneurs qui tournent ensemble), un **deployment** (qui maintient N copies de ton appli vivantes), un **service** (point d'accès stable vers tes pods). Analogie : K8s est le chef d'orchestre d'une grande scène — il s'assure que chaque musicien (conteneur) est là, joue juste, et le remplace instantanément si l'un défaille.
- **Tu construis** : **d'abord en local** avec `kind` ou `minikube` (un cluster K8s sur ton laptop, gratuit). Tu écris les manifests (deployment, service) pour déployer SnapStash dessus.
- **Réussi quand** : SnapStash tourne sur mon cluster K8s local ; si je supprime un pod, K8s en recrée un automatiquement.
- **Piège** : ne commence PAS K8s sur AWS (EKS) — c'est payant et complexe. Maîtrise-le en local d'abord. Le passage au cloud viendra naturellement après.
- **IA** : « Explique-moi la différence entre un pod, un deployment et un service avec mon appli SnapStash comme exemple concret. »

### B7.2 — Helm : empaqueter
- **KodeKloud** : *Helm for Beginners* (2h15)
- **Niveau** : Avancé
- **Le concept** : déployer une appli sur K8s demande plusieurs fichiers manifests. **Helm** les empaquette dans un « chart » paramétrable (comme un installateur). Analogie : Helm est à K8s ce qu'`apt` est à Linux — un gestionnaire de paquets.
- **Tu construis** : un chart Helm pour SnapStash, avec des valeurs différentes pour dev et prod.
- **Réussi quand** : `helm install snapstash` déploie toute mon appli sur le cluster en une commande.
- **IA** : « Quelle est la différence entre `values.yaml` et les templates dans un chart Helm ? »

### B7.3 — GitOps avec ArgoCD
- **KodeKloud** : *GitOps with ArgoCD* (6h)
- **Niveau** : Avancé
- **Le concept** : **GitOps** = ton dépôt Git devient la *source de vérité unique* de ce qui tourne en production. Tu ne déploies plus en lançant des commandes ; tu modifies Git, et **ArgoCD** synchronise automatiquement le cluster avec l'état décrit dans Git. Analogie : Git est la partition officielle ; ArgoCD est le chef qui s'assure que l'orchestre joue *exactement* ce qui est écrit, et corrige toute déviation.
- **Tu construis** : ArgoCD installé, qui surveille ton repo et déploie SnapStash automatiquement à chaque changement de manifest.
- **Réussi quand** : je modifie une valeur dans Git, et ArgoCD met à jour le cluster tout seul, sans que je touche `kubectl`.
- **IA** : « Quelle est la différence entre l'approche *push* (CI classique qui déploie) et *pull* (GitOps/ArgoCD) ? Pourquoi GitOps est-il plus sûr ? »

### B7.4 — Observabilité : Prometheus + Grafana
- **KodeKloud** : *Prometheus Certified Associate (PCA)* (6h45)
- **Niveau** : Avancé
- **Le concept** : l'équivalent open-source et standard de l'industrie pour la supervision. **Prometheus** collecte les métriques, **Grafana** les affiche en dashboards. C'est le pilier de l'observabilité moderne et du métier SRE. Analogie : Prometheus est le réseau de capteurs, Grafana est la salle de contrôle avec tous les écrans.
- **Tu construis** : Prometheus qui scrape les métriques de SnapStash et du cluster, Grafana avec des dashboards (latence, erreurs, état des pods), et des règles d'alerte.
- **Réussi quand** : j'ai un dashboard Grafana qui me montre la santé de SnapStash en temps réel, avec alertes.
- **IA** : « Explique-moi PromQL avec 5 requêtes utiles pour surveiller une API. »

### B7.5 — (Optionnel, expert) Istio : Service Mesh
- **KodeKloud** : *Istio Service Mesh* (2h45)
- **Niveau** : Expert
- **Le concept** : quand tu as beaucoup de services qui se parlent, un **service mesh** gère la communication entre eux (sécurité, *retries*, *timeouts*, traçage) sans modifier le code des applis. Analogie : un système de routage postal intelligent entre tous les bureaux d'une grande entreprise. C'est de l'expert — **n'y va que si tout le reste est solide.**
- **Réussi quand** : (optionnel) je comprends ce qu'apporte un mesh et quand il devient nécessaire.
- **IA** : garde Istio pour la fin. Demande à Claude « ai-je *vraiment* besoin d'un service mesh à mon échelle ? » — la réponse honnête est souvent non, et c'est une bonne leçon d'architecture.

**🏁 Jalon Phase 7 : SnapStash tourne sur Kubernetes, déployé en GitOps, supervisé par Prometheus/Grafana. Niveau production sérieux.**

---
---

# PHASE 8 — Finition, SRE et préparation carrière

**Objectif : transformer tout ça en atout pour décrocher un poste.**

### B8.1 — Le pont vers le SRE
- **Niveau** : Intermédiaire
- **Le concept** : tu hésitais entre DevOps et SRE. La vérité : tu as construit la base *commune* aux deux. Le **SRE** ajoute une rigueur sur la *fiabilité* : les **SLO** (Service Level Objectives — ex. « 99,9 % des uploads réussissent »), les **SLI** (les mesures correspondantes), les *error budgets*, la gestion d'incidents. **Et ton passé QA Automation est un pont naturel vers le SRE** : mentalité de test, automatisation, obsession de la fiabilité. C'est un atout à mettre en avant en entretien, pas un détail.
- **Tu construis** : définis 2-3 SLO pour SnapStash et mesure-les via Prometheus.
- **Réussi quand** : je peux dire « mon objectif est 99,5 % de disponibilité » et montrer comment je le mesure.

### B8.2 — Le portfolio
- **Niveau** : Intermédiaire
- **Tu construis** :
  - un `README.md` impeccable sur le repo SnapStash, avec un schéma d'architecture ;
  - un article de blog (ou un fil LinkedIn) « comment j'ai construit une plateforme cloud de A à Z » ;
  - un diagramme de l'archi finale.
- **Réussi quand** : un recruteur qui ouvre mon GitHub comprend en 2 minutes que je sais faire du vrai DevOps.

### B8.3 — Préparation entretiens
- **KodeKloud** : *DevOps Interview Preparation Course* (5h30)
- **Niveau** : Intermédiaire
- **Le concept** : ce projet est ta meilleure réponse à 80 % des questions d'entretien DevOps. Pour chaque outil, tu pourras raconter *un problème réel que tu as résolu*, pas réciter une définition.
- **Réussi quand** : je peux expliquer au tableau chaque couche de SnapStash et justifier chaque choix.
- **IA** : « Fais-moi un entretien blanc DevOps junior basé sur mon projet SnapStash. Pose-moi des questions de plus en plus dures. »

**🏁 Jalon final : je ne dis plus "je me forme au DevOps". Je dis "j'ai construit et déployé une plateforme cloud complète", et je peux le prouver ligne par ligne.**

---
---

# Comment utiliser l'IA tout au long (le mode d'emploi)

La règle qui prime sur tout : **l'IA est un tuteur, pas un distributeur de réponses.** Si elle code à ta place, tu ne construis aucun muscle. Quatre usages, dans l'ordre de préférence :

1. **Tuteur socratique.** Avant de coder une brique : « Explique-moi le concept, l'approche, les pièges. Quiz-moi. Challenge mon raisonnement. » → *puis tu implémentes toi-même.*
2. **Pattern "explique puis je fais".** Tu demandes le *quoi* et le *pourquoi*, tu écris le *comment*, et seulement après tu fais relire.
3. **Claude Code en binôme, pas en pilote auto.** Fais-lui *relire* ton Terraform/tes manifests et expliquer ce qui cloche, plutôt que de les lui faire écrire. Tu gardes le clavier sur la logique ; tu délègues le scaffolding ennuyeux (frontend HTML basique, boilerplate).
4. **Générateur de pannes.** « Casse mon déploiement / décris-moi un symptôme, à moi de diagnostiquer. » C'est le meilleur entraînement break-fix, et exactement ce que tu cherchais à la place de labs déconnectés.

**Le seul vrai anti-pattern** : copier-coller une config que tu ne comprends pas. Si ça arrive, arrête-toi et applique la règle du jeu n°1.

---

# Comment Claude Code utilise CE fichier

Pose ce `ROADMAP.md` à la racine du repo `snapstash`. Quand tu ouvres une session Claude Code :

- Il lit ce fichier et sait *où tu en es* (grâce aux cases cochées ci-dessous) et *où tu vas*.
- Donne-lui des consignes de binôme, pas de pilote : « Je suis sur la brique B6.1. Relis mon `main.tf`, explique-moi ce qui ne va pas, ne le réécris pas. »
- Tu peux lui demander de mettre à jour les cases de progression au fil de l'eau.

---

# Suivi de progression

## Phase 0 — Préparation
- [ ] B0.1 Dépôt et discipline
- [ ] B0.2 12 Factor App

## Phase 1 — Fondations (local)
- [x] B1.1 Linux *(déjà fait)*
- [ ] B1.2 Shell scripting
- [ ] B1.3 Git / GitHub (workflow PR)
- [ ] B1.4 Python (rafraîchissement)
- [ ] B1.5 SnapStash v0 local

## Phase 2 — Conteneurisation
- [x] B2.1 Docker *(déjà fait)*
- [ ] B2.2 Docker Compose (+ MinIO)

## Phase 3 — Cloud à la main (AWS)
- [ ] B3.1 Compte / IAM / facturation / CLI
- [ ] B3.2 EC2
- [ ] B3.3 VPC / réseau
- [ ] B3.4 Security Groups
- [ ] B3.5 S3
- [ ] B3.6 RDS

## Phase 4 — CI/CD
- [ ] B4.1 CI (tests automatiques)
- [ ] B4.2 CD (build + push image)

## Phase 5 — Scaling et résilience
- [ ] B5.1 Load Balancer
- [ ] B5.2 Auto Scaling
- [ ] B5.3 SQS + workers (async)
- [ ] B5.4 CloudWatch
- [ ] B5.5 Cache avec Redis (bonus)

## Phase 6 — Infrastructure as Code
- [ ] B6.1 Terraform fondations
- [ ] B6.2 Terraform state / remote state
- [ ] B6.3 Terraform modules
- [ ] B6.4 Ansible (bonus)

## Phase 7 — Orchestration
- [ ] B7.1 Kubernetes (local)
- [ ] B7.2 Helm
- [ ] B7.3 GitOps / ArgoCD
- [ ] B7.4 Prometheus / Grafana
- [ ] B7.5 Istio (optionnel)

## Phase 8 — Finition et carrière
- [ ] B8.1 Pont SRE (SLO/SLI)
- [ ] B8.2 Portfolio
- [ ] B8.3 Préparation entretiens

---

*Une brique à la fois. Je ne passe à la suivante qu'une fois le « Réussi quand… » atteint.*
*Je détruis mes ressources cloud après chaque session.*
*Je ne commit jamais ce que je ne peux pas expliquer.*
# PRODUCT-ROADMAP — SnapStash → Site d'affiliation Amazon

> **Feuille de route PRODUIT** : le *quoi construire*.
> Complémentaire de `ROADMAP.md` (le *comment déployer*, ma progression DevOps).
> Cette feuille se CALE sur la roadmap technique : chaque couche produit ne se
> construit qu'une fois la phase roadmap correspondante atteinte.

**But final** : remplacer mon bio-link c8ke par ma propre page d'affiliation
Amazon — articles cliquables (clic → Amazon), recherche, filtres par catégorie,
ajout via bot Telegram, vérification auto de disponibilité, metrics.

**Règle d'or** : une couche à la fois. Chaque couche est finie, déployée et
utilisable EN LIGNE avant de passer à la suivante.

---

## ⚠️ Ma priorité : l'INFRASTRUCTURE, pas le code applicatif

- **Infra** (Docker, K8s, Terraform, CI/CD, réseau AWS, supervision) → **MA
  compétence à forger** : je l'écris, Claude relit et explique, jamais à ma place.
- **Applicatif pur** (logique Flask, frontend, fonctionnalités du site) →
  **Claude peut l'écrire**, je le relis pour le COMPRENDRE et le DÉBUGGER (pas
  pour savoir l'écrire de tête). Je ne cherche pas à devenir dev Flask.
- **Applicatif lié à l'infra / qui l'éclaire** (worker, health check, client
  S3 par variables d'env, endpoint `/metrics`) → **je l'écris** : c'est de
  l'infra déguisée, le pont app↔infra, cœur du métier DevOps.
- Test permanent, sur TOUT code (le mien ou celui de Claude) : « est-ce que je
  peux l'expliquer moi-même ? » Sinon je ne le garde pas.

---

## ✅ Prérequis Amazon — DÉJÀ EN PLACE
- Membre Amazon Associates + accès PA-API fonctionnel, utilisé au quotidien.
- Règles : mentions d'affiliation obligatoires, réhébergement des images
  encadré, `rel="noopener noreferrer sponsored"` sur tous les liens.
- ⚠️ Rate limits de la PA-API → prévoir un cache (surtout Couche 4).

---

## Mapping COUCHE PRODUIT ↔ PHASE ROADMAP

| Couche produit | Phase roadmap (voir ROADMAP.md) | Qui code | État |
| --- | --- | --- | --- |
| C1 — socle cliquable | B1.5 (SnapStash v0) | applicatif (Claude) | ✅ fait |
| C2 — recherche & filtres | ajout local, possible dès maintenant | applicatif (Claude) | à faire |
| C3 — bot Telegram (worker) | Phase 5 (B5.3, workers async) | **infra-lié → moi** | plus tard |
| C4 — vérif dispo + notif | Phase 5 (jobs/async + SRE) | **infra-lié → moi** | plus tard |
| C5 — metrics | Phase 5 (B5.4) → Phase 7 (B7.4) | **infra-lié → moi** | plus tard |

> ⚠️ Ne PAS construire une couche avant que sa phase roadmap soit atteinte.
> Les couches 3-5 sont des workers/jobs/observabilité = de l'infra → je les
> écris moi-même, une fois les compétences apprises (Phase 5+).

---

## 🟢 C1 — Socle cliquable — ✅ FAIT (= B1.5)
Grille (image + titre + lien), clic → Amazon, table `items` avec champ
`category` prévu dès le départ. Ajout manuel. Applicatif.

## 🟢 C2 — Recherche & filtres — (local, dès maintenant possible)
Barre de recherche + boutons de catégorie (plats, une par article) + bouton
« Tous », filtres combinables. Applicatif → Claude peut coder, je relis.

## 🟡 C3 — Bot Telegram — (Phase 5, workers) — **je code (infra-lié)**
Service séparé qui écoute Telegram → PA-API Amazon → image + titre + catégorie
→ base. Mon premier worker asynchrone = compétence infra.

## 🟡 C4 — Vérif disponibilité + notifications — (Phase 5) — **je code**
Job planifié qui vérifie via la PA-API (rate limits → cache). Indisponible →
notification + marquage. Job planifié + alertes = SRE.

## 🔴 C5 — Metrics — (Phase 5 → 7) — **je code**
Clics par article/catégorie, recherches. Dashboard. Préfigure CloudWatch (B5.4)
puis Prometheus/Grafana (B7.4). Observabilité = infra.

---

## 🚀 Déploiement & hébergement
- Objectif assumé : **pratiquer AWS** (le plus employable).
- Site en **PROD CONTINU sur EC2 (Phase 3)**, PAS sur EKS. EKS = apprentissage
  en sessions ponctuelles détruites après (Phase 7), jamais 24/7 pour un site léger.
- **Trois environnements distincts** : (1) **NUC** = home lab K8s local (k3s), gratuit
  et allumé 24/7, pour apprendre K8s (Phase 2.5) ; (2) **EC2** = prod continu du site ;
  (3) **EKS** = apprentissage K8s cloud, ponctuel (Phase 7). Le NUC ne remplace pas
  le prod AWS, il le prépare gratuitement.
- Skill à pratiquer = **déployer des MàJ sur du live sans coupure** (rolling
  update, health checks, rollback, CI/CD), pas migrer entre clouds. Chaque
  couche produit = une mise à jour déployée sur le live.
- Discipline anti-facture SACRÉE (cf. ROADMAP.md) : alertes de facturation
  AVANT tout, ressources détruites après chaque session.

---

## Règles
- Une couche complète et déployée avant la suivante.
- Prévoir les champs de base tôt (ex. `category`) sans construire la
  fonctionnalité avant sa couche.
- **Ne PAS coder les couches produit tant que leur phase roadmap n'est pas
  atteinte.** Actuellement dans le cours Kubernetes — priorité à la formation.
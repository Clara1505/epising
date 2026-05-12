# epising

> Application iOS native de signature de présence — EPITA Master 1 iOS (SwiftUI)

---

## Sommaire

- [Présentation](#présentation)
- [Fonctionnalités](#fonctionnalités)
  - [Authentification](#authentification)
  - [Parcours Étudiant](#parcours-étudiant)
  - [Parcours Enseignant](#parcours-enseignant)
- [Stack technique](#stack-technique)
- [Architecture](#architecture)
- [Installation et configuration](#installation-et-configuration)
- [Données de test](#données-de-test)
- [Sécurité](#sécurité)
- [Limitations connues](#limitations-connues)

---

## Présentation

**epising** est une application iOS native développée dans le cadre du cours de développement iOS (SwiftUI) — Master 1 EPITA. Elle remplace les solutions web d'émargement existantes (type Edusign) par une solution exploitant les APIs natives d'iOS.

### Problèmes résolus

| Limitation web | Solution epising |
|---|---|
| QR code partageable à distance | Scan NFC lié à l'appareil (device binding) |
| Oubli de la signature après-midi | Notification de fenêtre ouverte |
| Aucune valeur ajoutée native | PencilKit, CoreNFC, Realtime |

---

## Fonctionnalités

### Authentification

- Login **email + mot de passe** via Supabase Auth
- **Routing automatique** selon le rôle : les étudiants voient le parcours étudiant, les enseignants voient le parcours enseignant
- **Persistance de session** : l'utilisateur reste connecté entre les lancements de l'app
- Bouton de déconnexion accessible depuis l'emploi du temps

---

### Parcours Étudiant

#### Emploi du temps

- Vue **hebdomadaire** des séances (aujourd'hui + 7 jours à venir)
- Séances du jour en section **"Aujourd'hui"**, futures en section **"À venir"** avec date affichée
- **Indicateur de statut coloré** sur chaque séance du jour :
  - 🟢 Vert + badge **"Présent"** → étudiant déjà émargé
  - 🟠 Orange + badge **"Fenêtre ouverte"** → émargement possible maintenant
  - 🔵 Bleu + créneau → séance du jour, fenêtre fermée
- **Bouton "Émarger maintenant"** visible uniquement quand la fenêtre est ouverte et l'étudiant pas encore émargé
- **Pull-to-refresh** pour rafraîchir l'emploi du temps

#### Émargement (flux complet)

1. **Scan NFC** — l'étudiant approche son iPhone du tag NFC physique collé dans la salle
   - Le tag contient l'identifiant de la salle (ex: `EPITA-KB106`)
   - L'app appelle la Edge Function `validate-nfc` qui vérifie :
     - La fenêtre d'émargement est ouverte
     - L'étudiant est inscrit au cours
     - Le device binding (anti-fraude)
   - **Mode DEBUG** (simulateur) : bouton orange "Simuler NFC" pour tester sans tag physique

2. **Signature PencilKit** — l'étudiant signe manuscritement
   - Support **Apple Pencil** (pression + inclinaison) ET doigt
   - **Seuil de validation** : 200px de tracé minimum
   - **Barre de progression** en temps réel (bleue → verte quand valide)
   - Bouton **"Effacer"** pour recommencer
   - Bouton **"Confirmer"** activé uniquement quand le tracé est suffisant
   - La signature est validée **localement** — elle n'est pas stockée en base

3. **Confirmation** — écran de succès avec récapitulatif de la séance

#### Historique des présences

- Liste chronologique de toutes les présences passées
- **Statistiques en haut** : taux de présence global (%), nombre de présences, nombre d'absences
- **Barre de progression** colorée (verte ≥ 80%, orange < 80%)
- **Code couleur** par statut sur chaque ligne :
  - 🟢 Présent
  - 🟠 En retard / Parti tôt
  - 🔴 Absent
- **Pull-to-refresh**

---

### Parcours Enseignant

#### Mes cours

- Vue **hebdomadaire** des séances de l'enseignant connecté (aujourd'hui + 7 jours)
- **Indicateur de statut** sur les séances du jour :
  - 🟠 Orange **"Fenêtre ouverte"** → émargement NFC actif pour les étudiants
  - 🔵 Bleu + créneau → fenêtre fermée
- **Nombre d'élèves inscrits** affiché sur chaque carte
- **Bouton "Ouvrir l'émargement"** — active la fenêtre NFC pour 60 minutes
- **Bouton "Faire l'appel"** — ouvre la vue d'appel en temps réel
- Séances à venir avec **date affichée**
- Bouton d'alerte **"Je serai absent / en retard"**
- Pull-to-refresh

#### Appel en temps réel

- **Compteurs en haut** : Présents / Absents / Partis tôt / En attente
- **Liste complète des inscrits** avec avatar initiales coloré selon statut
- **Heure d'arrivée** affichée pour les présents (horodatage du scan NFC)
- **Heure de départ** affichée pour les partis tôt
- Actions manuelles par étudiant :
  - ✅ **"Marquer présent"** → sur les absents et en attente
  - ⏰ **"Parti tôt"** → sur les présents (enregistre l'heure de départ)
  - ❌ **"Marquer absent"** → sur les présents et partis tôt
- Modification instantanée sans rechargement

#### Historique

- **Taux de présence global** de l'enseignant (toutes séances confondues) avec barre de progression animée
- **Liste de toutes les séances passées** + séance du jour, triées par date décroissante
- Chaque ligne affiche : cours, date, créneau, taux%, ratio présents/inscrits
- **Indicateur coloré** (vert ≥ 80%, orange < 80%)
- **Clic sur une séance** → vue détaillée

#### Détail d'une séance (historique)

- **Statistiques** : Présents / Partis tôt / Absents / En attente
- **Liste triée par catégorie** :
  - Section Présents avec heure d'arrivée
  - Section Partis tôt avec heure d'arrivée et heure de départ
  - Section Absents
  - Section En attente
- **Bouton "Marquer absent"** sur présents, partis tôt et en attente
- **Realtime** : la vue se met à jour automatiquement dès qu'un étudiant émerge (Supabase Realtime)
- Pull-to-refresh

---

## Stack technique

| Composant | Technologie |
|---|---|
| Application iOS | SwiftUI (iOS 17+) |
| Persistance locale | SwiftData |
| Signature manuscrite | PencilKit |
| Lecture NFC | CoreNFC |
| Backend | Supabase (PostgreSQL + Auth + Realtime) |
| API custom | Supabase Edge Functions (Deno/TypeScript) |
| Realtime | Supabase Realtime (WebSocket) |
| Authentification | Supabase Auth — email + password |

---

## Architecture

### Structure du projet Xcode

```
epising/
├── App/
│   ├── episingApp.swift          — Point d'entrée, injection AuthViewModel
│   └── RootView.swift            — Routing login / student / teacher
├── Core/
│   ├── Network/
│   │   ├── SupabaseClient.swift  — Client Supabase partagé
│   │   └── APIError.swift        — Enum erreurs réseau
│   ├── Models/
│   │   ├── Profile.swift         — Profil utilisateur + enum UserRole
│   │   ├── Course.swift          — Cours avec nfc_tag_id
│   │   ├── CourseSession.swift   — Séance avec fenêtre d'émargement
│   │   ├── Attendance.swift      — Présence avec statut
│   │   └── Enrollment.swift      — Inscription étudiant ↔ cours
│   └── Auth/
│       ├── AuthViewModel.swift   — Login, session, profil
│       └── KeychainHelper.swift  — Stockage device_id (anti-fraude)
├── Features/
│   ├── Auth/
│   │   └── LoginView.swift
│   ├── Student/
│   │   ├── StudentTabView.swift
│   │   ├── Schedule/             — Emploi du temps
│   │   ├── Attendance/           — Historique présences
│   │   ├── NFC/                  — Scan NFC + Edge Function
│   │   └── Signature/            — PencilKit + validation 200px
│   └── Teacher/
│       ├── TeacherTabView.swift
│       ├── Courses/              — Liste cours + ouvrir fenêtre
│       ├── RollCall/             — Appel temps réel
│       └── History/              — Historique + détail séance
└── Shared/
    └── Components/               — StatPill, StatCard, SectionHeader...
```

### Pattern MVVM

```
View  ──observe──▶  ViewModel (@Observable)  ──appelle──▶  Supabase SDK
  ▲                      │
  └──────────────────────┘ (mise à jour @MainActor)
```

### Schéma de base de données

```
auth.users (Supabase)
    ↓ trigger auto
profiles          id | email | full_name | role | device_id
    ↓
courses           id | title | teacher_id | room | nfc_tag_id
    ↓
sessions          id | course_id | session_date | slot | start_time | sign_open_at | sign_close_at
    ↓
enrollments       course_id ↔ student_id
attendances       session_id | student_id | status | marked_by | signed_at | left_at
nfc_scan_log      session_id | student_id | device_id | success | fail_reason
```

### Flux d'émargement NFC

```
Tag NFC (salle)  →  CoreNFC lit "EPITA-KB106"
                 →  POST /functions/v1/validate-nfc
                         { nfc_tag_id, device_id }
                 →  Edge Function vérifie :
                         fenêtre ouverte ?
                         étudiant inscrit ?
                         device binding ?
                 →  INSERT/UPDATE attendances
                 →  Retour { success, course_title, signed_at }
                 →  PencilKit signature (locale, non stockée)
                 →  Écran confirmation ✅
```

---

## Installation et configuration

### Prérequis

- macOS 14+ (Sonoma ou Sequoia)
- Xcode 16+
- Homebrew (`brew.sh`)
- Supabase CLI (`brew install supabase/tap/supabase`)

### 1. Cloner le projet

```bash
git clone <URL_DU_REPO> epising
cd epising
```

### 2. Installer le package Supabase Swift

Dans Xcode : **File → Add Package Dependencies**
```
https://github.com/supabase/supabase-swift
```
→ Sélectionner **Supabase** → Add to Target : **epising**

### 3. Configurer les clés Supabase

Dans `Core/Network/SupabaseClient.swift`, renseigner :
```swift
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://<ref>.supabase.co")!,
    supabaseKey: "<anon-key>"
)
```
Les clés sont disponibles dans **Supabase Dashboard → Settings → API Keys**.

> ⚠️ Ne jamais committer la `service_role` key dans le code Swift.

### 4. Configurer la base de données

Dans le **SQL Editor** de Supabase, exécuter dans l'ordre :
1. `supabase/migrations/001_schema.sql`
2. `supabase/migrations/002_rls.sql`

### 5. Déployer la Edge Function

```bash
supabase login
supabase link --project-ref <project-ref>
supabase functions deploy validate-nfc
```

### 6. Activer le Realtime

Dans le **SQL Editor** :
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.attendances;
```

### 7. Ajouter la Capability NFC

Dans Xcode : target **epising** → **Signing & Capabilities** → **+ Capability** → **Near Field Communication Tag Reading**

Dans `Info.plist` :
```
NFCReaderUsageDescription → "Utilisé pour émarger à votre cours"
```

---

## Données de test

### Réinitialiser la base

```bash
# 1. Nettoyer (SQL Editor)
#    → cleanup.sql

# 2. Créer les users (terminal)
bash create_users.sh   # nécessite SERVICE_ROLE_KEY dans le script

# 3. Insérer les données (SQL Editor)
#    → fresh_seed.sql
```

### Comptes de test

Mot de passe universel : **`Epising2026!`**

| Email | Rôle | Cours |
|---|---|---|
| `m.durand@epita.fr` | Enseignant | Programmation iOS |
| `mme.chen@epita.fr` | Enseignant | JavaScript, DevOPS, Algorithmique |
| `m.martin@epita.fr` | Enseignant | Probabilités, Indexations |
| `alice.rousseau@epita.fr` | Étudiant | Tous les cours |
| `bob.dupont@epita.fr` | Étudiant | Tous les cours |
| `clara.bernard@epita.fr` | Étudiant | Tous les cours |
| `david.leroy@epita.fr` | Étudiant | Tous les cours |
| `emma.petit@epita.fr` | Étudiant | Tous les cours |

### Tags NFC de test

| Tag | Salle | Cours |
|---|---|---|
| `EPITA-KB106` | KB106 | Programmation iOS |
| `EPITA-KB002` | KB002 | JavaScript - Node.js |
| `EPITA-PAR1-DV` | Paritalie App1 | DevOPS |
| `EPITA-KB102` | KB102 | Algorithmique avancée |
| `EPITA-KB404` | KB404 | Probabilités |
| `EPITA-KB202` | KB202 | Indexations |

### Ouvrir une fenêtre d'émargement manuellement

```sql
SELECT public.open_sign_window(
  (SELECT id FROM public.sessions WHERE session_date = current_date LIMIT 1),
  60  -- durée en minutes
);
```

---

## Sécurité

### Couches anti-fraude

| Mécanisme | Description |
|---|---|
| **Fenêtre temporelle** | L'émargement n'est accepté que pendant la plage définie par l'enseignant |
| **Device binding** | Un étudiant ne peut émarger que depuis l'iPhone enregistré au premier login |
| **NFC physique** | Nécessite la présence physique en salle (pas de partage de code à distance) |
| **Journal NFC** | Chaque scan (succès et échec) est enregistré dans `nfc_scan_log` avec timestamp et device_id |
| **RLS Supabase** | Les étudiants ne voient que leurs propres données, les enseignants que leurs cours |
| **JWT Auth** | Toutes les requêtes sont authentifiées par token JWT signé |

---

## Limitations connues

| Limitation | Raison | Solution envisagée |
|---|---|---|
| NFC non fonctionnel sur simulateur | CoreNFC ne supporte pas le simulateur iOS | Compte Apple Developer (99$/an) requis pour device réel |
| NFC non fonctionnel en développement | Nécessite un provisioning profile avec entitlement NFC | Compte Apple Developer payant |
| RLS désactivée sur `sessions` et `courses` | Conflit entre les subqueries RLS | Revoir le schéma de sécurité en production |
| Pas de notifications push | Non implémenté dans cette version | APNs + compte Apple Developer |
| Signature non stockée | Choix de conception (validation locale uniquement) | Optionnel : upload S3/Storage Supabase |

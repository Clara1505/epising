# epising

> Application iOS native de signature de présence (SwiftUI)

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

1. **Scan NFC** — l'étudiant approche son iPhone de la carte d'école de l'enseignant
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
- **Bouton "Ouvrir l'émargement"** — l'enseignant scanne sa propre carte NFC pour activer la fenêtre pendant 60 minutes
- **Bouton "Faire l'appel"** — ouvre la vue d'appel en temps réel
- Séances à venir avec **date affichée**
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

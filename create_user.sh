#!/bin/bash
# ============================================================
# create_users.sh — Crée les 8 users via l'API Admin Supabase
# Usage : bash create_users.sh
# Prérequis : curl installé (présent par défaut sur macOS)
# ============================================================

PROJECT_URL="https://pzvrvfdwygvpelfvceyv.supabase.co"
SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB6dnJ2ZmR3eWd2cGVsZnZjZXl2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NzAzMDQ2NSwiZXhwIjoyMDkyNjA2NDY1fQ.xQEZWNZ5tMV2_SqxGerUptLeerHq4wrNX6ca6r7zU4s"
PASSWORD="Epising2026!"

# Couleurs terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

create_user() {
  local EMAIL="$1"
  local FULL_NAME="$2"
  local ROLE="$3"

  RESPONSE=$(curl -s -X POST \
    "$PROJECT_URL/auth/v1/admin/users" \
    -H "apikey: $SERVICE_KEY" \
    -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"email\": \"$EMAIL\",
      \"password\": \"$PASSWORD\",
      \"email_confirm\": true,
      \"user_metadata\": {
        \"full_name\": \"$FULL_NAME\",
        \"role\": \"$ROLE\"
      }
    }")

  if echo "$RESPONSE" | grep -q '"id"'; then
    echo -e "  ${GREEN}✅ $EMAIL${NC}"
  elif echo "$RESPONSE" | grep -q '"User already registered"'; then
    echo -e "  ${BLUE}⚠️  $EMAIL déjà existant — ignoré${NC}"
  else
    echo -e "  ${RED}❌ $EMAIL → $(echo $RESPONSE | grep -o '"message":"[^"]*"')${NC}"
  fi
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  epising — Création des users de test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo -e "${BLUE}👨‍🏫 Enseignants${NC}"
create_user "m.durand@epita.fr"    "M. Durand"    "teacher"
create_user "mme.chen@epita.fr"    "Mme. Chen"    "teacher"
create_user "m.martin@epita.fr"    "M. Martin"    "teacher"

echo ""
echo -e "${BLUE}👩‍🎓 Étudiants${NC}"
create_user "alice.rousseau@epita.fr"  "Alice Rousseau"  "student"
create_user "bob.dupont@epita.fr"      "Bob Dupont"      "student"
create_user "clara.bernard@epita.fr"   "Clara Bernard"   "student"
create_user "david.leroy@epita.fr"     "David Leroy"     "student"
create_user "emma.petit@epita.fr"      "Emma Petit"      "student"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Mot de passe universel : ${GREEN}Epising2026!${NC}"
echo "  Lance maintenant fresh_seed.sql"
echo "  dans le SQL Editor Supabase"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

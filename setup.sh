#!/usr/bin/env bash
# Cartellino — setup completo da terminale (Mac)
# Uso:  ./setup.sh [nome-repo]      (default: cartellino)
set -euo pipefail
cd "$(dirname "$0")"

REF="znkchlvusjaogrvlbutl"
SB_URL="https://$REF.supabase.co"
REPO="${1:-cartellino}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo "✗ Manca '$1'. Installa con: $2"; exit 1; }; }
need git     "xcode-select --install"
need python3 "xcode-select --install"
need curl    "(già presente su macOS)"
need gh      "brew install gh"
need supabase "brew install supabase/tap/supabase"

step(){ printf '\n\033[1;36m▸ %s\033[0m\n' "$1"; }

step "Login GitHub e Supabase"
gh auth status >/dev/null 2>&1 || gh auth login
supabase projects list >/dev/null 2>&1 || supabase login

step "Collego il progetto Supabase ($REF)"
[ -f supabase/config.toml ] || supabase init
echo "Ti chiederà la password del database (quella scelta quando hai creato il progetto)."
supabase link --project-ref "$REF"

step "Creo tabella, foto e permessi"
supabase db push

step "Leggo la chiave di servizio (solo in memoria)"
KEYS_JSON="$(supabase projects api-keys --project-ref "$REF" -o json --reveal 2>/dev/null || supabase projects api-keys --project-ref "$REF" -o json)"
key(){ python3 -c '
import json,sys
ks=json.loads(sys.argv[1]); want=sys.argv[2]
for k in ks:
    if k.get("name")==want and k.get("api_key"): print(k["api_key"]); break
else:
    t={"service_role":"secret"}.get(want)
    for k in ks:
        if t and k.get("type")==t and k.get("api_key") and "·" not in k["api_key"]: print(k["api_key"]); break
' "$KEYS_JSON" "$1"; }
SERVICE="$(key service_role)"
[ -n "$SERVICE" ] || { echo "✗ Chiave segreta non trovata. Output:"; echo "$KEYS_JSON"; exit 1; }
# chiave legacy (JWT) va anche in Authorization; la nuova sb_secret_ solo in apikey
AUTH=(-H "apikey: $SERVICE"); [[ "$SERVICE" == eyJ* ]] && AUTH+=(-H "Authorization: Bearer $SERVICE")

step "Creo l'accesso del negozio"
read -rp "Email per il login: " EMAIL
read -rsp "Password (min 6 caratteri): " PASS; echo
BODY="$(python3 -c 'import json,sys; print(json.dumps({"email":sys.argv[1],"password":sys.argv[2],"email_confirm":True}))' "$EMAIL" "$PASS")"
RES="$(curl -sS -X POST "$SB_URL/auth/v1/admin/users" \
  "${AUTH[@]}" -H "Content-Type: application/json" -d "$BODY")"
if echo "$RES" | grep -q '"id"'; then echo "✓ Utente creato"
elif echo "$RES" | grep -qi 'already'; then echo "• Utente già esistente, continuo"
else echo "✗ Errore creazione utente: $RES"; exit 1; fi

curl -sS -o /dev/null -w '' -X POST "$SB_URL/rest/v1/staff" \
  "${AUTH[@]}" -H "Content-Type: application/json" \
  -H "Prefer: resolution=ignore-duplicates" -d "{\"email\":\"$(echo "$EMAIL" | tr 'A-Z' 'a-z')\"}"
echo "✓ $EMAIL può aggiungere ed eliminare vestiti"
unset SERVICE PASS BODY AUTH

step "Pubblico su GitHub Pages"
OWNER="$(gh api user -q .login)"
[ -d .git ] || git init -q -b main
git add -A
git commit -qm "Cartellino" || true
if git remote get-url origin >/dev/null 2>&1; then git push -q -u origin main
else gh repo create "$REPO" --public --source=. --push; fi
gh api -X POST "repos/$OWNER/$REPO/pages" -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1 \
  || echo "• GitHub Pages già attivo"

printf '\n\033[1;32m✓ Fatto.\033[0m Tra 1-2 minuti la pagina è online su:\n  https://%s.github.io/%s/\n\n' "$OWNER" "$REPO"

#!/usr/bin/env bash
# Aggiunge un altro login del negozio (es. un commesso)
# Uso: ./staff.sh
set -euo pipefail
REF="znkchlvusjaogrvlbutl"
SB_URL="https://$REF.supabase.co"

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

read -rp "Email: " EMAIL
read -rsp "Password (min 6 caratteri): " PASS; echo
BODY="$(python3 -c 'import json,sys; print(json.dumps({"email":sys.argv[1],"password":sys.argv[2],"email_confirm":True}))' "$EMAIL" "$PASS")"
RES="$(curl -sS -X POST "$SB_URL/auth/v1/admin/users" \
  "${AUTH[@]}" -H "Content-Type: application/json" -d "$BODY")"
echo "$RES" | grep -q '"id"' || echo "$RES" | grep -qi 'already' || { echo "✗ $RES"; exit 1; }

curl -sS -o /dev/null -X POST "$SB_URL/rest/v1/staff" \
  "${AUTH[@]}" -H "Content-Type: application/json" \
  -H "Prefer: resolution=ignore-duplicates" -d "{\"email\":\"$(echo "$EMAIL" | tr 'A-Z' 'a-z')\"}"
echo "✓ $EMAIL può entrare e aggiungere vestiti"

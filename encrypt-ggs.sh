#!/usr/bin/env bash
# Password-protect rendered GETGAIN (ggs/) HTML with StatiCrypt, in place.
#
# Usage (from the repo root, in Git Bash):
#   STATICRYPT_PASSWORD='...' ./encrypt-ggs.sh                 # every ggs/**/*.html
#   STATICRYPT_PASSWORD='...' ./encrypt-ggs.sh ggs/x/deck.html # specific files
#
# Run it after every `quarto render` of a ggs/ document; rendering overwrites the
# encrypted file with plain HTML again. Files that are already encrypted are skipped.
# .staticrypt.json (the salt, not a secret) must stay committed so "Remember me"
# and share links keep working across re-encryptions.
set -euo pipefail
cd "$(dirname "$0")"

if [[ -z "${STATICRYPT_PASSWORD:-}" ]]; then
  echo "Set STATICRYPT_PASSWORD first." >&2
  exit 1
fi

if [[ $# -gt 0 ]]; then
  files=("$@")
else
  mapfile -t files < <(find ggs -name '*.html' -not -path '*_files/*')
fi

for f in "${files[@]}"; do
  if grep -q 'staticrypt' "$f"; then
    echo "skip (already encrypted): $f"
    continue
  fi
  # --short: skip the interactive "short password" prompt, which can't be answered here
  # and silently aborts. Prefer a password of 14+ characters anyway.
  npx --no-install staticrypt "$f" \
    -d "$(dirname "$f")" \
    --short \
    --remember 30 \
    --template-title "Documento protegido · GETGAIN" \
    --template-instructions "Este documento é confidencial. Introduza a palavra-passe fornecida." \
    --template-button "ENTRAR" \
    --template-placeholder "Palavra-passe" \
    --template-error "Palavra-passe incorreta" \
    --template-remember "Lembrar-me" \
    --template-color-primary "#1f3864" \
    --template-color-secondary "#eef1f5" < /dev/null
  if ! grep -q 'staticrypt' "$f"; then
    echo "FAILED (file is still plain HTML): $f" >&2
    exit 1
  fi
  echo "encrypted: $f"
done

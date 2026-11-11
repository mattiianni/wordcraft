#!/usr/bin/env bash
set -e

# Sync Upstream with Custom Preserved Modifications
# WordCraft

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

echo "=== [WordCraft] Verifica aggiornamenti upstream da origin/main ==="

# Assicuriamoci che i remoti siano configurati
git fetch origin main

NEW_COMMITS=$(git rev-list --count HEAD..origin/main)

if [ "$NEW_COMMITS" -eq 0 ]; then
    echo "Nessun nuovo aggiornamento dalla community. WordCraft è già allineato all'ultima versione di upstream!"
    exit 0
fi

echo "Trovati $NEW_COMMITS nuovi commit upstream."
echo "Avvio rebase per incorporare le migliorie della community preservando le personalizzazioni..."

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Tentativo di rebase
if git rebase origin/main; then
    echo "Rebase completato con successo senza conflitti!"
else
    echo "Attenzione: si sono verificati conflitti durante il rebase."
    echo "Risolvi i conflitti assicurandoti di mantenere le modifiche in CHANGELOG_CUSTOM.md, poi prosegui con 'git rebase --continue'."
    exit 1
fi

echo "Verifica dei test di digitazione e preferenze personalizzate..."
cargo test -p wordcraft-engine tests::typing::default_preferences_lowercase_start_and_standard_hyphen

if [ -z "${CRAFT_I18N_DIR:-}" ] && [ -f "$REPO_DIR/craft-i18n.rev" ]; then
    I18N_REV="$(tr -d '[:space:]' < "$REPO_DIR/craft-i18n.rev")"
    I18N_DIR="/tmp/craft-i18n"
    if [ ! -d "$I18N_DIR/.git" ]; then
        git clone --filter=blob:none https://github.com/storytold/craft-i18n.git "$I18N_DIR"
    fi
    git -C "$I18N_DIR" fetch origin "$I18N_REV" 2>/dev/null || git -C "$I18N_DIR" fetch origin
    git -C "$I18N_DIR" checkout -f "$I18N_REV"
    export CRAFT_I18N_DIR="$I18N_DIR"
fi

echo "Compilazione dell'applicazione aggiornata..."
cargo build --release -p wordcraft

if [ -d "/Applications/WordCraft.app" ]; then
    echo "Installazione del nuovo eseguibile in /Applications/WordCraft.app..."
    /bin/cp -f target/release/wordcraft /Applications/WordCraft.app/Contents/MacOS/WordCraft
    xattr -cr /Applications/WordCraft.app
    codesign --force --deep --sign - /Applications/WordCraft.app 2>/dev/null || true
    echo "Applicazione aggiornata e firmata con successo in /Applications/WordCraft.app!"

    echo "Aggiornamento pacchetto WordCraft.zip sulla Scrivania..."
    (cd /Applications && rm -f /Users/mattiaianniello/Desktop/WordCraft.zip && COPYFILE_DISABLE=1 zip -r -y -q /Users/mattiaianniello/Desktop/WordCraft.zip WordCraft.app -x "*.DS_Store" -x "*__MACOSX*")
    echo "Pacchetto WordCraft.zip su Scrivania aggiornato con successo!"
fi

echo "Pulizia cartella target per risparmiare spazio su disco..."
cargo clean

echo "Aggiornamento del fork su GitHub..."
git push --force-with-lease fork "$CURRENT_BRANCH" || true
git push --force-with-lease fork "$CURRENT_BRANCH":main || true

echo "=== [WordCraft] Aggiornamento completato con successo! ==="

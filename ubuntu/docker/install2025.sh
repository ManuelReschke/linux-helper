#!/usr/bin/env bash
set -euo pipefail

#####################################
# Docker Install für Ubuntu (z. B. 25.04)
# - Unterstützt alte Releases via Fallback auf noble (24.04 LTS)
# - Keine apt-key Nutzung, stattdessen Keyring + signed-by
# - Installiert docker-ce + docker-compose-plugin (+ optional Legacy-Binary)
# Optionen:
#   --dry-run | --check  : Nichts ändern, nur prüfen/anzeigen
#   --yes                : Bestätigungen automatisch mit "Ja"
# Umgebungsvariablen (optional):
#   DOCKER_CHANNEL       : stable | test | nightly (Default: stable)
#   DOCKER_COMPOSE_VERSION : z. B. v2.29.2 (Legacy-Binary; leer lassen, um zu überspringen)
#####################################

DOCKER_CHANNEL="${DOCKER_CHANNEL:-stable}"
DOCKER_COMPOSE_VERSION="${DOCKER_COMPOSE_VERSION:-v2.29.2}"
DEBIAN_FRONTEND=noninteractive

DRY_RUN=0
ASSUME_YES=0

for arg in "${@:-}"; do
  case "${arg}" in
    --dry-run|--check) DRY_RUN=1 ;;
    --yes|-y)          ASSUME_YES=1 ;;
    *) echo "Unbekannte Option: ${arg}" >&2; exit 2 ;;
  esac
done

# ---------- Hilfsfunktionen ----------
log()   { printf "%s\n" "[$(date +'%H:%M:%S')] $*"; }
warn()  { printf "%s\n" "[$(date +'%H:%M:%S')] WARN: $*" >&2; }
err()   { printf "%s\n" "[$(date +'%H:%M:%S')] ERROR: $*" >&2; }
ask()   {
  local prompt="${1:-Fortfahren?} [y/N] "
  if (( ASSUME_YES )); then
    log "Auto-Bestätigung (--yes) aktiv."
    return 0
  fi
  read -r -p "$prompt" reply || true
  [[ "${reply,,}" =~ ^(y|yes|j|ja)$ ]]
}

# Sudo/Root-Handling
NEED_SUDO=1
if [[ "${EUID}" -eq 0 ]]; then
  NEED_SUDO=0
fi

if (( NEED_SUDO )); then
  if ! command -v sudo >/dev/null 2>&1; then
    err "Dieses Skript benötigt sudo oder Root. Bitte sudo installieren oder als Root ausführen."
    exit 1
  fi
  if ! sudo -n true 2>/dev/null; then
    warn "sudo erfordert ggf. dein Passwort."
    if ! ask "Mit sudo fortfahren?"; then
      err "Abgebrochen."
      exit 1
    fi
  fi
fi

SUDO() {
  if (( DRY_RUN )); then
    echo "DRY-RUN: sudo $*"
  else
    if (( NEED_SUDO )); then sudo "$@"; else "$@"; fi
  fi
}

DO() {
  if (( DRY_RUN )); then
    echo "DRY-RUN: $*"
  else
    eval "$@"
  fi
}

# Architektur-Mapping für Compose-Binary
ARCH="$(uname -m)"
OS="$(uname -s)"
case "${ARCH}" in
  x86_64|amd64) COMPOSE_ARCH="x86_64" ;;
  aarch64|arm64) COMPOSE_ARCH="aarch64" ;;
  armv7l) COMPOSE_ARCH="armv7" ;;
  *) COMPOSE_ARCH="${ARCH}" ;;
esac

# Ubuntu Codename
UBUNTU_CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
DIST_ARCH="$(dpkg --print-architecture)"
KEYRING="/etc/apt/keyrings/docker.asc"
REPO_FILE="/etc/apt/sources.list.d/docker.list"

log "Erkannt: Ubuntu Codename='${UBUNTU_CODENAME}', Arch='${DIST_ARCH}', Kernel='$(uname -r)'."
log "Docker Channel: ${DOCKER_CHANNEL}"
if [[ -n "${DOCKER_COMPOSE_VERSION}" ]]; then
  log "Legacy docker-compose Binary wird installiert: ${DOCKER_COMPOSE_VERSION}"
else
  log "Legacy docker-compose Binary wird übersprungen (Plugin reicht)."
fi

# ---------- Checks (auch im Dry-Run sinnvoll) ----------
check_network() {
  if ! curl -fsSL -m 5 https://download.docker.com/ >/dev/null 2>&1; then
    warn "Kein Zugriff auf https://download.docker.com (Netz/Firewall?)."
    return 1
  fi
  return 0
}

check_repo_suite() {
  local suite="${1}"
  local url="https://download.docker.com/linux/ubuntu/dists/${suite}/Release"
  if curl -fsI -m 5 "$url" >/dev/null 2>&1; then
    log "Docker-Repo Suite verfügbar: ${suite}"
    return 0
  else
    warn "Docker-Repo Suite nicht gefunden: ${suite}"
    return 1
  fi
}

log "Prüfe Netzwerk-Konnektivität..."
check_network || warn "Du kannst fortfahren, aber das apt update wird scheitern."

log "Prüfe Docker-Repo für '${UBUNTU_CODENAME}'..."
SUITE="${UBUNTU_CODENAME}"
if ! check_repo_suite "${UBUNTU_CODENAME}"; then
  warn "Fallback auf 'noble' (24.04 LTS) wird vorbereitet."
  SUITE="noble"
fi

log "APT-Repo-Zeile: deb [arch=${DIST_ARCH} signed-by=${KEYRING}] https://download.docker.com/linux/ubuntu ${SUITE} ${DOCKER_CHANNEL}"

if (( DRY_RUN )); then
  log "Dry-Run abgeschlossen. Verwende ohne --dry-run für Installation."
  exit 0
fi

# ---------- Installation beginnt ----------
if ! ask "Docker Engine jetzt installieren/aktualisieren?"; then
  err "Abgebrochen."
  exit 1
fi

log "Pakete aktualisieren und Basis-Tools installieren..."
SUDO apt-get update -y
SUDO apt-get install -y ca-certificates curl gnupg lsb-release software-properties-common apt-transport-https

log "Keyring-Verzeichnis anlegen und GPG-Key beziehen..."
SUDO install -m 0755 -d /etc/apt/keyrings
SUDO curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "${KEYRING}"
SUDO chmod a+r "${KEYRING}"

log "Docker APT-Quelle setzen (${SUITE}/${DOCKER_CHANNEL})..."
echo "deb [arch=${DIST_ARCH} signed-by=${KEYRING}] https://download.docker.com/linux/ubuntu ${SUITE} ${DOCKER_CHANNEL}" | SUDO tee "${REPO_FILE}" >/dev/null

log "apt-get update ausführen..."
if ! SUDO apt-get update -y; then
  if [[ "${SUITE}" != "noble" ]]; then
    warn "Update fehlgeschlagen. Fallback auf 'noble' (24.04 LTS)."
    echo "deb [arch=${DIST_ARCH} signed-by=${KEYRING}] https://download.docker.com/linux/ubuntu noble ${DOCKER_CHANNEL}" | SUDO tee "${REPO_FILE}" >/dev/null
    SUDO apt-get update -y
  else
    err "apt-get update fehlgeschlagen. Bitte Netzwerk/Repo prüfen."
    exit 1
  fi
fi

log "Alte Docker-Pakete bereinigen (falls vorhanden)..."
SUDO apt-get purge -y docker-ce docker-ce-cli docker-ce-rootless-extras docker-compose-plugin || true
# Daten bewusst nicht löschen (Images/Container behalten):
# SUDO rm -rf /var/lib/docker /var/lib/containerd || true

log "Docker Engine + CLI + Containerd + Buildx + Compose-Plugin installieren..."
SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Optional: Legacy docker-compose Binary
if [[ -n "${DOCKER_COMPOSE_VERSION}" ]]; then
  log "Legacy docker-compose Binary installieren (${DOCKER_COMPOSE_VERSION})..."
  SUDO curl -fsSL \
    "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-${OS}-${COMPOSE_ARCH}" \
    -o /usr/local/bin/docker-compose
  SUDO chmod +x /usr/local/bin/docker-compose
fi

# Gruppe docker
log "docker-Gruppe setzen und Benutzer hinzufügen..."
SUDO groupadd -f docker
SUDO usermod -aG docker "$USER" || true

# Versionen ausgeben
log "=== Installierte Versionen ==="
( SUDO docker --version && SUDO docker compose version ) || true
if command -v /usr/local/bin/docker-compose >/dev/null 2>&1; then
  SUDO /usr/local/bin/docker-compose --version || true
fi

log "Fertig. Melde dich neu an oder führe 'newgrp docker' aus, damit die Gruppenänderung wirkt."

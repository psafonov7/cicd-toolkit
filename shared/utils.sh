log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2
}

error() {
    log "ERROR: $*"
    exit 1
}

check_os_support() {
    if [[ -f /etc/os-release ]]; then
      source /etc/os-release
      if ! [[ "$ID" == "debian" || "$ID_LIKE" == *"debian"* ]]; then
        error "This system is not Debian or Debian-based."
      fi
    else
      error "Cannot determine OS type (missing /etc/os-release)."
    fi
}

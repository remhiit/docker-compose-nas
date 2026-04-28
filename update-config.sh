#!/bin/bash

# See https://stackoverflow.com/a/44864004 for the sed GNU/BSD compatible hack

set -euo pipefail

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

CONFIG_ROOT="${CONFIG_ROOT:-.}"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-120}"

function wait_for_file {
  local file_path="$1"
  local waited=0

  until [ -f "$file_path" ]; do
    sleep 1
    waited=$((waited + 1))
    if [ "$waited" -ge "$WAIT_TIMEOUT_SECONDS" ]; then
      echo "Timed out waiting for $file_path" >&2
      return 1
    fi
  done
}

if ! command -v docker >/dev/null 2>&1; then
  echo "docker command is required but was not found in PATH" >&2
  exit 1
fi

function update_arr_config {
  echo "Updating ${container} configuration..."
  wait_for_file "$CONFIG_ROOT"/"$container"/config.xml
  sed -i.bak "s/<UrlBase><\/UrlBase>/<UrlBase>\/$1<\/UrlBase>/" "$CONFIG_ROOT"/"$container"/config.xml && rm "$CONFIG_ROOT"/"$container"/config.xml.bak
  CONTAINER_NAME_UPPER=$(echo "$container" | tr '[:lower:]' '[:upper:]')
  sed -i.bak 's/^'"${CONTAINER_NAME_UPPER}"'_API_KEY=.*/'"${CONTAINER_NAME_UPPER}"'_API_KEY='"$(sed -n 's/.*<ApiKey>\(.*\)<\/ApiKey>.*/\1/p' "$CONFIG_ROOT"/"$container"/config.xml)"'/' .env && rm .env.bak
  echo "Update of ${container} configuration complete, restarting..."
  docker compose restart "$container"
}

function update_qbittorrent_config {
    echo "Updating ${container} configuration..."
    docker compose stop "$container"
    wait_for_file "$CONFIG_ROOT"/"$container"/qBittorrent/qBittorrent.conf
    sed -i.bak '/WebUI\\ServerDomains=*/a WebUI\\Password_PBKDF2="@ByteArray(ARQ77eY1NUZaQsuDHbIMCA==:0WMRkYTUWVT9wVvdDtHAjU9b3b7uB8NR1Gur2hmQCvCDpm39Q+PsJRJPaCU51dEiz+dTzh8qbPsL8WkFljQYFQ==)"' "$CONFIG_ROOT"/"$container"/qBittorrent/qBittorrent.conf && rm "$CONFIG_ROOT"/"$container"/qBittorrent/qBittorrent.conf.bak
    echo "Update of ${container} configuration complete, restarting..."
    docker compose start "$container"
}

function update_bazarr_config {
    echo "Updating ${container} configuration..."
    wait_for_file "$CONFIG_ROOT"/"$container"/config/config/config.yaml
    sed -i.bak "s/base_url: ''/base_url: '\/$container'/" "$CONFIG_ROOT"/"$container"/config/config/config.yaml && rm "$CONFIG_ROOT"/"$container"/config/config/config.yaml.bak
    sed -i.bak "s/use_radarr: false/use_radarr: true/" "$CONFIG_ROOT"/"$container"/config/config/config.yaml && rm "$CONFIG_ROOT"/"$container"/config/config/config.yaml.bak
    sed -i.bak "s/use_sonarr: false/use_sonarr: true/" "$CONFIG_ROOT"/"$container"/config/config/config.yaml && rm "$CONFIG_ROOT"/"$container"/config/config/config.yaml.bak
    wait_for_file "$CONFIG_ROOT"/sonarr/config.xml
    SONARR_API_KEY=$(sed -n 's/.*<ApiKey>\(.*\)<\/ApiKey>.*/\1/p' "$CONFIG_ROOT"/sonarr/config.xml)
    sed -i.bak "/sonarr:/,/^radarr:/ { s/apikey: .*/apikey: $SONARR_API_KEY/; s/base_url: .*/base_url: \/sonarr/; s/ip: .*/ip: sonarr/ }" "$CONFIG_ROOT"/"$container"/config/config/config.yaml && rm "$CONFIG_ROOT"/"$container"/config/config/config.yaml.bak
    wait_for_file "$CONFIG_ROOT"/radarr/config.xml
    RADARR_API_KEY=$(sed -n 's/.*<ApiKey>\(.*\)<\/ApiKey>.*/\1/p' "$CONFIG_ROOT"/radarr/config.xml)
    sed -i.bak "/radarr:/,/^sonarr:/ { s/apikey: .*/apikey: $RADARR_API_KEY/; s/base_url: .*/base_url: \/radarr/; s/ip: .*/ip: radarr/ }" "$CONFIG_ROOT"/"$container"/config/config/config.yaml && rm "$CONFIG_ROOT"/"$container"/config/config/config.yaml.bak
    sed -i.bak 's/^BAZARR_API_KEY=.*/BAZARR_API_KEY='"$(sed -n 's/.*apikey: \(.*\)*/\1/p' "$CONFIG_ROOT"/"$container"/config/config/config.yaml | head -n 1)"'/' .env && rm .env.bak
    echo "Update of ${container} configuration complete, restarting..."
    docker compose restart "$container"
}

for container in $(docker compose ps --services --status running); do
  if [[ "$container" =~ ^(radarr|sonarr|lidarr|prowlarr)$ ]]; then
    update_arr_config "$container"
  elif [[ "$container" =~ ^(bazarr)$ ]]; then
    update_bazarr_config "$container"
  elif [[ "$container" =~ ^(qbittorrent)$ ]]; then
    update_qbittorrent_config "$container"
  fi
done

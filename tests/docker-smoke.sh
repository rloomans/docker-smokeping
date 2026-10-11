#!/usr/bin/env bash
set -euo pipefail

image="${1:?Usage: docker-smoke.sh IMAGE}"
container_name="smokeping-smoke-test-${GITHUB_RUN_ID:-local}-${GITHUB_RUN_ATTEMPT:-1}-$$"

cleanup() {
  docker rm --force "$container_name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --detach \
  --name "$container_name" \
  --publish 127.0.0.1::80 \
  --env PUID=1000 \
  --env PGID=1000 \
  --env TZ=UTC \
  "$image" >/dev/null

published_port="$(docker port "$container_name" 80/tcp | sed 's/.*://')"
url="http://127.0.0.1:${published_port}/smokeping/smokeping.fcgi"

for attempt in $(seq 1 30); do
  if status="$(curl --silent --output /dev/null --write-out '%{http_code}' "$url")" \
    && [[ "$status" == "200" ]]; then
    echo "SmokePing page responded with HTTP 200."
    exit 0
  fi

  if [[ "$(docker inspect --format '{{.State.Running}}' "$container_name")" != "true" ]]; then
    echo "Container exited before the SmokePing page became available." >&2
    docker logs "$container_name" >&2
    exit 1
  fi

  sleep 2
done

echo "SmokePing page did not respond successfully at $url." >&2
docker logs "$container_name" >&2
exit 1

#!/bin/bash

# Make the smokeping user/group match PUID/PGID so that the smokeping daemon and the
# web server run as that user and own the files in /config and /data.

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

if ! [[ $PUID =~ ^[0-9]+$ && $PGID =~ ^[0-9]+$ ]]; then
  echo "ERROR: PUID and PGID must be numeric (PUID=$PUID PGID=$PGID)" >&2
  exit 1
fi

if [[ $PUID -eq 0 || $PGID -eq 0 ]]; then
  echo "ERROR: PUID and PGID must not be 0, Apache refuses to serve pages as root" >&2
  exit 1
fi

groupmod -o -g "$PGID" smokeping
usermod -o -u "$PUID" -g "$PGID" smokeping

mkdir -p /var/run/smokeping /var/lib/smokeping /var/cache/smokeping
chown smokeping:smokeping /var/run/smokeping /var/lib/smokeping /var/cache/smokeping
chown -R smokeping:smokeping /opt/smokeping/cache /opt/smokeping/var
chown -R smokeping:smokeping /var/lib/apache2/fcgid

# Only touch what is not already owned correctly, the RRD data can be large
find /config/ /data/ \( ! -uid "$PUID" -o ! -gid "$PGID" \) -exec chown -h "$PUID:$PGID" {} +

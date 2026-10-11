# rloomans/docker-smokeping

A fork of [mad-ady/docker-smokeping](https://github.com/mad-ady/docker-smokeping), which is itself based on [magicdude4eva/docker-smokeping](https://github.com/magicdude4eva/docker-smokeping).

Smokeping keeps track of your network latency. For a full example of what this application is
capable of visit [UCDavis](http://smokeping.ucdavis.edu/cgi-bin/smokeping.fcgi).

This image includes Smokeping, the `speedtest-cli` Python client, and `yt-dlp` (also available as
`youtube-dl` for compatibility with the YoutubeDL probe). It can run as a master or slave. The
default configuration needs tweaking, but should allow you to run out of the box.

![Smokeping Docker](https://github.com/magicdude4eva/docker-smokeping/raw/master/docker-smokeping.png)

## TL;DR - Features

- Private Smokeping branch (<https://github.com/rloomans/SmokePing>, forked from
  <https://github.com/mad-ady/SmokePing>)
- Speedtest probe ([smokeping-speedtest](https://github.com/mad-ady/smokeping-speedtest)) using
  the `speedtest-cli` Python client
- YoutubeDL probe ([smokeping-youtube-dl](https://github.com/mad-ady/smokeping-youtube-dl))
  using `yt-dlp`
- Working configuration for DNS, Speedtest and web-site probes
- Ability to run as a slave

[![smokeping](http://oss.oetiker.ch/smokeping/inc/smokeping-logo.png)](http://oss.oetiker.ch/smokeping/)

## Usage

Images are published for `linux/amd64` and `linux/arm64` to
- [Docker Hub](https://hub.docker.com/r/rloomans/smokeping-influx)
- [GitHub Container Registry](https://github.com/rloomans/docker-smokeping/pkgs/container/smokeping-influx).

Note - you can edit/use `smokeping-master-compose` or `smokeping-slave-compose` with
docker-compose after editing them.

Run standalone:

```bash
docker run \
    --name smokeping-master \
    --hostname smokeping-master \
    -p 9500:80 \
    -e PUID=<UID> -e PGID=<GID> \
    -e TZ=<timezone> \
    -e SMOKEPING_EXTRA_FLAGS="--debug-daemon" \
    -v <path/to/smokeping/data>:/data \
    -v <path/to/smokeping/config>:/config \
    rloomans/smokeping-influx:latest
```

Run as a slave (connected to `master.server.url`):

```bash
docker run \
    --name smokeping-slave \
    --hostname=smokeping-slave \
    -e PUID=<UID> -e PGID=<GID> \
    -e TZ=<timezone> \
    -e SMOKEPING_EXTRA_FLAGS="--debug-daemon" \
    -e SMOKEPING_MASTER_URL=<http://master.server.url:9500/smokeping/smokeping.fcgi> \
    -e SMOKEPING_SHARED_SECRET=<your_secret_goes_here_in_clear_text_unfortunately> \
    rloomans/smokeping-influx:latest
```

In order to run as a slave you'll need to edit the master configuration, specifically:

- Add the following to /config/Slaves:

```text
+smokeping-slave
display_name=smokeping-slave
color=0000ff
```

- Add slave credentials to `/config/smokeping_secrets` on the master (the file is created
  automatically if missing):

```text
smokeping-slave:your_secret_goes_here_in_clear_text_unfortunately
```

- The container sets `smokeping_secrets` to mode 440 on startup
- Assign measurements to be done by the slave in /config/Targets:

```text
+ slaves
menu = Slave measurement
title = Slave measurement

++ BBC
menu = BBC
title = bbc.co.uk HTTP Latency
host = bbc.co.uk
slaves = smokeping-slave
```

- If you're not getting results back from the slave you need to make the rrd files writable by
  apache on the master: <https://github.com/oetiker/SmokePing/issues/11>

## Parameters

The parameters are split into two halves, separated by a colon, the left hand side representing
the host and the right the container side.
For example with a port -p external:internal - what this shows is the port mapping from internal
to external of the container.
So -p 9500:80 would expose port 80 from inside the container to be accessible from the host's IP
on port 9500
http://192.168.x.x:9500 would show you what's running INSIDE the container on port 80.

- `-p 80` - the port for the webUI
- `-v /data` - Storage location for db and application data (graphs etc)
- `-v /config` - Configure the `Targets` file here
- `-e PGID` for GroupID, default 1000 - see below for explanation
- `-e PUID` for UserID, default 1000 - see below for explanation
- `-e TZ` for timezone setting, eg Africa/Johannesburg
- `-e SMOKEPING_EXTRA_FLAGS` to pass extra flags to smokeping (it's optional)
- `-e SMOKEPING_MASTER_URL` for a URL to the master instance (causes this container to be a
  slave)
- `-e SMOKEPING_SHARED_SECRET` the shared secret needed by the slave

This container is based on phusion/baseimage. For shell access whilst the container is running
do `docker exec -it smokeping-master /bin/bash`.

### User / Group Identifiers

Sometimes when using data volumes (`-v` flags) permissions issues can arise between the host OS
and the container. We avoid this issue by allowing you to specify the user `PUID` and group
`PGID`. The smokeping daemon and the web server run as this user and group, and ownership of
`/config` and `/data` is fixed up on startup. Both must be non-zero (Apache refuses to run as root).
The only process that still runs as root is `nscd`.

In this instance `PUID=1001` and `PGID=1001`. To find yours use `id dockeruser` as below:

```bash
  $ id dockeruser
    uid=1001(dockeruser) gid=1001(dockergroup) groups=1001(dockergroup)
```

## Setting up the application

Once running the URL will be `http://<host-ip>:9500/smokeping/smokeping.fcgi`.

Basics are, edit the Targets file to ping the hosts you're interested in to match the format
found there. Wait 10 minutes.

## Info

- To monitor the logs of the container in realtime `docker logs -f smokeping-master`.

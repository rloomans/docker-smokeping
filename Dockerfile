# syntax=docker/dockerfile:1
FROM phusion/baseimage:resolute-1.0.20 AS base

ARG APT_HTTP_PROXY

ENV \
    HOME="/root" \
    TERM="xterm" \
    LC_ALL=C \
    LANG=C

# Upgrade pre-installed packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
&&  if [ -n "$APT_HTTP_PROXY" ]; then \
        printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
    fi \
&&  apt-get update \
&&  DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y -o Dpkg::Options::="--force-confold" \
&&  rm -f /etc/apt/apt.conf.d/apt-proxy.conf \
&&  rm -rf /tmp/* /var/tmp/*

# Install common packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    if [ -n "$APT_HTTP_PROXY" ]; then \
        printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
    fi \
&&  apt-get update \
&&  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ca-certificates \
    curl \
    dnsutils \
    fping \
    libauthen-radius-perl \
    libcgi-fast-perl \
    libconfig-grammar-perl \
    libdigest-hmac-perl \
    libio-socket-ssl-perl \
    libio-tty-perl \
    libjs-cropper \
    libjs-prototype \
    libjs-scriptaculous \
    libnet-dns-perl \
    libnet-ldap-perl \
    libnet-ssleay-perl \
    libnet-telnet-perl \
    librrds-perl \
    libsnmp-session-perl \
    libsocket6-perl \
    libssl3 \
    liburi-perl \
    libwww-perl \
    openssh-client \
    perl \
    perl-base \
    rrdtool \
    zlib1g \
&&  rm -f /etc/apt/apt.conf.d/apt-proxy.conf \
&&  rm -rf /tmp/* /var/tmp/*

FROM base AS build
LABEL maintainer="Robert Loomans <robert@loomans.org>"
LABEL url="https://github.com/rloomans/docker-smokeping"
LABEL source="https://github.com/rloomans/docker-smokeping.git"

ARG APT_HTTP_PROXY

# ========================================================================================
# ====== SmokePing
ENV \
    HOME="/root" \
    TERM="xterm" \
    LC_ALL=C \
    LANG=C

# Install build dependencies and do the build
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    if [ -n "$APT_HTTP_PROXY" ]; then \
        printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
    fi \
&&  apt-get update \
&&  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    autoconf \
    build-essential \
    cpanminus \
    git \
    krb5-config \
    libkrb5-dev \
    libc6-dev \
    libcrypt-dev \
    libarchive-tools \
    libssl-dev \
    unzip \
    zlib1g-dev \
&&  rm -f /etc/apt/apt.conf.d/apt-proxy.conf \
&&  rm -rf /var/tmp/* \
# GNU tar 1.35 fails with "Function not implemented" under Rosetta amd64 emulation.
# cpanm uses the first tar on PATH, so shadow it with bsdtar in this build stage only.
&&  ln -s /usr/bin/bsdtar /usr/local/bin/tar

RUN \
    git clone https://github.com/rloomans/SmokePing.git \
&&  cd SmokePing \
&&  ./bootstrap \
&&  ./configure

# Pre-install Carton and raise cpanm's hard-coded 60s configure timeout. Carton clears
# PERL_CPANM_OPT, and on timeout cpanm kills the whole process group (and the build),
# which happens with slow module configure steps, e.g. under amd64 emulation.
RUN \
    cd SmokePing/thirdparty \
&&  make bin/cpanm \
&&  PERL_CPANM_OPT= PERL_CPANM_HOME=/SmokePing/thirdparty PERL_CARTON_PATH=/SmokePing/thirdparty \
    perl bin/cpanm -q --notest --local-lib-contained /SmokePing/thirdparty/carton Carton \
&&  sed -i 's/configure_timeout => 60,/configure_timeout => 600,/' \
    carton/lib/perl5/Menlo/CLI/Compat.pm \
&&  grep -q 'configure_timeout => 600' carton/lib/perl5/Menlo/CLI/Compat.pm

RUN \
    cd SmokePing \
&&  (PERL_MM_USE_DEFAULT=1 make install \
     || (cat thirdparty/work/*/build.log; false)) \
&&  mv htdocs/smokeping.fcgi.dist htdocs/smokeping.fcgi

###########################################################################################
# Target image                                                                            #
###########################################################################################

# create the production image
FROM base AS target
LABEL maintainer="Robert Loomans <robert@loomans.org>"
LABEL url="https://github.com/rloomans/docker-smokeping"
LABEL source="https://github.com/rloomans/docker-smokeping.git"

ARG APT_HTTP_PROXY

# Apache environment settings
ENV \
    HOME="/root" \
    TERM="xterm" \
    APACHE_LOG_DIR="/var/log/apache2" \
    APACHE_LOCK_DIR="/var/lock/apache2" \
    APACHE_PID_FILE="/var/run/apache2.pid" \
    PERL5LIB=/opt/smokeping/lib \
    LC_ALL=C \
    LANG=C

# Install runtime dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    if [ -n "$APT_HTTP_PROXY" ]; then \
        printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
    fi \
&& apt-get update \
&& DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 \
    busybox \
    dirmngr \
    dnsutils \
    fonts-dejavu \
    iproute2 \
    libapache2-mod-fcgid \
    nscd \
    python-is-python3 \
    speedtest-cli \
    ssmtp \
    syslog-ng \
    time \
    tzdata \
&&  apt-get autoremove -y \
&&  rm -f /etc/apt/apt.conf.d/apt-proxy.conf \
&&  rm -rf /var/tmp/* \
# Adjusting SyslogNG - see https://github.com/phusion/baseimage-docker/pull/223/commits/dda46884ed2b1b0f7667b9cc61a961e24e910784
&&  sed -ie "s/^       system();$/#      system(); #This is to avoid calls to \/proc\/kmsg inside docker/g" /etc/syslog-ng/syslog-ng.conf \
&&  rm /etc/ssmtp/ssmtp.conf

RUN \
    sed -i -e 's/\(enable-cache.*\)	yes$/\1 no/' /etc/nscd.conf \
&&  sed -i -e 's/\(enable-cache.*hosts.*\) no$/\1 yes/' /etc/nscd.conf

#Adding Custom files
COPY init/ /etc/my_init.d/
COPY services/ /etc/service/
COPY Alerts /tmp/Alerts
COPY Database /tmp/Database
COPY General /tmp/General
COPY Presentation /tmp/Presentation
COPY Probes /tmp/Probes
COPY Slaves /tmp/Slaves
COPY Targets /tmp/Targets
COPY pathnames /tmp/pathnames
COPY ssmtp.conf /tmp/ssmtp.conf
COPY config /tmp/config

# Copy Smokeping that we previously built
COPY --from=build /opt/smokeping-* /opt/smokeping

# Copy Smokeping Perl modules that were bulilt previously
RUN perl -V
COPY --from=build /usr/lib/*-linux-gnu/perl5 /usr/lib/*-linux-gnu/perl5/

# Copy smokemail, tmail, web interface
COPY --from=build /SmokePing/etc/smokemail.dist /etc/smokeping/smokemail
COPY --from=build /SmokePing/etc/tmail.dist /etc/smokeping/tmail
COPY --from=build /SmokePing/etc/basepage.html.dist /etc/smokeping/basepage.html
COPY --from=build /SmokePing/etc/config.dist /etc/smokeping/config
COPY --from=build /SmokePing/VERSION /opt/smokeping

COPY smokeping.conf /etc/apache2/sites-enabled/10-smokeping.conf

RUN \
    mkdir /var/run/smokeping \
&&  mkdir /var/cache/smokeping \
&&  mkdir  /opt/smokeping/cache \
&&  mkdir /opt/smokeping/var \
&&  mkdir /opt/smokeping/data \
# Create cache dir
&&  mkdir /var/lib/smokeping \
&&  mkdir /var/www/html/smokeping \
# Create the smokeping user
&&  useradd -d /opt/smokeping -G www-data smokeping \
&&  ln -s /opt/smokeping/cache /var/www/html/smokeping/cache \
&&  chown smokeping:www-data /opt/smokeping/cache \
&&  chmod g+w /opt/smokeping/cache \
&&  ln -s /opt/smokeping/data /data \
&&  chown -R smokeping:www-data /opt/smokeping/data

COPY favicon.ico /var/www/html/
COPY favicon.png /var/www/html/

RUN \
    chmod -v +x /etc/service/*/run \
&&  chmod -v +x /etc/my_init.d/*.sh \
#&&  ln -s /etc/smokeping /opt/smokeping/etc \
&&  mv /opt/smokeping/etc /opt/smokeping/etc.dist \
&&  ln -s /opt/smokeping/etc /config \
&&  ln -s /opt/smokeping /opt/smokeping-$(cat /opt/smokeping/VERSION)

COPY --from=build /SmokePing/htdocs/ /var/www/html/smokeping/

# Add custom probes and dependencies

RUN \
    curl -fsSL -o /opt/smokeping/lib/Smokeping/probes/speedtest.pm \
        https://github.com/mad-ady/smokeping-speedtest/raw/2351623c5a0df46ad83270edf8f0f35eb8e3edb4/speedtest.pm \
&&  curl -fsSL -o /opt/smokeping/lib/Smokeping/probes/YoutubeDL.pm \
        https://github.com/mad-ady/smokeping-youtube-dl/raw/3dde65432641b3f948d33471c58b5076b1062f26/YoutubeDL.pm \
&&  curl -fsSL -o /usr/local/bin/speedtest-cli \
        https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py \
&&  chmod a+x /usr/local/bin/speedtest-cli \
&&  curl -fsSL -o /usr/local/bin/yt-dlp \
        https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
&&  chmod a+x /usr/local/bin/yt-dlp \
&&  ln -s yt-dlp /usr/local/bin/youtube-dl

# Use baseimage-docker's init system
CMD ["/sbin/my_init"]

# Volumes and Ports
VOLUME /config
VOLUME /data
EXPOSE 80
# ========================================================================================

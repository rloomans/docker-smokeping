FROM phusion/baseimage:jammy-1.0.1 as base
MAINTAINER rloomans, https://github.com/rloomans/docker-phusion-baseimage

ARG APT_HTTP_PROXY

ENV \
    DEBIAN_FRONTEND="noninteractive" \
    HOME="/root" \
    TERM="xterm" \
    LC_ALL=C \
    LANG=C

# Upgrade pre-installed packages
RUN \
    if [ -n "$APT_HTTP_PROXY" ]; then \
        printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
    fi \
&&  apt-get update \
&&  apt-get dist-upgrade -y -o Dpkg::Options::="--force-confold" \
&&  apt-get clean \
&&  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /etc/apt/apt.conf.d/apt-proxy.conf

# Install common packages
RUN \
    if [ -n "$APT_HTTP_PROXY" ]; then \
        printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
    fi \
&&  apt-get update \
&&  apt-get install -y \
    curl \
    dnsutils \
    fping \
    libauthen-radius-perl \
    libcgi-fast-perl \
    libconfig-grammar-perl \
    libdigest-hmac-perl \
    libio-socket-ssl-perl \
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
    libssl-dev \
    liburi-perl \
    libwww-perl \
    openssh-client \
    rrdtool \
    zlib1g-dev \
&&  apt-get clean \
&&  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /etc/apt/apt.conf.d/apt-proxy.conf

FROM base as build
MAINTAINER rloomans, https://github.com/rloomans/docker-smokeping

# ========================================================================================
# ====== SmokePing
ENV \
    DEBIAN_FRONTEND="noninteractive" \
    HOME="/root" \
    TERM="xterm" \
    PERL_MM_USE_DEFAULT=1 \
    LC_ALL=C \
    LANG=C

# Install build dependencies and do the build
RUN \
    if [ -n "$APT_HTTP_PROXY" ]; then \
        printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
    fi \
&&  apt-get update \
&&  apt-get install -y \
    autoconf \
    build-essential \
    cpanminus \
    git \
    unzip \
&&  apt-get clean \
&&  rm -rf /var/lib/apt/lists/* /var/tmp/* /etc/apt/apt.conf.d/apt-proxy.conf

RUN \
    git clone https://github.com/rloomans/SmokePing.git \
&&  cd SmokePing \
&&  ./bootstrap \
&&  ./configure \
&&  (make install || (cat /SmokePing/thirdparty/work/*/build.log; false)) \
&&  mv htdocs/smokeping.fcgi.dist htdocs/smokeping.fcgi

###########################################################################################
# Target image                                                                            #
###########################################################################################

# create the production image
FROM base
MAINTAINER rloomans, https://github.com/rloomans/docker-smokeping

# Some build ENV variables
# LIBDIR looks like /usr/lib/x86_64-linux-gnu
# PERLDIR looks like /usr/lib/x86_64-linux-gnu/perl5/5.26
#ENV \
#   LIBDIR=$(ldconfig -v 2>/dev/null | grep /usr/lib | head --lines=2 | tail -1 | sed 's/:$//') \
#   PERLDIR=$(perl -V | grep $LIBDIR/perl5/ | tail -1 | sed 's/ *//') \
ENV \
    LIBDIR=/usr/lib/x86_64-linux-gnu \
    PERLDIR=/usr/lib/x86_64-linux-gnu/perl5/5.34

# Apache environment settings
ENV \
    DEBIAN_FRONTEND="noninteractive" \
    HOME="/root" \
    TERM="xterm" \
    APACHE_LOG_DIR="/var/log/apache2" \
    APACHE_LOCK_DIR="/var/lock/apache2" \
    APACHE_PID_FILE="/var/run/apache2.pid" \
    PERL_MM_USE_DEFAULT=1 \
    PERL5LIB=/opt/smokeping/lib \
    LC_ALL=C \
    LANG=C

# Fetch Ookla speedtest-cli installer - https://www.speedtest.net/apps/cli
RUN \
    curl -o ookla-speedtest-cli-install.sh https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh \
&&  chmod +x ookla-speedtest-cli-install.sh

# Install dependencies
RUN \
    ./ookla-speedtest-cli-install.sh \
&&  if [ -n "$APT_HTTP_PROXY" ]; then \
        printf 'Acquire::http::Proxy "%s";\n' "${APT_HTTP_PROXY}" > /etc/apt/apt.conf.d/apt-proxy.conf; \
    fi \
&& apt-get install -y \
    apache2 \
    apt-transport-https \
    busybox \
    dirmngr \
    dnsutils \
    fonts-dejavu \
    iproute2 \
    iw \
    libapache2-mod-fcgid \
    nscd \
    python-is-python3 \
    speedtest \
    ssmtp \
    syslog-ng \
    time \
    tzdata \
&&  apt-get autoremove -y \
&&  apt-get clean \
&&  rm -rf /var/lib/apt/lists/* /var/tmp/* /etc/apt/apt.conf.d/apt-proxy.conf \
# Adjusting SyslogNG - see https://github.com/phusion/baseimage-docker/pull/223/commits/dda46884ed2b1b0f7667b9cc61a961e24e910784
&&  sed -ie "s/^       system();$/#      system(); #This is to avoid calls to \/proc\/kmsg inside docker/g" /etc/syslog-ng/syslog-ng.conf \
&&  rm /etc/ssmtp/ssmtp.conf

RUN \
    sed -i -e 's/\(enable-cache.*\)	yes$/\1 no/' /etc/nscd.conf \
&&  sed -i -e 's/\(enable-cache.*hosts.*\) no$/\1 yes/' /etc/nscd.conf

#Adding Custom files
ADD init/ /etc/my_init.d/
ADD services/ /etc/service/
ADD Alerts /tmp/Alerts
ADD Database /tmp/Database
ADD General /tmp/General
ADD Presentation /tmp/Presentation
ADD Probes /tmp/Probes
ADD Slaves /tmp/Slaves
ADD Targets /tmp/Targets
ADD pathnames /tmp/pathnames
ADD ssmtp.conf /tmp/ssmtp.conf
ADD config /tmp/config

# Copy Smokeping that we previously built
COPY --from=build /opt/smokeping-* /opt/smokeping

# Copy Smokeping Perl modules that were bulilt previously
RUN perl -V
COPY --from=build ${PERLDIR}/ ${PERLDIR}/

# Copy smokemail, tmail, web interface
COPY --from=build /SmokePing/etc/smokemail.dist /etc/smokeping/smokemail
COPY --from=build /SmokePing/etc/tmail.dist /etc/smokeping/tmail
COPY --from=build /SmokePing/etc/basepage.html.dist /etc/smokeping/basepage.html
COPY --from=build /SmokePing/etc/config.dist /etc/smokeping/config
COPY --from=build /SmokePing/VERSION /opt/smokeping

ADD smokeping.conf /etc/apache2/sites-enabled/10-smokeping.conf

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

ADD favicon.ico /var/www/html/
ADD favicon.png /var/www/html/

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
    curl -L -o /opt/smokeping/lib/Smokeping/probes/speedtest.pm \
        https://github.com/mad-ady/smokeping-speedtest/raw/master/speedtest.pm \
&&  curl -L -o /opt/smokeping/lib/Smokeping/probes/speedtestcli.pm \
        https://github.com/mad-ady/smokeping-speedtest/raw/master/speedtestcli.pm \
&&  curl -L -o /opt/smokeping/lib/Smokeping/probes/YoutubeDL.pm \
        https://github.com/mad-ady/smokeping-youtube-dl/raw/master/YoutubeDL.pm \
&&  curl -L -o /opt/smokeping/lib/Smokeping/probes/WifiParam.pm \
        https://github.com/mad-ady/smokeping-wifi-param/raw/master/WifiParam.pm \
&&  curl -L -o /usr/local/bin/speedtest-cli \
        https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py \
&&  chmod a+x /usr/local/bin/speedtest-cli \
&&  curl -L -o /usr/local/bin/youtube-dl \
        https://yt-dl.org/downloads/latest/youtube-dl \
&&  chmod a+x /usr/local/bin/youtube-dl

# Use baseimage-docker's init system
CMD ["/sbin/my_init"]

# Volumes and Ports
VOLUME /config
VOLUME /data
EXPOSE 80
# ========================================================================================

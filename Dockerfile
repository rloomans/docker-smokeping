FROM phusion/baseimage:master as build
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

# Install base packages and do the build
RUN \
    apt-get update \
&&  apt-get install -y build-essential autoconf git cpanminus unzip rrdtool librrds-perl libnet-ssleay-perl libapache2-mod-fcgid \
&&  git clone https://github.com/mad-ady/SmokePing.git \
&&  cd SmokePing \
&&  ./bootstrap \
&&  ./configure \
&&  make install \
&&  mv htdocs/smokeping.fcgi.dist htdocs/smokeping.fcgi

###########################################################################################
# Target image                                                                            #
###########################################################################################

#create the production image
FROM phusion/baseimage:master
MAINTAINER rloomans, https://github.com/rloomans/docker-smokeping

# Some build ENV variables
# LIBDIR looks like /usr/lib/x86_64-linux-gnu
# PERLDIR looks like /usr/lib/x86_64-linux-gnu/perl5/5.26
#ENV \
#   LIBDIR=$(ldconfig -v 2>/dev/null | grep /usr/lib | head --lines=2 | tail -1 | sed 's/:$//') \
#   PERLDIR=$(perl -V | grep $LIBDIR/perl5/ | tail -1 | sed 's/ *//') \
ENV \
    LIBDIR=/usr/lib/x86_64-linux-gnu \
    PERLDIR=/usr/lib/x86_64-linux-gnu/perl5/5.26

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
COPY --from=build ${PERLDIR}/ ${PERLDIR}/

# Copy smokemail, tmail, web interface
COPY --from=build /SmokePing/etc/smokemail.dist /etc/smokeping/smokemail
COPY --from=build /SmokePing/etc/tmail.dist /etc/smokeping/tmail
COPY --from=build /SmokePing/etc/basepage.html.dist /etc/smokeping/basepage.html
COPY --from=build /SmokePing/etc/config.dist /etc/smokeping/config
COPY --from=build /SmokePing/VERSION /opt/smokeping

# Add Ookla Smokeping repository - https://www.speedtest.net/apps/cli

# Install dependencies
RUN \
    export OOKLA_REPO_KEY=379CE192D401AB61 \
&&  export DEB_DISTRO=$(lsb_release -sc) \
&&  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $OOKLA_REPO_KEY \
&&  echo "deb https://ookla.bintray.com/debian ${DEB_DISTRO} main" | tee  /etc/apt/sources.list.d/speedtest.list \
&&  apt-get update \
&&  apt-get install -y apache2 rrdtool fping ssmtp syslog-ng ttf-dejavu iw time dnsutils iproute2 busybox tzdata apt-transport-https dirmngr speedtest \
&&  chmod -v +x /etc/service/*/run \
&&  chmod -v +x /etc/my_init.d/*.sh \
&&  mkdir /var/run/smokeping \
&&  mkdir /var/cache/smokeping \
&&  mkdir /opt/smokeping/cache \
&&  mkdir /opt/smokeping/var \
&&  mkdir /opt/smokeping/data \
#&&  ln -s /etc/smokeping /opt/smokeping/etc \
&&  mv /opt/smokeping/etc /opt/smokeping/etc.dist \
&&  ln -s /opt/smokeping/etc /config \
&&  ln -s /opt/smokeping /opt/smokeping-$(cat /opt/smokeping/VERSION) \
# Create cache dir
&&  mkdir /var/lib/smokeping \
# Create the smokeping user
&&  useradd -d /opt/smokeping -G www-data smokeping \
# Enable cgid support in apache
&&  a2enmod cgid \
&&  sed -i 's/#AddHandler cgi-script .cgi/AddHandler cgi-script .cgi .pl .fcgi/' /etc/apache2/mods-available/mime.conf \
# Adjusting SyslogNG - see https://github.com/phusion/baseimage-docker/pull/223/commits/dda46884ed2b1b0f7667b9cc61a961e24e910784
&&  sed -ie "s/^       system();$/#      system(); #This is to avoid calls to \/proc\/kmsg inside docker/g" /etc/syslog-ng/syslog-ng.conf \
&&  rm /etc/ssmtp/ssmtp.conf \
&&  apt-get autoremove -y \
&&  apt-get clean \
&&  rm -rf /var/lib/apt/lists/* /var/tmp/*

ADD smokeping.conf /etc/apache2/sites-enabled/10-smokeping.conf
RUN  mkdir /var/www/html/smokeping \
&&  ln -s /opt/smokeping/cache /var/www/html/smokeping/cache \
&&  chown smokeping:www-data /opt/smokeping/cache \
&&  chmod g+w /opt/smokeping/cache \
&&  ln -s /opt/smokeping/data /data \
&&  chown -R smokeping:www-data /opt/smokeping/data
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
&&  curl -L -o /usr/local/bin/youtube-dl https://yt-dl.org/downloads/latest/youtube-dl \
&&  chmod a+x /usr/local/bin/youtube-dl


# Use baseimage-docker's init system
CMD ["/sbin/my_init"]

# Volumes and Ports
VOLUME /config
VOLUME /data
EXPOSE 80
# ========================================================================================

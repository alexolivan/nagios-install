#!/bin/bash
# +---------------------------------------------------------------------+
# |  ____ _               _        __  __ _  __  ____      ___        __|
# | / ___| |__   ___  ___| | __   |  \/  | |/ / |  _ \    / \ \      / /|
# || |   | '_ \ / _ \/ __| |/ /   | |\/| | ' /  | |_) |  / _ \ \ /\ / / |
# || |___| | | |  __/ (__|   <    | |  | | . \  |  _ <  / ___ \ V  V /  |
# | \____|_| |_|\___|\___|_|\_\___|_|  |_|_|\_\ |_| \_\/_/   \_\_/\_/   |
# |                          |_____|                                    |
# |                                                                     |
# | Copyright Alejandro Olivan 2017                 alex@alexolivan.com |
# +---------------------------------------------------------------------+
# | A Script that installs the following complementary monitoring       |
# | stuff over a previously installed nagios-core4 Debian system.       |
# | it is tested on (at least) Debian Stretch.                          |
# | - PNP4NAGIOS                                                        |
# | - Check_Mk                                                          |
# | - Nagvis                                                            |
# | The script needs to install stuff and modify some sys files.        |
# | Use at absolutelly your own risk!                                   |
# +---------------------------------------------------------------------+
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.


# SCRIPT SETUP AREA
# Setup those variable accordingly... specially those versions will outdate!
CHECKMKVERSION="check_mk-1.2.8p26"
PNP4NAGIOSTREE="PNP-0.6"
PNP4NAGIOSVERSION="pnp4nagios-0.6.26"
NAGVISVERSION="nagvis-1.9.3"


# SCRIPT EXECUTION CODE
echo ""
echo "...downloading check_mk..."
wget http://mathias-kettner.com/download/${CHECKMKVERSION}.tar.gz -O /usr/src/${CHECKMKVERSION}.tar.gz
echo ""
echo ""
echo "... downloading PNP4NAGIOS..."
wget wget https://sourceforge.net/projects/pnp4nagios/files/${PNP4NAGIOSTREE}/${PNP4NAGIOSVERSION}.tar.gz/download -O /usr/src/${PNP4NAGIOSVERSION}.tar.gz
echo ""
echo ""
echo "... downloading Nagvis..."
wget http://www.nagvis.org/share/${NAGVISVERSION}.tar.gz -O /usr/src/${NAGVISVERSION}.tar.gz

echo ""
echo ""
echo "Installing PNP4NAGIOS dependencies."
apt-get install -y php7.0-gd php-xml librrds-perl rrdtool

echo ""
echo "OK"
echo ""
echo ""
echo "Building PNP4NAGIOS..."
cd /usr/src
tar xzf ${PNP4NAGIOSVERSION}.tar.gz
cd ${PNP4NAGIOSVERSION}/
./configure --with-httpd-conf=/etc/apache2/sites-enabled --sysconfdir=/usr/local/pnp4nagios --with-base-url=/site01/pnp4nagios
make all
make fullinstall
systemctl restart apache2
rm /usr/local/pnp4nagios/share/install.php

cat >> /usr/local/nagios/etc/nagios.cfg << EOF


#
# Bulk / NPCD mode
#
process_performance_data=1
# *** the template definition differs from the one in the original nagios.cfg
#
service_perfdata_file=/usr/local/pnp4nagios/var/service-perfdata
service_perfdata_file_template=DATATYPE::SERVICEPERFDATA\\tTIMET::\$TIMET\$\\tHOSTNAME::\$HOSTNAME\$\\tSERVICEDESC::\$SERVICEDESC\$\\tSERVICEPERFDATA::\$SERVICEPERFDATA\$\\tSERVICECHECKCOMMAND::\$SERVICECHECKCOMMAND\$\\tHOSTSTATE::\$HOSTSTATE\$\\tHOSTSTATETYPE::\$HOSTSTATETYPE\$\\tSERVICESTATE::\$SERVICESTATE\$\\tSERVICESTATETYPE::\$SERVICESTATETYPE\$
service_perfdata_file_mode=a
service_perfdata_file_processing_interval=15
service_perfdata_file_processing_command=process-service-perfdata-file
#
# *** the template definition differs from the one in the original nagios.cfg
#
host_perfdata_file=/usr/local/pnp4nagios/var/host-perfdata
host_perfdata_file_template=DATATYPE::HOSTPERFDATA\\tTIMET::\$TIMET\$\\tHOSTNAME::\$HOSTNAME\$\\tHOSTPERFDATA::\$HOSTPERFDATA\$\\tHOSTCHECKCOMMAND::\$HOSTCHECKCOMMAND\$\\tHOSTSTATE::\$HOSTSTATE\$\\tHOSTSTATETYPE::\$HOSTSTATETYPE\$
host_perfdata_file_mode=a
host_perfdata_file_processing_interval=15
host_perfdata_file_processing_command=process-host-perfdata-file
EOF

cat >> /usr/local/nagios/etc/objects/misccommands.cfg << EOF
# Bulk with NPCD mode
define command {
               command_name process-service-perfdata-file
               command_line /bin/mv /usr/local/pnp4nagios/var/service-perfdata /usr/local/pnp4nagios/var/spool/service-perfdata.\$TIMET\$
}

define command {
               command_name process-host-perfdata-file
               command_line /bin/mv /usr/local/pnp4nagios/var/host-perfdata /usr/local/pnp4nagios/var/spool/host-perfdata.\$TIMET\$
}
EOF

sed -i '/\/usr\/local\/nagios\/etc\/routers/s/.*/&\n\n\n# Definitions for PNP4NAGIOS\ncfg_file=\/usr\/local\/nagios\/etc\/objects\/misccommands.cfg/' /usr/local/nagios/etc/nagios.cfg

echo ""
echo "OK"
echo ""
echo ""
echo "Installing chek_mk dependencies."
apt-get -y install libapache2-mod-python sudo

echo ""
echo "OK"
echo ""
echo ""
echo "Initializing check_mk setup..."
cd /usr/src
tar zxfv ${CHECKMKVERSION}.tar.gz
cd ${CHECKMKVERSION}
./setup.sh


systemctl enable mkeventd
systemctl restart apache2
systemctl restart nagios
systemctl restart mkeventd


echo ""
echo "OK"
echo ""
echo ""
echo "Installing nagvis dependencies."
apt-get install -y rsync php7.0-common libapache2-mod-php7.0 php7.0-cli php-gettext php7.0-cgi graphviz sqlite sqlite3 php7.0-sqlite libjson-xs-perl

echo ""
echo "OK"
echo ""
echo ""
echo "Building Nagvis..."
cd /usr/src
tar xvzf ${NAGVISVERSION}.tar.gz
cd ${NAGVISVERSION}
./install.sh -W /site01/nagvis -w /etc/apache2/sites-enabled

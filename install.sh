#!/bin/bash

# Default variables
COUNTRY="CO"
STATE="Central"
CITY="Bogota"
ORG="Nuntius"
ORG_UNIT="IT"
COMMON_NAME="www.nuntius.dev"
EMAIL="hola@nuntius.dev"
stunnel="/etc/init.d/stunnel4"

clear 
if [[ $(id -u) -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

if [ -f "$stunnel" ]; then
   clear
   echo "Reverting changes made by previous script..."

   # Stop and disable udpgw service
   systemctl stop udpgw.service
   systemctl disable udpgw.service

   # Remove udpgw service file
   rm -f /etc/systemd/system/udpgw.service

   # Remove udpgw binary
   rm -f /usr/bin/badvpn-udpgw

   # Remove stunnel config and certificate
   rm -f /etc/stunnel/stunnel.conf
   rm -f /etc/stunnel/stunnel.pem

   # Remove packages
   apt-get remove --purge -y dropbear stunnel4

   # Remove /bin/false from shells file
   sed -i '/\/bin\/false/d' /etc/shells

   # Remove user
   systemctl daemon-reload
   userdel -r aku 2>/dev/null
   echo "Done!"
else
   sleep 2
   echo "[SSH / SSL INSTALLER ]"
   echo "List of things:"
   echo "1. Dropbear"
   echo "2. Stunnel4"
   echo "3. UDPGW" 
   echo "Starting installation ... "
   sleep 3
   clear

   apt-get update -y 
   apt-get install -y wget curl dropbear stunnel4 sed

   sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=21/g' /etc/default/dropbear
   clear
   sleep 3

   echo "Generating certificates for stunnel..."
   openssl req -x509 -newkey rsa:4096 -keyout /etc/stunnel/stunnel.pem -out /etc/stunnel/stunnel.pem -days 365 -nodes -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$ORG/OU=$ORG_UNIT/CN=$COMMON_NAME/emailAddress=$EMAIL" &>/dev/null

   cat > /etc/stunnel/stunnel.conf <<EOF
[dropbear]
accept = 80
connect = 21
cert = /etc/stunnel/stunnel.pem
EOF

   sleep 3
   echo "Installing UDPGW and service of udpgw.service"

   OS=$(uname -m)
   URL="https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw"
   [ "$OS" = "x86_64" ] && URL="https://raw.githubusercontent.com/daybreakersx/premscript/master/badvpn-udpgw64"
   wget -O /usr/bin/badvpn-udpgw "$URL" &>/dev/null
   chmod +x /usr/bin/badvpn-udpgw

   cat > /etc/systemd/system/udpgw.service <<EOF
[Unit]
Description=UDPGW Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300
Restart=always

[Install]
WantedBy=multi-user.target
EOF

   systemctl daemon-reload
   systemctl enable udpgw.service
   systemctl restart udpgw.service

   sleep 2
   clear
   echo "/bin/false" >> /etc/shells
   sed -i 's/NO_START=1/NO_START=0/g' /etc/default/dropbear
   systemctl restart stunnel4
   systemctl restart dropbear

   echo "Creating user.."
   sleep 3
   useradd aku -M -s /bin/false
   echo "aku:aku" | chpasswd

   echo "[ SSH Info ]"
   echo "SSL Port: 80"
   echo "Dropbear Port: 21"
   echo "UDPGW Port: 7300"
   
   sleep 5
   rm -f /root/install.sh
fi

#!/bin/bash
set -e

# --- 1. SET IDENTITY ---
# Force hostname to UPPERCASE for consistency across all protocols
MYHOST=$(hostname | tr 'a-z' 'A-Z')

echo "------------------------------------------------"
echo "Initializing Network Share: $MYHOST"
echo "------------------------------------------------"

# --- 2. CONFIGURE SAMBA (SMB Protocol) ---
cat > /etc/samba/smb.conf <<SMB
[global]
   workgroup = WORKGROUP
   server string = Samba Docker
   netbios name = $MYHOST
   server role = standalone server
   local master = yes 
   os level = 20
   map to guest = Bad User
   usershare allow guests = yes
   log file = /var/log/samba/log.%m
   max log size = 50

[Media]
   path = /srv/samba/media
   browseable = yes
   read only = no
   guest ok = yes
   force user = nobody
   create mask = 0777
   directory mask = 0777
SMB

# --- 3. CONFIGURE AVAHI (mDNS Protocol) ---
sed -i 's/#enable-dbus=yes/enable-dbus=no/' /etc/avahi/avahi-daemon.conf
mkdir -p /etc/avahi/services

# CRITICAL FIX: We do NOT use %h here anymore. 
# We inject $MYHOST directly so Avahi broadcasts the exact same name as Samba.
cat > /etc/avahi/services/samba.service <<XML
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
 <name replace-wildcards="no">$MYHOST</name>
 <service>
   <type>_smb._tcp</type>
   <port>445</port>
 </service>
</service-group>
XML

# --- 4. START SERVICES ---

echo "Starting Avahi (mDNS)..."
avahi-daemon --daemonize --no-drop-root

echo "Starting WSDD (Windows Discovery)..."
wsdd --shortlog --hostname "$MYHOST" &

echo "Starting NetBIOS (nmbd)..."
service nmbd start

echo "Starting Samba (smbd)..."
smbd -F --no-process-group < /dev/null

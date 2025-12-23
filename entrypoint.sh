#!/bin/bash
set -e

# --- 1. SET IDENTITY ---
# Force hostname to UPPERCASE to match NetBIOS standards.
# This ensures Windows sees "MYSERVER" (NetBIOS) and "MYSERVER" (WSDD)
# as the same device, preventing ghost icons.
MYHOST=$(hostname | tr 'a-z' 'A-Z')

echo "------------------------------------------------"
echo "Initializing Network Share: $MYHOST"
echo "------------------------------------------------"

# --- 2. CONFIGURE SAMBA ---
cat > /etc/samba/smb.conf <<SMB
[global]
   # Identity
   workgroup = WORKGROUP
   server string = Samba Docker
   netbios name = $MYHOST
   
   # Network Behavior
   server role = standalone server
   local master = yes 
   os level = 20

   # Permissions (Guest Access - No Password)
   map to guest = Bad User
   usershare allow guests = yes
   
   # Logging
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

# --- 3. CONFIGURE AVAHI (Linux/Mac Visibility) ---
# Disable dbus requirement to allow running inside Docker
sed -i 's/#enable-dbus=yes/enable-dbus=no/' /etc/avahi/avahi-daemon.conf
mkdir -p /etc/avahi/services

# Create the mDNS service advertisement
cat > /etc/avahi/services/samba.service <<XML
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
 <name replace-wildcards="yes">%h</name>
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
# We explicitly force the hostname here to match the NetBIOS uppercase name
wsdd --shortlog --hostname "$MYHOST" &

echo "Starting NetBIOS (nmbd)..."
service nmbd start

echo "Starting Samba (smbd)..."
# Run in foreground to keep the container alive
smbd -F --no-process-group < /dev/null

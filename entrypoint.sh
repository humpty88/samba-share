
#!/bin/bash
set -e

MYHOST=$(hostname | tr 'a-z' 'A-Z')
echo "Setting network identity to: $MYHOST"

echo "[INFO] Configuring Samba..."
cat > /etc/samba/smb.conf <<EOF
[global]
   workgroup = WORKGROUP
   server string = Samba Docker
   netbios name = $MYHOST
   server role = standalone server
   map to guest = Bad User
   usershare allow guests = yes

[Media]
   path = /srv/samba/media
   browseable = yes
   read only = no
   guest ok = yes
   force user = nobody
   create mask = 0777
   directory mask = 0777
EOF

echo "[INFO] Configuring Avahi (Linux Visibility)..."
# Disable dbus requirement so it runs in a container
sed -i 's/#enable-dbus=yes/enable-dbus=no/' /etc/avahi/avahi-daemon.conf

mkdir -p /etc/avahi/services
cat > /etc/avahi/services/samba.service <<EOF
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
 <name replace-wildcards="yes">%h</name>
 <service>
   <type>_smb._tcp</type>
   <port>445</port>
 </service>
</service-group>
EOF

echo "[INFO] Starting Services..."

# 1. Start Avahi in daemon mode
avahi-daemon --daemonize --no-drop-root

# 2. Start WSDD (Windows Visibility) in background
wsdd --shortlog --hostname "$MYHOST" &

# 3. Start NetBIOS (nmbd) in daemon mode
nmbd -D

# 4. Start Samba (smbd) in foreground to keep container alive
echo "[INFO] Samba is ready."
smbd -F --no-process-group < /dev/null

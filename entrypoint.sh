cd ~/samba-share

cat << 'EOF' > entrypoint.sh
#!/bin/bash
set -e

# 1. Get Hostname and convert to UPPERCASE
# This ensures Windows sees only ONE computer
MYHOST=$(hostname | tr 'a-z' 'A-Z')
echo "Setting network identity to: $MYHOST"

# 2. Configure Samba with explicit NetBIOS name
cat > /etc/samba/smb.conf <<SMB
[global]
   workgroup = WORKGROUP
   server string = Samba Docker
   netbios name = $MYHOST
   server role = standalone server
   map to guest = Bad User
   usershare allow guests = yes
   
   # Optimization for browsing
   local master = yes
   os level = 20

[Media]
   path = /srv/samba/media
   browseable = yes
   read only = no
   guest ok = yes
   force user = nobody
   create mask = 0777
   directory mask = 0777
SMB

# 3. Configure Avahi (mDNS)
sed -i 's/#enable-dbus=yes/enable-dbus=no/' /etc/avahi/avahi-daemon.conf
mkdir -p /etc/avahi/services
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

# 4. Start Services
echo "Starting services..."

# Start Avahi
avahi-daemon --daemonize --no-drop-root

# Start WSDD (Force the hostname to match NetBIOS)
wsdd --shortlog --hostname "$MYHOST" &

# Start NetBIOS
nmbd -D

# Start Samba
smbd -F --no-process-group < /dev/null
EOF

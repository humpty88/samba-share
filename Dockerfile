FROM ubuntu:22.04

# Install Samba, WSDD, Avahi, and python3 (for wsdd)
# We clean up apt lists to keep the image small
RUN apt-get update && \
    apt-get install -y \
    samba \
    wsdd \
    avahi-daemon \
    python3 \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Create the directory for the share
RUN mkdir -p /srv/samba/media && \
    chmod 777 /srv/samba/media

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose necessary ports (TCP/UDP)
EXPOSE 137/udp 138/udp 139 445 3702/udp 5353/udp

ENTRYPOINT ["/entrypoint.sh"]

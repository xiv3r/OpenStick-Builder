#!/bin/sh -e

DEBIAN_FRONTEND=noninteractive
DEBCONF_NONINTERACTIVE_SEEN=true

echo 'tzdata tzdata/Areas select Etc' | debconf-set-selections
echo 'tzdata tzdata/Zones/Etc select UTC' | debconf-set-selections
echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections
echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections
rm -f "/etc/locale.gen"

apt update -qqy
apt upgrade -qqy
apt autoremove -qqy
apt install -qqy --no-install-recommends \
    bridge-utils \
    dnsmasq \
    iptables \
    libconfig11 \
    locales \
    modemmanager \
    netcat-traditional \
    network-manager \
    openssh-server \
    qrtr-tools \
    rmtfs \
    sudo \
    systemd-timesyncd \
    tzdata \
    wireguard-tools \
    wpasupplicant \
    bash-completion \
    curl \
    ca-certificates \
    zram-tools \
    bc \
    ifupdown2 \
    mobile-broadband-provider-info

# Cleanup
apt clean
rm -rf /var/lib/apt/lists/*
rm /etc/machine-id
rm /var/lib/dbus/machine-id
rm /etc/ssh/ssh_host_*
find /var/log -type f -delete

passwd -dl root

# Add user
adduser --disabled-password --comment "" user
# Set password
passwd user << EOD
1
1
EOD
# Add user to sudo group
usermod -aG sudo user

cat <<EOF >>/etc/bash.bashrc

alias ls='ls --color=auto -lh'
alias ll='ls --color=auto -lhA'
alias l='ls --color=auto -l'
alias cl='clear'
alias ip='ip --color'
alias bridge='bridge -color'
alias free='free -h'
alias df='df -h'
alias du='du -hs'

EOF

cat <<EOF >> /etc/systemd/journald.conf
SystemMaxUse=300M
SystemKeepFree=1G
EOF

# install dnsproxy
bash /install_dnsproxy.sh

systemctl mask systemd-networkd-wait-online.service

# Prevent the accidental shutdown by power button
sed -i 's/^#HandlePowerKey=poweroff/HandlePowerKey=ignore/' /etc/systemd/logind.conf

# Enable IPv4 and IPv6 forwarding
if [ -f /etc/sysctl.conf ]; then
    # Uncomment existing lines if they exist
    sed -i -e 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' -e 's/^#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/' /etc/sysctl.conf
    # Add the lines if they don't exist at all
    grep -q '^net.ipv4.ip_forward' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    grep -q '^net.ipv6.conf.all.forwarding' /etc/sysctl.conf || echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
else
    # Create the file with the required settings
    cat <<EOF > /etc/sysctl.conf
# Enable IPv4 forwarding
net.ipv4.ip_forward=1

# Enable IPv6 forwarding
net.ipv6.conf.all.forwarding=1
EOF
fi

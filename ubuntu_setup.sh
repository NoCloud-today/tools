# That is all root user operations
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# less words
cd /etc/update-motd.d/ && chmod -x 10-help-text 50-motd-news 91-release-upgrade

# add swap, ~twice of the size of RAM
RAM_SIZE=`free -b | awk '/Mem:/ {print $2 / 1024 / 1024 / 1024}'`
SWAP_SIZE=$(printf "%.0f" $(echo "$RAM_SIZE * 2 + 0.5" | bc))
swapon --show # status quo
free --giga -h #shows the RAM
fallocate -l $SWAP_SIZE."G" /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
swapon --show
echo "/swapfile    none    swap    sw    0   0" >> /etc/fstab

echo "alias glances='glances --disable-bg'" >> ~/.bashrc
dpkg-reconfigure tzdata # adjust timezone

# Unattended upgrades
systemctl enable unattended-upgrades
apt-config dump APT::Periodic::Unattended-Upgrade # shall be 1
ls /etc/apt/apt.conf.d/*unattended-upgrades # shall be one file
cat <<\EOF > /etc/apt/apt.conf.d/50unattended-upgrades
Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}";
        "${distro_id}:${distro_codename}-security";
        "${distro_id}ESMApps:${distro_codename}-apps-security";
        "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::AutoFixInterruptedDpkg "false";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";
Unattended-Upgrade::Verbose "true";
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
};
EOF
systemctl restart unattended-upgrades

# IPv6 is mostly causing problems
cat <<EOF >> /etc/sysctl.d/99-no_ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
service procps force-reload

# add automatic reboot at the night time
crontab -l | { cat; echo "$((RANDOM % 60)) $((2 + RANDOM % 4)) * * * /bin/sh -c '[ -f /var/run/reboot-required ] && sudo shutdown -r now'"; } | crontab -
crontab -l

# change ssh port
new_ssh_port=$(shuf -i 1025-32875 -n 1)

echo "NOTE new SSH port: $new_ssh_port"
read -p "Press Enter to continue or Ctrl+C to abort"

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i "s/^Port.*/Port $new_ssh_port/" /etc/ssh/sshd_config
sed -i "s/^\s*#*\s*Port\s*.*/Port $new_ssh_port/" /etc/ssh/sshd_config
grep Port /etc/ssh/sshd_config

read -p "Verify that port is valid and press Enter"

service sshd restart

apt update && apt upgrade -y
apt install -y btop glances vim

echo "set ts=4 sw=4" >> ~/.vimrc
echo "Changing default editor:"
sudo update-alternatives --config editor

echo "Done."

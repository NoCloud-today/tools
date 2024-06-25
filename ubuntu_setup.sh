# add swap, ~twice of the size of RAM
RAM_SIZE=`free -b | awk '/Mem:/ {print $2 / 1024 / 1024 / 1024}'`
SWAP_SIZE=$(printf "%.0f" $(echo "$RAM_SIZE * 2 + 0.5" | bc))
sudo swapon --show # status quo
free --giga -h #shows the RAM
sudo fallocate -l $SWAP_SIZE."G" /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
sudo swapon --show
echo "/swapfile    none    swap    sw    0   0" >> /etc/fstab

# Unattended upgrades
sudo systemctl enable unattended-upgrades
sudo apt-config dump APT::Periodic::Unattended-Upgrade # shall be 1
ls /etc/apt/apt.conf.d/*unattended-upgrades # shall be one file
cat <<EOF > /etc/apt/apt.conf.d/50unattended-upgrades
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

# Enable server restart flag with livepatch enabled

cat <<EOF > /etc/kernel/postinst.d/kernel-livepatch-reboot
#!/bin/sh

case "$DPKG_MAINTSCRIPT_PACKAGE::$DPKG_MAINTSCRIPT_NAME" in
   linux-image-extra*::postrm)
      exit 0;;
esac

if [ -d /var/run ]; then
    touch /var/run/reboot-required
    if ! grep -q "^$DPKG_MAINTSCRIPT_PACKAGE$" /var/run/reboot-required.pkgs 2> /dev/null ; then
        echo "$DPKG_MAINTSCRIPT_PACKAGE" >> /var/run/reboot-required.pkgs
    fi
fi
EOF

# add automatic reboot at the night time
crontab -l | { cat; echo "$((RANDOM % 60)) $((2 + RANDOM % 4)) * * * /bin/sh -c '[ -f /var/run/reboot-required ] && sudo shutdown -r now'"; } | crontab -

# change ssh port
new_ssh_port=$(shuf -i 1024-65535 -n 1)

echo "NOTE new SSH port: $new_ssh_port"
read -p "Press Enter to continue"

sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo sed -i "s/^Port.*/Port $new_ssh_port/" /etc/ssh/sshd_config
sudo sed -i "s/^\s*#*\s*Port\s*.*/Port $new_ssh_port/" /etc/ssh/sshd_config
sudo grep Port /etc/ssh/sshd_config

read -p "Check that port is valid and press Enter to continue (or Ctrl+C to abort)"

sudo service sshd restart

# Monitoring
sudo apt install monit

# Final touches
sudo dpkg-reconfigure tzdata # adjust timezone

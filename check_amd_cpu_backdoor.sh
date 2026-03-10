#!/usr/local/bin/bash

# A trivial port scan; fails if AMD's "management" ports are open

OPEN_PORTS_FOUND=0

# Grab all IPv4 addresses from ifconfig.
# Then, use grep -vE to EXCLUDE localhost (127.x) and RFC 1918 private IP ranges:
# 10.0.0.0/8, 192.168.0.0/16, and 172.16.0.0/12
PUBLIC_IPS=$(ifconfig | grep -w 'inet' | awk '{print $2}' | grep -vE '^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)')

if [ -z "$PUBLIC_IPS" ]; then
    echo "No public IP addresses found on this system."
    exit 0
fi

for IP in $PUBLIC_IPS; do
    echo "Scanning public interface IP: $IP..."

    # Run nmap. -Pn skips the ping check (useful if your firewall drops ICMP).
    NMAP_OUT=$(/usr/local/bin/nmap -Pn -p 623,664 "$IP")

    # Check if the output explicitly contains the word "open" for those ports.
    # The regex ensures it matches the standard nmap format like "623/tcp open"
    if echo "$NMAP_OUT" | grep -qE '^[0-9]+/(tcp|udp)[[:space:]]+open'; then
        echo "[!] WARNING: Open DASH/OOB port found on $IP!"
        echo "$NMAP_OUT" | grep -E '^[0-9]+/(tcp|udp)[[:space:]]+open'
        OPEN_PORTS_FOUND=1
    else
        echo "[OK] No open management ports found on $IP."
    fi
    echo "----------------------------------------"
done

# Evaluate findings and exit
if [ "$OPEN_PORTS_FOUND" -eq 1 ]; then
    echo "Check complete: Exposed management ports DETECTED."
    exit 6
else
    echo "Check complete: No exposed management ports."
    exit 0
fi

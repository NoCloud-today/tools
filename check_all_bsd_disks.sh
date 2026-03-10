#!/bin/sh
# =======================================================================================
# Check disks health on FreeBSD; fails if SMART pass, but faulty blocks are there already
# =======================================================================================

RAW_DEVICES=""

# 1. Get standard ATA/SATA/SAS block devices from kern.disks
RAW_DISKS=$(sysctl -n kern.disks)
for disk in $RAW_DISKS; do
    # Only keep 'ada' (SATA) or 'da' (SCSI/SAS)
    # This intentionally ignores 'nda' and 'nvd' (NVMe block namespaces)
    if echo "$disk" | grep -q -E "^(ada|da)[0-9]+$"; then
        RAW_DEVICES="$RAW_DEVICES /dev/$disk"
    fi
done

# 2. Get NVMe controller devices directly
# smartctl requires the controller node (/dev/nvmeX) instead of the block node
for nvme in $(ls /dev/nvme[0-9]* 2>/dev/null); do
    # Ensure we only grab base controllers (nvme0, nvme1) and not namespaces (nvme0ns1)
    if echo "$nvme" | grep -q -E "^/dev/nvme[0-9]+$"; then
        RAW_DEVICES="$RAW_DEVICES $nvme"
    fi
done

# 3. Sort the list alphabetically
DEVICES=$(echo "$RAW_DEVICES" | tr ' ' '\n' | grep -v '^$' | sort)

# If no devices are found, alert and exit
if [ -z "$DEVICES" ]; then
    echo "UNKNOWN: No physical disks found on this system."
    exit 3
fi

# Track overall status (0 = OK, 2 = CRITICAL, 3 = UNKNOWN)
OVERALL_EXIT=0

for DEVICE in $DEVICES; do
    # Fetch SMART data text output using sudo
    SMART_OUT=$(/usr/local/bin/sudo /usr/local/sbin/smartctl -x "$DEVICE")

    # Detect NVMe drives
    if echo "$SMART_OUT" | grep -q "NVMe Version"; then
        # Extract the number from "Error Information Log Entries:      0"
        ERROR_COUNT=$(echo "$SMART_OUT" | grep "^Error Information Log Entries:" | awk '{print $5}')

        # If empty for any reason, default to 0
        [ -z "$ERROR_COUNT" ] && ERROR_COUNT=0

        if [ "$ERROR_COUNT" -gt 0 ] 2>/dev/null; then
            echo "CRITICAL: $DEVICE (NVMe) has $ERROR_COUNT logged SMART errors!"
            OVERALL_EXIT=2
        else
            echo "OK: $DEVICE (NVMe) error log is clean."
        fi

    # Detect ATA/SATA drives
    elif echo "$SMART_OUT" | grep -q -E "ATA Version|SATA Version"; then
        # Extract the number from "Device Error Count: X"
        ERROR_COUNT=$(echo "$SMART_OUT" | grep "^Device Error Count:" | awk '{print $4}')

        # Fallback to 0 if the line wasn't found (e.g., "No Errors Logged")
        [ -z "$ERROR_COUNT" ] && ERROR_COUNT=0

        if [ "$ERROR_COUNT" -gt 0 ] 2>/dev/null; then
            echo "CRITICAL: $DEVICE (ATA) has $ERROR_COUNT logged SMART errors!"
            OVERALL_EXIT=2
        else
            echo "OK: $DEVICE (ATA) error log is clean."
        fi

    else
        echo "UNKNOWN: Could not determine drive protocol for $DEVICE."
        [ $OVERALL_EXIT -lt 3 ] && OVERALL_EXIT=3
    fi
done

# Exit with the highest severity encountered
exit $OVERALL_EXIT

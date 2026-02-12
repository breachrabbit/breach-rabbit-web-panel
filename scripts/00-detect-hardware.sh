#!/bin/bash
set -e

echo "Detecting hardware configuration..."

# CPU Info
CPU_COUNT=$(nproc)
CPU_MODEL=$(lscpu | grep "Model name" | sed 's/Model name: *//')
CPU_SPEED=$(lscpu | grep "CPU MHz" | awk '{print $3}')

# RAM Info
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
AVAILABLE_RAM=$(free -m | awk '/^Mem:/{print $7}')

# Swap Info
TOTAL_SWAP=$(free -m | awk '/^Swap:/{print $2}')

# Disk Info
DISK_TOTAL=$(df -BG / | awk 'NR==2 {print $2}')
DISK_AVAILABLE=$(df -BG / | awk 'NR==2 {print $4}')
DISK_USED=$(df -BG / | awk 'NR==2 {print $3}')

# Network
PRIMARY_IP=$(hostname -I | awk '{print $1}')

# OS Info
source /etc/os-release
OS_NAME="$NAME"
OS_VERSION="$VERSION_ID"

echo "Hardware Detection Results:"
echo "==========================="
echo "CPU: ${CPU_COUNT} cores"
echo "CPU Model: ${CPU_MODEL}"
echo "CPU Speed: ${CPU_SPEED} MHz"
echo "RAM: ${TOTAL_RAM}MB total, ${AVAILABLE_RAM}MB available"
echo "Swap: ${TOTAL_SWAP}MB"
echo "Disk: ${DISK_AVAILABLE} available of ${DISK_TOTAL}"
echo "Primary IP: ${PRIMARY_IP}"
echo "OS: ${OS_NAME} ${OS_VERSION}"
echo ""

# Determine configuration profile
if [ "$TOTAL_RAM" -lt 2000 ]; then
    PROFILE="minimal"
    WORKERS=1
    MAX_CONN=150
elif [ "$TOTAL_RAM" -lt 4000 ]; then
    PROFILE="standard"
    WORKERS=2
    MAX_CONN=300
elif [ "$TOTAL_RAM" -lt 8000 ]; then
    PROFILE="performance"
    WORKERS=4
    MAX_CONN=500
else
    PROFILE="high_performance"
    WORKERS=8
    MAX_CONN=1000
fi

echo "Recommended Profile: ${PROFILE}"
echo "Workers: ${WORKERS}"
echo "Max Connections: ${MAX_CONN}"
echo ""

# Export variables for other scripts
cat > /tmp/hardware-config.sh <<EOF
export HW_PROFILE="${PROFILE}"
export HW_WORKERS=${WORKERS}
export HW_MAX_CONN=${MAX_CONN}
export HW_RAM=${TOTAL_RAM}
export HW_CPU=${CPU_COUNT}
export HW_IP="${PRIMARY_IP}"
EOF

echo "Configuration saved to /tmp/hardware-config.sh"
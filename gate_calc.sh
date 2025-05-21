#!/bin/bash
set -e
cd "$(dirname "$0")"

# =====[ Argument Parsing ]=====
if [ $# -ne 1 ]; then
    echo "Usage: $0 <path_to_circuit_file.circom>"
    exit 1
fi

CIRCUIT_FILE="$1"
CIRCUIT_BASENAME=$(basename "$CIRCUIT_FILE" .circom)

# =====[ Build Paths ]=====
BUILD_DIR="build"
mkdir -p "$BUILD_DIR"
R1CS_FILE="$BUILD_DIR/${CIRCUIT_BASENAME}.r1cs"

# =====[ Compile Circom ]=====
echo "[1] Compile Circom → R1CS"
circom "$CIRCUIT_FILE" \
    --r1cs \
    --wasm \
    --sym \
    -o "$BUILD_DIR"

# =====[ Check system memory and choose heap size ]=====
echo "[2] Estimate heap size for snarkjs (r1cs info)"
MEM_MB=$(free -m | awk '/^Mem:/ {print $2}')
# Use 50% of total memory as max heap size (in MB)
HEAP_MB=$((MEM_MB / 2))

echo "  > Total system memory: ${MEM_MB}MB"
echo "  > Setting --max-old-space-size=${HEAP_MB}"

# =====[ Run snarkjs r1cs info safely ]=====
echo "[3] Run snarkjs r1cs info with increased heap"
node --max-old-space-size=${HEAP_MB} $(which snarkjs) r1cs info "$R1CS_FILE"

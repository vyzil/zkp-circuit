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

# =====[ Environment Setup ]=====
BUILD_DIR="build"
PTAU_DIR="ptau"
CURVE="bls12381"
PTAU_POWER=17

R1CS_FILE="$BUILD_DIR/${CIRCUIT_BASENAME}.r1cs"
PTAU_INIT="$PTAU_DIR/pot${PTAU_POWER}_0000.ptau"
PTAU_FILE="$PTAU_DIR/pot${PTAU_POWER}_final.ptau"
PTAU_PREPARED="$PTAU_DIR/pot${PTAU_POWER}_prepared.ptau"
ZKEY_FILE="$BUILD_DIR/${CIRCUIT_BASENAME}.zkey"
ZKEY_JSON="$BUILD_DIR/zkey.json"
VK_JSON="$BUILD_DIR/verification_key.json"

mkdir -p "$BUILD_DIR"

# =====[ 1. Compile Circom circuit with curve info ]=====
echo "[1] Compile Circom circuit (curve: $CURVE)"
circom "$CIRCUIT_FILE" \
    --r1cs \
    --wasm \
    --sym \
    --prime "$CURVE" \
    -o "$BUILD_DIR"

# =====[ 2. Extract R1CS gate count and compute 2^k ]=====
echo "[2] Extract R1CS constraint count"
R1CS_COUNT=$(snarkjs r1cs info "$R1CS_FILE" | sed -r "s/\x1B\[[0-9;]*[mK]//g" | grep "# of Constraints" | awk '{print $6}')

# Round up to nearest power of 2 (log2 using integer loop)
R1CS_LOG2=0
temp=$R1CS_COUNT
while [ "$temp" -gt 1 ]; do
  temp=$(( (temp + 1) / 2 ))
  R1CS_LOG2=$((R1CS_LOG2 + 1))
done
R1CS_NTT_SIZE=$((2 ** R1CS_LOG2))

# =====[ 3. Generate ptau and zkey ]=====
echo "[3] Generate ptau and zkey"
if [ ! -f "$PTAU_FILE" ]; then
    echo "  > Creating ptau (2^$PTAU_POWER)"
    snarkjs powersoftau new "$CURVE" "$PTAU_POWER" "$PTAU_INIT" -v
    echo "dummy entropy" | snarkjs powersoftau contribute "$PTAU_INIT" "$PTAU_FILE" --name="dummy"
fi

if [ ! -f "$PTAU_PREPARED" ]; then
    echo "  > Preparing phase2 ptau"
    snarkjs powersoftau prepare phase2 "$PTAU_FILE" "$PTAU_PREPARED"
fi

echo "  > Generating PLONK zkey"
snarkjs plonk setup "$R1CS_FILE" "$PTAU_PREPARED" "$ZKEY_FILE"
snarkjs zkey export verificationkey "$ZKEY_FILE" "$VK_JSON"

# =====[ 4. Extract PLONK power from verification key ]=====
echo "[4] Extract PLONK domain size (from verification key)"
PLONK_POWER=$(grep '"power"' "$VK_JSON" | head -1 | grep -o '[0-9]\+')
PLONK_NTT_SIZE=$((2 ** PLONK_POWER))

# =====[ Final Output ]=====
echo ""
echo "✅ Gate / Domain Size Summary"
echo "🔢 R1CS  gate count: $R1CS_COUNT → rounded NTT size: 2^$R1CS_LOG2 = $R1CS_NTT_SIZE"
echo "🔢 PLONK domain size (from power): 2^$PLONK_POWER = $PLONK_NTT_SIZE"

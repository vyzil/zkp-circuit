#!/bin/bash
set -e
cd "$(dirname "$0")"

if [ $# -ne 1 ]; then
    echo "Usage: $0 <path_to_circuit_file.circom>"
    exit 1
fi

CIRCUIT_FILE="$1"
CIRCUIT_BASENAME=$(basename "$CIRCUIT_FILE" .circom)
BUILD_DIR="build"
PTAU_DIR="ptau"
ENTROPY="shin_2025_test_entropy_7q82v9$%^"
R1CS_FILE="$BUILD_DIR/${CIRCUIT_BASENAME}.r1cs"
ZKEY_FILE="$BUILD_DIR/${CIRCUIT_BASENAME}.zkey"
VK_FILE="$BUILD_DIR/verification_key.json"

mkdir -p "$BUILD_DIR" "$PTAU_DIR"

# Step 1: Compile Circom if needed
if [ ! -f "$R1CS_FILE" ]; then
    echo "[1] R1CS not found. Compiling..."
    circom "$CIRCUIT_FILE" --r1cs --wasm --sym -o "$BUILD_DIR"
else
    echo "[1] R1CS already exists: $R1CS_FILE"
fi

# Step 2: Get constraint count
MEM_MB=$(free -m | awk '/^Mem:/ {print $2}')
HEAP_MB=$((MEM_MB / 2))
NODE_CMD="node --max-old-space-size=${HEAP_MB} $(which snarkjs)"

echo "[2] Reading R1CS info using heap ${HEAP_MB} MB"
RAW_CONSTRAINTS=$($NODE_CMD r1cs info "$R1CS_FILE" | sed -r "s/\x1B\[[0-9;]*[mK]//g" | grep "# of Constraints" | awk '{print $6}')

# Step 3: Estimate domain power
k=0
temp=$RAW_CONSTRAINTS
while [ "$temp" -gt 1 ]; do
  temp=$(( (temp + 1) / 2 ))
  k=$((k + 1))
done
NTT_SIZE=$((2 ** k))

PTAU_INIT="$PTAU_DIR/pot${k}_0000.ptau"
PTAU_FINAL="$PTAU_DIR/pot${k}_final.ptau"
PTAU_PREPARED="$PTAU_DIR/pot${k}_prepared.ptau"

echo ""
echo "✅ Estimated PLONK Gate / Domain Size"
echo "🔢 R1CS constraint count : $RAW_CONSTRAINTS"
echo "🔢 Estimated PLONK domain: 2^$k = $NTT_SIZE"

# Step 4: Generate ptau if missing
if [ ! -f "$PTAU_FINAL" ]; then
    echo "[3] PTAU not found. Generating..."
    $NODE_CMD powersoftau new bls12381 $k "$PTAU_INIT" -v
    $NODE_CMD powersoftau contribute "$PTAU_INIT" "$PTAU_FINAL" --name="auto" <<< $ENTROPY
else
    echo "[3] PTAU already exists: $PTAU_PREPARED"
fi

# Step 5: Prepare ptau for phase2
if [ ! -f "$PTAU_PREPARED" ]; then
    echo "   > Preparing phase2 ptau..."
    $NODE_CMD powersoftau prepare phase2 "$PTAU_FINAL" "$PTAU_PREPARED"
fi

# Step 6: Run plonk setup
echo "[4] Running PLONK setup..."
$NODE_CMD plonk setup "$R1CS_FILE" "$PTAU_PREPARED" "$ZKEY_FILE"
$NODE_CMD zkey export verificationkey "$ZKEY_FILE" "$VK_FILE"

# Step 7: Extract actual PLONK domain power
PLONK_POWER=$(grep '"power"' "$VK_FILE" | head -1 | grep -o '[0-9]\+')
PLONK_NTT_SIZE=$((2 ** PLONK_POWER))

# Final Summary
echo ""
echo "🎯 Final Verification"
echo "🔢 R1CS constraints       : $RAW_CONSTRAINTS"
echo "📐 Estimated PLONK power  : $k (2^$k = $NTT_SIZE)"
echo "📏 Actual PLONK power     : $PLONK_POWER (2^$PLONK_POWER = $PLONK_NTT_SIZE)"
echo "✔️  ZKey and VK ready."

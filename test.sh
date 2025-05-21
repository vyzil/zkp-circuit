#!/bin/bash
set -e
cd "$(dirname "$0")"

# Environment
BUILD_DIR="build"
ENTROPY="shin_2025_test_entropy_7q82v9$%^"
CURVE="bls12381"
DEGREE=17

mkdir -p $BUILD_DIR

echo "[1] Compile Circom circuit with --prime=$CURVE"
circom model.circom \
    --r1cs \
    --wasm \
    --sym \
    --prime $CURVE \
    -o $BUILD_DIR

echo "[2] Trusted setup: Powers of Tau (degree=2^$DEGREE, curve=$CURVE)"
snarkjs powersoftau new $CURVE $DEGREE \
    $BUILD_DIR/pot${DEGREE}_0000.ptau -v

echo "$ENTROPY" | snarkjs powersoftau contribute \
    $BUILD_DIR/pot${DEGREE}_0000.ptau \
    $BUILD_DIR/pot${DEGREE}_final.ptau \
    --name="shin" -v

snarkjs powersoftau prepare phase2 \
    $BUILD_DIR/pot${DEGREE}_final.ptau \
    $BUILD_DIR/pot${DEGREE}_prepared.ptau
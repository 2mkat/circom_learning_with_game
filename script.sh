#!/bin/bash
set -e

CIRCUIT_NAME=$1
if [ ! $1 ]; then
    echo "You should pass <name> of the existing <name>.circom template to run all. Example: ./script.sh game.circom"
    exit 1
fi

BUILD_DIR=build
if [ ${#BUILD_DIR} -lt 1 ]; then 
    echo "BUILD_DIR var is empty, exiting";
    exit 2;
fi
echo "Removing previous build dir ./$BUILD_DIR to create new empty"
rm -rf ./$BUILD_DIR
if [ ! -d "$BUILD_DIR" ]; then
    echo "Creating new buld dir: '$BUILD_DIR'"
    mkdir "$BUILD_DIR"
fi

if [ ! -f circuits/${CIRCUIT_NAME}.circom ]; then
    echo "circuits/${CIRCUIT_NAME}.circom template doesn't exist, exit..."
    exit 3
fi

# directory to keep PowersOfTau, zkeys, and other non-circuit-dependent files
POTS_DIR=pots

# power value for "powersOfTau28" pre-generated setup files
POWERTAU=12

# uncomment to output every actual command being run
# set -x

# To generate setup by yourself, don't download below, use:
snarkjs powersoftau new bn128 ${POWERTAU} tmp.ptau -v
snarkjs powersoftau prepare phase2 tmp.ptau powersOfTau28_hez_final_${POWERTAU}.ptau


echo "Building R1CS for circuit ${CIRCUIT_NAME}.circom"
if ! /usr/bin/time -f "[PROFILE] R1CS gen time: %E" circom circuits/${CIRCUIT_NAME}.circom --r1cs --wasm --sym --output "$BUILD_DIR"; then
    echo "circuits/${CIRCUIT_NAME}.circom compilation to r1cs failed. Exiting..."
    exit 4
fi


echo "Info about circuits/${CIRCUIT_NAME}.circom R1CS constraints system"
snarkjs info -c ${BUILD_DIR}/${CIRCUIT_NAME}.r1cs

echo "Printing constraints"
snarkjs r1cs print ${BUILD_DIR}/${CIRCUIT_NAME}.r1cs ${BUILD_DIR}/${CIRCUIT_NAME}.sym

snarkjs groth16 setup ${BUILD_DIR}/${CIRCUIT_NAME}.r1cs powersOfTau28_hez_final_${POWERTAU}.ptau \
    ${BUILD_DIR}/${CIRCUIT_NAME}.zkey

rm tmp.ptau

echo "Exporting verification key to ${BUILD_DIR}/${CIRCUIT_NAME}_verification_key.json"
snarkjs zkey export verificationkey ${BUILD_DIR}/${CIRCUIT_NAME}.zkey \
    ${BUILD_DIR}/${CIRCUIT_NAME}_verification_key.json

echo "Output size of ${BUILD_DIR}/${CIRCUIT_NAME}_verification_key.json"
echo "[PROFILE]" `du -kh "${BUILD_DIR}/${CIRCUIT_NAME}_verification_key.json"`


echo " "
echo "############################################"
echo "Going to client's side into \"${BUILD_DIR}/${CIRCUIT_NAME}_js\" folder"
cd ${BUILD_DIR}/${CIRCUIT_NAME}_js


echo "Generate witness from input.json, using ${CIRCUIT_NAME}.wasm, saving to ${CIRCUIT_NAME}_witness.wtns"
/usr/bin/time -f "[PROFILE] Witness generation time: %E" \
    node generate_witness.js ${CIRCUIT_NAME}.wasm ../../circuits/input.json \
        ./${CIRCUIT_NAME}_witness.wtns

echo "Starting proving that we have a witness (our input.json in form of ${CIRCUIT_NAME}_witness.wtn)"
echo "Proof and public signals are saved to ${CIRCUIT_NAME}_proof.json and ${CIRCUIT_NAME}_public.json"
/usr/bin/time -f "[PROFILE] Prove time: %E" \
    snarkjs groth16 prove ../${CIRCUIT_NAME}.zkey ./${CIRCUIT_NAME}_witness.wtns \
        ./${CIRCUIT_NAME}_proof.json \
        ./${CIRCUIT_NAME}_public.json

echo "Checking proof of knowledge of private inputs for ${CIRCUIT_NAME}_public.json using ${CIRCUIT_NAME}_verification_key.json"
/usr/bin/time -f "[PROFILE] Verify time: %E" \
    snarkjs groth16 verify ../${CIRCUIT_NAME}_verification_key.json \
        ./${CIRCUIT_NAME}_public.json \
        ./${CIRCUIT_NAME}_proof.json

set +x

echo "Output sizes of client's side files":
echo "[PROFILE]" `du -kh "${CIRCUIT_NAME}.wasm"`
echo "[PROFILE]" `du -kh "${CIRCUIT_NAME}_witness.wtns"`



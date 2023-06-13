import random
import hashlib
import string
import os
import json

N = 4   # size of the secret number

def generate_solution(n):
    digits = random.sample("1234567890", n)
    number = int("".join(digits))
    if number < 1000:
        number = number * 10

    return number


def generate_clue(privateSolution, publicGuess):
    numBulls = 0
    numCows = 0

    guess = list(str(publicGuess))
    soln = list(str(privateSolution))

    for i, char in enumerate(guess):
        if soln[i] == char:
            numBulls += 1
            guess[i] = 0
            soln[i] = 0

    for i, gs in enumerate(guess):
        for j, ss in enumerate(soln):
            if i != j and guess[i] != 0 and guess[i] == soln[j]:
                numCows += 1
                guess[i] = 0
                soln[j] = 0

    return numBulls, numCows

def rand_string(n=12, alphabet=string.ascii_uppercase + string.ascii_lowercase + string.digits):
    return ''.join(random.choice(alphabet) for _ in range(n))

def json_response(obj):
    return json.dumps(
            obj,
            separators=(',', ':')
        )

def game():
    # perform actions for creation input.json
    privateSolution = generate_solution(N)

    # generate salt, solution + salt put it to json
    salt = str(int(rand_string().encode().hex(), 16))
    corSaltSoln = str(privateSolution) + salt
    pubSolutionHash = hashlib.sha256(corSaltSoln.encode()).hexdigest()

    while True:
        print(f"Pls, enter public guess with size = {N}: ")
        publicGuess = input()
        numBulls, numCows = generate_clue(privateSolution, publicGuess)
        print(f"Bulls = {numBulls}, Cows = {numCows}")
        
        json_response({
        'pubGuess': [int(i) for i in publicGuess],
        'pubNumBulls': numBulls,
        'pubNumCows': numCows,
        'pubSolutionHash': str(int(pubSolutionHash, 16)),
        'corSolution': [int(i) for i in str(privateSolution)],
        'corSaltedSoln': corSaltSoln,
        })

        os.system("echo Generate witness from input.json, using game.wasm, saving to game_witness.wtns")
        os.system("/usr/bin/time -f \"[PROFILE] Witness generation time: %E\" \
        node game_js/generate_witness.js game_js/game.wasm ../circuits/input.json \
        ./game_witness.wtns")

        os.system("echo Starting proving that we have a witness")
        os.system("echo Proof and public signals are saved to game_proof.json and game_public.json")
        os.system("/usr/bin/time -f \"[PROFILE] Prove time: %E\" \
                snarkjs groth16 prove game.zkey ./game_witness.wtns ./game_proof.json \
                ./game_public.json")

        os.system("echo Checking proof of knowledge of private inputs for game_public.json using game_verification_key.json")
        os.system("/usr/bin/time -f \"[PROFILE] Verify time: %E\" \
                snarkjs groth16 verify ./game_verification_key.json \
                ./game_public.json ./game_proof.json")

        os.system("echo Output sizes of clients side files")
        os.system("echo \"[PROFILE]\" `du -kh \"game_js/game.wasm\"`")
        os.system("echo \"[PROFILE]\" `du -kh \"game_witness.wtns\"`")

        if numBulls == N:
            print("YOU ARE WIN")
            break


if __name__ == '__main__':
    # trusted setup
    os.system("snarkjs powersoftau new bn128 12 tmp.ptau -v")
    os.system("snarkjs powersoftau prepare phase2 tmp.ptau powersOfTau28_hez_final_12.ptau")
    os.system("echo Building R1CS for circuit game.circom")
    os.system("/usr/bin/time -f \"[PROFILE] R1CS gen time: %E\" circom ../circuits/game.circom --r1cs --wasm --sym")
    os.system("snarkjs info -c game.r1cs")
    os.system("snarkjs groth16 setup game.r1cs powersOfTau28_hez_final_12.ptau game.zkey")
    os.system("snarkjs zkey export verificationkey game.zkey game_verification_key.json")

    while(True):
        print("SERVER STARTS A NEW GAME")
        game()

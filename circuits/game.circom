pragma circom 2.0.0;

include "../node_modules/circomlib/circuits/comparators.circom";
include "hash.circom";

template MainLogic(n) {
    // Публичные входы
    signal input pubGuess[n];
    signal input pubNumBulls;
    signal input pubNumCows;
    signal input pubSolutionHash;

    // Приватные входы решения головоломки
    signal input corSolution[n];

    //приватное соленое решение, но не захэшированное!
    signal input corSaltedSoln;

    // Выход
    signal output solnHashOut;

    var numBulls = 0;

    var guess[n] = pubGuess;
    var soln[n] =  corSolution;

    // Считаем число быков
    for (var i=0; i<4; i++) {
        if (guess[i] == soln[i]) {
            numBulls += 1;
            // устанавливаем число совпадений в 0
            guess[i] = 0;
            soln[i] = 0;
        }
    }
    var numCows = 0;

    // Считаем число коров
    var k = 0;
    var j = 0;
    for (j=0; j<4; j++) {
        for (k=0; k<4; k++) {
            if (j != k) {
                if (guess[j] == soln[k]) {
                    if (guess[j] > 0) {
                        numCows += 1;
                        // Устанавливаем число совпадений в 0
                        guess[j] = 0;
                        soln[k] = 0;
                    }
                }
            }
        }
    }

    // Создаем ограничение на число быков
    component bullEqual = IsEqual();
    bullEqual.in[0] <== pubNumBulls;
    bullEqual.in[1] <-- numBulls;
    bullEqual.out === 1;

    // Создаем ограничение на число коров
    component cowEqual = IsEqual();
    cowEqual.in[0] <== pubNumCows;
    cowEqual.in[1] <-- numCows;
    cowEqual.out === 1;

    //Проверяем, что хэш решения совпадает с публичным хэшем через
    // систему ограничений 

    component pedersen = PedersenHashSingle();
    pedersen.in <== corSaltedSoln;

    solnHashOut <== pedersen.encoded;
    // log("HASH = ", solnHashOut);
    pubSolutionHash === pedersen.encoded;
}

component main{public [pubGuess, pubNumBulls, pubNumCows]} = MainLogic(4);
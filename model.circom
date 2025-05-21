pragma circom 2.0.0;

template MLP2() {
    signal input x1;
    signal input x2;

    signal input w1;
    signal input w2;
    signal input w3;
    signal input w4;

    signal input v1;
    signal input v2;

    signal output out;

    // Hidden layer
    signal t1;
    signal t2;
    signal t3;
    signal t4;
    signal h1;
    signal h2;

    t1 <== x1 * w1;
    t2 <== x2 * w2;
    h1 <== t1 + t2;

    t3 <== x1 * w3;
    t4 <== x2 * w4;
    h2 <== t3 + t4;

    // Activation
    signal a1;
    signal a2;
    a1 <== h1 * h1;
    a2 <== h2 * h2;

    // Output layer
    signal o1;
    signal o2;
    signal s;

    o1 <== a1 * v1;
    o2 <== a2 * v2;
    s <== o1 + o2;

    out <== s;
}

component main = MLP2();

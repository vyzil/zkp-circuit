pragma circom 2.0.8;

template convolution_pad(l, z) {
    signal input image[l][l];
    signal input filter[z][z];
    signal input bias;
    signal output conv2dop[l][l];

    var padded_size = l + 2;
    signal padded[padded_size][padded_size];
    signal products[l][l][z][z];

    // Zero padding + 이미지 복사
    for (var i = 0; i < padded_size; i++) {
        for (var j = 0; j < padded_size; j++) {
            var val = 0;
            if (i >= 1 && i <= l && j >= 1 && j <= l) {
                val = image[i - 1][j - 1];
            }
            padded[i][j] <== val;
        }
    }

    // Convolution (곱셈은 signal, 누적은 var)
    for (var i = 0; i < l; i++) {
        for (var j = 0; j < l; j++) {
            var acc = 0;
            for (var ki = 0; ki < z; ki++) {
                for (var kj = 0; kj < z; kj++) {
                    products[i][j][ki][kj] <== padded[i + ki][j + kj] * filter[ki][kj];
                    acc += products[i][j][ki][kj];
                }
            }
            conv2dop[i][j] <== acc + bias;
        }
    }
}

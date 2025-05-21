pragma circom 2.0.8;

include "arrsum.circom";
include "relu.circom";

// General linear layer: input_len → output_len
template linear(input_len, output_len) {
    signal input image[input_len];
    signal input filter[input_len][output_len];
    signal input bias[output_len];
    signal output lin[output_len];

    component linarrsum[output_len];

    for (var i = 0; i < output_len; i++) {
        linarrsum[i] = arrsum(input_len);
        for (var j = 0; j < input_len; j++) {
            linarrsum[i].in[j] <== image[j] * filter[j][i];
        }
        lin[i] <== linarrsum[i].op + bias[i];
    }
}

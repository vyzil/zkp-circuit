pragma circom 2.0.8;

include "convolution.circom";
include "linear_general.circom";
include "argmax.circom";

// Residual Block with 2 convolutions + skip connection
template ResBlock(l, z) {
    signal input image[l][l];
    signal input filter1[z][z];
    signal input filter2[z][z];
    signal input bias1;
    signal input bias2;
    signal output out[l-z+1][l-z+1];

    component conv1 = convolution(l, z);
    component conv2 = convolution(l-z+1, z);

    for (var i = 0; i < l; i++) {
        for (var j = 0; j < l; j++) {
            conv1.image[i][j] <== image[i][j];
        }
    }
    for (var i = 0; i < z; i++) {
        for (var j = 0; j < z; j++) {
            conv1.filter[i][j] <== filter1[i][j];
        }
    }
    conv1.bias <== bias1;

    for (var i = 0; i < l-z+1; i++) {
        for (var j = 0; j < l-z+1; j++) {
            conv2.image[i][j] <== conv1.conv2dop[i][j];
        }
    }
    for (var i = 0; i < z; i++) {
        for (var j = 0; j < z; j++) {
            conv2.filter[i][j] <== filter2[i][j];
        }
    }
    conv2.bias <== bias2;

    for (var i = 0; i < l-2*(z-1); i++) {
        for (var j = 0; j < l-2*(z-1); j++) {
            out[i][j] <== conv2.conv2dop[i][j] + image[i][j];
        }
    }
}

// Main simplified ResNet18-style circuit
template resnet18model() {
    signal input image[224][224];
    signal input conv1_filter[7][7];
    signal input conv1_bias;

    signal input res1_f1[3][3];
    signal input res1_f2[3][3];
    signal input res1_b1;
    signal input res1_b2;

    signal input lin_filter[44944][10];
    signal input lin_bias[10];

    signal output label;

    component conv1 = convolution(224, 7);
    for (var i = 0; i < 224; i++) {
        for (var j = 0; j < 224; j++) {
            conv1.image[i][j] <== image[i][j];
        }
    }
    for (var i = 0; i < 7; i++) {
        for (var j = 0; j < 7; j++) {
            conv1.filter[i][j] <== conv1_filter[i][j];
        }
    }
    conv1.bias <== conv1_bias;

    component res1 = ResBlock(218, 3);
    for (var i = 0; i < 218; i++) {
        for (var j = 0; j < 218; j++) {
            res1.image[i][j] <== conv1.conv2dop[i][j];
        }
    }
    for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
            res1.filter1[i][j] <== res1_f1[i][j];
            res1.filter2[i][j] <== res1_f2[i][j];
        }
    }
    res1.bias1 <== res1_b1;
    res1.bias2 <== res1_b2;

    // Flatten and linear
    component linear1 = linear(44944, 10);
    var count = 0;
    for (var i = 0; i < 212; i++) {
        for (var j = 0; j < 212; j++) {
            linear1.image[count] <== res1.out[i][j];
            count++;
        }
    }
    for (var i = 0; i < 10; i++) {
        for (var j = 0; j < 44944; j++) {
            linear1.filter[j][i] <== lin_filter[j][i];
        }
        linear1.bias[i] <== lin_bias[i];
    }

    component argm = argmax(10);
    for (var i = 0; i < 10; i++) {
        argm.arr[i] <== linear1.lin[i];
    }
    label <== argm.y;
}

component main = resnet18model();

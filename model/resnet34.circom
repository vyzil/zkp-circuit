pragma circom 2.0.8;

include "convolution_pad.circom";
include "linear_general.circom";
include "argmax.circom";

template ResBlockSameSize(l, z) {
    signal input image[l][l];
    signal input filter1[z][z];
    signal input filter2[z][z];
    signal input bias1;
    signal input bias2;
    signal output out[l][l];

    component conv1 = convolution_pad(l, z);
    component conv2 = convolution_pad(l, z);

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

    for (var i = 0; i < l; i++) {
        for (var j = 0; j < l; j++) {
            conv2.image[i][j] <== conv1.conv2dop[i][j];
        }
    }

    for (var i = 0; i < z; i++) {
        for (var j = 0; j < z; j++) {
            conv2.filter[i][j] <== filter2[i][j];
        }
    }

    conv2.bias <== bias2;

    for (var i = 0; i < l; i++) {
        for (var j = 0; j < l; j++) {
            out[i][j] <== conv2.conv2dop[i][j] + image[i][j];
        }
    }
}

template resnet34model() {
    signal input image[224][224];
    signal input conv1_filter[3][3];
    signal input conv1_bias;

    signal input res_f[6][2][3][3];
    signal input res_b[6][2];

    signal input lin_filter[50176][10];
    signal input lin_bias[10];

    signal output label;

    component conv1 = convolution_pad(224, 3);
    for (var i = 0; i < 224; i++) {
        for (var j = 0; j < 224; j++) {
            conv1.image[i][j] <== image[i][j];
        }
    }
    for (var i = 0; i < 3; i++) {
        for (var j = 0; j < 3; j++) {
            conv1.filter[i][j] <== conv1_filter[i][j];
        }
    }
    conv1.bias <== conv1_bias;

    signal inter0[224][224];
    for (var i = 0; i < 224; i++) {
        for (var j = 0; j < 224; j++) {
            inter0[i][j] <== conv1.conv2dop[i][j];
        }
    }

    component resblock[6];
    signal inter[6][224][224];

    for (var b = 0; b < 6; b++) {
        resblock[b] = ResBlockSameSize(224, 3);
        for (var i = 0; i < 224; i++) {
            for (var j = 0; j < 224; j++) {
                if (b == 0) {
                    resblock[b].image[i][j] <== inter0[i][j];
                } else {
                    resblock[b].image[i][j] <== inter[b - 1][i][j];
                }
            }
        }
        for (var i = 0; i < 3; i++) {
            for (var j = 0; j < 3; j++) {
                resblock[b].filter1[i][j] <== res_f[b][0][i][j];
                resblock[b].filter2[i][j] <== res_f[b][1][i][j];
            }
        }
        resblock[b].bias1 <== res_b[b][0];
        resblock[b].bias2 <== res_b[b][1];

        for (var i = 0; i < 224; i++) {
            for (var j = 0; j < 224; j++) {
                inter[b][i][j] <== resblock[b].out[i][j];
            }
        }
    }

    component linear1 = linear(50176, 10);
    var count = 0;
    for (var i = 0; i < 224; i++) {
        for (var j = 0; j < 224; j++) {
            linear1.image[count] <== inter[5][i][j];
            count++;
        }
    }

    for (var i = 0; i < 10; i++) {
        for (var j = 0; j < 50176; j++) {
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

component main = resnet34model();

#include "hal.h"

int main(void) {
    // Configure the first 6 GPIO pins as outputs.
    GPIO_DIR = 0x3F;

    // Drive LED0 on (active low on the Tang Nano 20K board).
    GPIO_OUT = 0x01;

    while (1) {
        // Spin forever so the LED state remains stable.
    }

    return 0;
}

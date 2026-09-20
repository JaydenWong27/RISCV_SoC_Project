#include "hal.h"

int main(void) {
    // Configure the first 6 GPIO pins as outputs.
    GPIO_DIR = 0x3F;

    // Drive LED0 on. Polarity is handled in hardware by wb_gpio's
    // ACTIVE_LOW_MASK, set from soc_top.
    GPIO_OUT = 0x01;

    while (1) {
        // Spin forever so the LED state remains stable.
    }

    return 0;
}

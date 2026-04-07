#include "hal.h"

void uart_putchar(char c) {
    while (UART_TX_BUSY);
    
    UART_TX_DATA = c;
}

void uart_print(const char* s){
    while (*s) {
        uart_putchar(*s);
        s++;
    }
}

int main(void){
    GPIO_DIR = 0x3F;
    for(volatile int i = 0; i < 100000; i++);

    while (1) {
        GPIO_OUT = 0x01;
        for(volatile int i = 0; i < 100000; i++);
        GPIO_OUT = 0x00;
        for(volatile int i = 0; i < 100000; i++);
    }
    return 0;
}

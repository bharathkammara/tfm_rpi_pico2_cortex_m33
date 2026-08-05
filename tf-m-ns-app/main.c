/*
 * Copyright (c) 2023, Arm Limited. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 */

#include <stdio.h>
#include "cmsis_compiler.h"
#include "psa/client.h"
#include "psa/crypto.h"
#include "tfm_plat_ns.h"
#include "Driver_USART.h"
#include "uart_stdout.h"

/**
 * \brief Modified table template for user defined SVC functions
 *
 * \details RTX has a weak definition of osRtxUserSVC, which
 *          is overridden here
 */
#if defined(__ARMCC_VERSION)
#if (__ARMCC_VERSION == 6110004)
/* Workaround needed for a bug in Armclang 6.11, more details at:
 * http://www.keil.com/support/docs/4089.htm
 */
__attribute__((section(".gnu.linkonce")))
#endif

/* Avoids the semihosting issue */
#if (__ARMCC_VERSION >= 6010050)
__asm("  .global __ARM_use_no_argv\n");
#endif
#endif

// Define base address and offsets for GPIO peripherals (check datasheet for exact values)
#define GPIO_BASE 0x40028000 // Example base address
#define GPIO25_STATUS (GPIO_BASE + 0x0c8)
#define GPIO25_CTRL (GPIO_BASE + 0x0cc)

// PAD control
#ifndef PADS_BANK0_BASE
#define PADS_BANK0_BASE 0x40038000
#endif
#define PADS_BANK0_GPIO25_CTRL (PADS_BANK0_BASE + 0x68)

// SIO control
#ifndef SIO_BASE
#define SIO_BASE 0xd0000000
#endif
#define GPIO_OUT_SET (SIO_BASE + 0x018)
#define GPIO_OUT_CLR (SIO_BASE + 0x020)
#define GPIO_OE_SET (SIO_BASE + 0x038)

// Define your LED pin (e.g., GPIO 25)
#define LED_PIN 25

// Delay function (a simple loop)
void delay(volatile uint32_t count) {
    while (count--) {
        __asm volatile ("nop" ::: "memory");
    }
}

/**
 * \brief Platform peripherals and devices initialization.
 *        Can be overridden for platform specific initialization.
 *
 * \return  ARM_DRIVER_OK if the initialization succeeds
 */
__WEAK int32_t tfm_ns_platform_init(void)
{
    stdio_init();

    return ARM_DRIVER_OK;
}

/**
 * \brief main() function
 */
#ifndef __GNUC__
__attribute__((noreturn))
#endif
int main(void)
{
    if (tfm_ns_platform_init() != ARM_DRIVER_OK) {
        /* Avoid undefined behavior if platform init failed */
        while(1);
    }

    printf("Non-Secure system starting...\r\n");
    printf("Hello TF-M world\r\n");

    uint32_t fw_version = psa_framework_version();
    printf("PSA Framework Version = %d.%d\r\n", fw_version >> 8, fw_version & 0xFF);

    uint8_t number;
    printf("Testing psa get random number...\r\n");
    for (int i = 1; i <= 5; i++) {
        if (psa_generate_random(&number, sizeof(number)) == PSA_SUCCESS) {
            printf("%d: psa_generate_random() = %d\r\n", i, number);
        } else {
            printf("psa_generate_random() failed.\r\n");
        }
    }

    printf("End of TF-M example App\r\n");

         /********* GPIO*********/
    *(unsigned int *)(GPIO25_CTRL) = 0x05;
    *(unsigned int *)(PADS_BANK0_GPIO25_CTRL) = 0x34;
    *(unsigned int *)(GPIO_OE_SET) = 0x01U << 25;
	while(1)
    {
        // Turn LED on
        *(unsigned int *)(GPIO_OUT_SET) = 0x01U << 25; 
        delay(1000000000);
        // Turn LED off
        *(unsigned int *)(GPIO_OUT_CLR) = 0x01U << 25; 
    
    } 
}

// EasyREDVIO.h
// Josh Brake
// jbrake@hmc.edu
// 1/10/2020

// This library provides an Arduino-style interface to control I/O 
// devices on a RISC-V FE310 SoC on a SparkFun RED-V board.

// The SparkFun RED-V board maps the FE310 pins to Arduino pin names
// as given in Table 9 of the datasheet:

//  Arduino Pin Name	FE310 GPIO Pin
//	D0					GPIO16
//  D1					GPIO17
//	D2					GPIO18
//	D3					GPIO19
//	D4					GPIO20
//	D5					GPIO21
//	D6					GPIO22
//	D7					GPIO23
//	D8					GPIO0
//	D9					GPIO1
//	D10					GPIO2
//	D11					GPIO3   
//	D12					GPIO4
//	D13					GPIO5 (on-board blue LED)
//	D14	        		Not Connected (NC)
//	D15			        GPIO9
//	D16     			GPIO10
//	D17		        	GPIO11
//	D18		        	GPIO12
//	D19		        	GPIO13

// Mapping of Dx pins to FE310 pins.
// 0:7  are FE310 GPIO16:23
// 8:13 are FE310 GPIO0:5
// 14 is not Connected
// 15:19 are FE310 GPIO9:13

#include <stdint.h>

///////////////////////////////////////////////////////////////////////////////
// Constant Definitions
///////////////////////////////////////////////////////////////////////////////

#define GPIO0_BASE  (0x10012000U)   // GPIO memory-mapped base address

#define GPIO0 ((GPIO*) GPIO0_BASE)  // Set up pointer to struct of type GPIO aligned at the base GPIO0 memory-mapped address

#define LOW 0
#define HIGH 1

#define INPUT 0
#define OUTPUT 1
#define GPIO_IOF0 2

///////////////////////////////////////////////////////////////////////////////
// Bitfield Structs
///////////////////////////////////////////////////////////////////////////////

typedef struct
{
    volatile uint32_t   input_val;      // (GPIO offset 0x00) Pin value
    volatile uint32_t   input_en;       // (GPIO offset 0x04) Pin input enable*
    volatile uint32_t   output_en;      // (GPIO offset 0x08) Pin output enable*
    volatile uint32_t   output_val;     // (GPIO offset 0x0C) Output value
    volatile uint32_t   pue;            // (GPIO offset 0x10) Internal pull-up enable*
    volatile uint32_t   ds;             // (GPIO offset 0x14) Pin drive strength
    volatile uint32_t   rise_ie;        // (GPIO offset 0x18) Rise interrupt enable
    volatile uint32_t   rise_ip;        // (GPIO offset 0x1C) Rise interrupt pending
    volatile uint32_t   fall_ie;        // (GPIO offset 0x20) Fall interrupt enable
    volatile uint32_t   fall_ip;        // (GPIO offset 0x24) Fall interrupt pending
    volatile uint32_t   high_ie;        // (GPIO offset 0x28) High interrupt enable
    volatile uint32_t   high_ip;        // (GPIO offset 0x2C) High interrupt pending
    volatile uint32_t   low_ie;         // (GPIO offset 0x30) Low interrupt enable
    volatile uint32_t   low_ip;         // (GPIO offset 0x34) Low interrupt pending
    volatile uint32_t   iof_en;         // (GPIO offset 0x38) HW-Driven functions enable
    volatile uint32_t   iof_sel;        // (GPIO offset 0x3C) HW-Driven functions enable
    volatile uint32_t   out_xor;        // (GPIO offset 0x40) Output XOR (invert)
    // Registers marked with * are asynchronously reset to 0. All others are synchronously reset to 0.
} GPIO;

// Delay constants
#define COUNTS_PER_MS 898 // Need to update for RED-V

/////////////////////////////////////////////////////////////////////
// Helper functions for converting pin numbers
/////////////////////////////////////////////////////////////////////

// Note -1 in place of D14 which is not connected
int digitalPinMapping[20] = {16,17,18,19,20,21,22,23,0,1,2,3,4,5,-1,9,10,11,12,13};


int pinToGPIO(int pin)
{
    int p;
    if((pin != 14) & (pin < 20))
    {
	    p = digitalPinMapping[pin];
    }
    else p = -1;
    return p;
}

/////////////////////////////////////////////////////////////////////
// GPIO Functions
/////////////////////////////////////////////////////////////////////

void pinMode(int pin, int function)
{
    int pin_offset = pin % 32;
    int gpio_pin = pinToGPIO(pin_offset);

    switch(function) {
        case INPUT:
            GPIO0->input_en     |= (1 << gpio_pin);   // Sets a pin as an input
            break;
        case OUTPUT:
            GPIO0->output_en    |= (1 << gpio_pin);   // Set pin as an output
            GPIO0->iof_en       &= ~(1 << gpio_pin);
            break;
        case GPIO_IOF0:
            GPIO0->iof_sel      &= ~(1 << gpio_pin);
            GPIO0->iof_en       |= (1 << gpio_pin);
    }
}

void digitalWrite(int pin, int val)
{
    int pin_offset = pin % 32;
    int gpio_pin = pinToGPIO(pin_offset);

    if (val) GPIO0->output_val |= (1 << gpio_pin);
    else     GPIO0->output_val &= ~(1 << gpio_pin);
}

int digitalRead(int pin)
{
    int pin_offset = pin % 32;
    int gpio_pin = pinToGPIO(pin_offset);

    return (GPIO0->input_val >> gpio_pin) & 0x1;
}

/////////////////////////////////////////////////////////////////////
// Delay Functions
/////////////////////////////////////////////////////////////////////

void delayLoop(int ms) {
	// declare counter volatile so it isn't optimized away
	// counts_per_ms empirically determined such that delayLoop(100) waits 100 ms
	volatile int i = COUNTS_PER_MS * ms;
	
	while (i--); // count down time
}

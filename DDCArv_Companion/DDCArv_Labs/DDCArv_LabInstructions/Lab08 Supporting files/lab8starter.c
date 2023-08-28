// lab8starter.c
// Josh Brake
// jbrake@hmc.edu
// 1/20/2020

#include "EasyREDVIO_ThingPlus.h"
#include "REDV_SPI.h"

#define GPIO_IOF0 2

/* Enables the SPI peripheral and intializes its clock speed (baud rate), polarity, and phase.
 *    -- clkdivide: (0 to 2^12-1). The SPI clk will be the master clock / 2*(div+1).
 *    -- cpol: clock polarity (0: inactive state is logical 0, 1: inactive state is logical 1).
 *    -- cpha: clock phase (0: data captured on leading edge of clk and changed on next edge,
 *             1: data changed on leading edge of clk and captured on next edge)
 */
void spiInit(uint32_t clkdivide, uint32_t cpol, uint32_t cpha)
{
    // Initially assigning SPI pins (GPIO 2-5 corresponding pins 10-13) to HW I/O function 0
    pinMode(2, GPIO_IOF0); // CS0
    pinMode(3, GPIO_IOF0); // MOSI
    pinMode(4, GPIO_IOF0); // MISO
    pinMode(5, GPIO_IOF0); // SCK

    SPI1->sckdiv.div = clkdivide; // Set the clock divisor

    SPI1->sckmode.pol = cpol; // Set the polarity
    SPI1->sckmode.pha = cpha; // Set the phase
    SPI1->csid.csid = 0x0; // Set the chip ID to 0

    SPI1->csmode.mode = 2; // CS configured as HOLD mode

    SPI1->fmt.proto = 0; // Set SPI protocol to Single. DQ0 (MOSI), DQ1 (MISO)
    SPI1->fmt.endian = 0; // Send MSb first
    SPI1->fmt.dir = 0; // Set SPI direction
    SPI1->fmt.len = 8; // 8 bits per frame
    SPI1->fctrl.en = 0; // Disable SPI flash mode

    SPI1->delay1.interxfr = 0; // No delay in between frames
    SPI1->delay0.cssck = 0; // Delay (in SCK cycles) between CS and SCK start
    SPI1->delay0.sckcs = 0; // Delay (in SCK cycles) between SCK end and CS deassert

    /*  Set up watermarks in order to check whether the values are ready to be
        written or read. It seems you should be able to just read the EMPTY and
        FULL flags for the RX and TX buffers respectively, but this doesn't
        seem to work. I've given up and just use the watermarks now since they 
        work reliably. The RX watermark is set to 0 so that it triggers
        whenever we get a single byte and the TX watermark is set to 0 so that
        it is true whenever we don't have any data in the TX
    */    
    SPI1->ie.rxwm = 1; // Enable rx watermark
    SPI1->ie.txwm = 1; // Enable tx watermark

    SPI1->rxmark.rxmark = 0; // Set rx watermark (in bytes)
    SPI1->txmark.txmark = 1; // Set tx watermark (in bytes)

}

/* Transmits a character (1 byte) over SPI and returns the received character.
 *    -- send: the character to send over SPI
 *    -- return: the character received over SPI */
uint8_t spiSendReceive(uint8_t send)
{
    while(!SPI1->ip.txwm); // Wait until transmit FIFO is ready for new data
    SPI1->txdata.data = send; // Transmit the character over SPI
    while(!SPI1->ip.rxwm);
    return SPI1->rxdata.data; // Return received character
}

/* Transmits 2 characters (2 byte) over SPI and returns the received character.
 *    -- send: the character to send over SPI
 *    -- return: the character received over SPI */
uint16_t spiSendReceive16(uint16_t data)
{
    uint16_t volatile rec = 0;
    uint8_t char1, char2;

    SPI1->csmode.mode = 2; // CS configured as HOLD mode
    char1 = spiSendReceive((data & 0xFF00) >> 8);
    char2 = spiSendReceive(data & 0x00FF);
    rec = (char1 << 8) | char2;
    SPI1->csmode.mode = 0; // CS configured as AUTO mode

    return rec; // Return received character
}

void spiWrite(uint8_t address, uint8_t value)
{
	spiSendReceive16(address << 8 | value);
}

uint8_t spiRead(uint8_t address)
{
    return (uint8_t) spiSendReceive16(address << 8 | (1 << 15));
}

int main(void)
{
    volatile uint8_t debug;
    volatile int16_t x, y, disx, disy;

    spiInit(10, 1, 1); // Initialize SPI pins

    // Setup the LIS3DH
    spiWrite(0x20, 0x77); // highest conversion rate, all axis on
    spiWrite(0x23, 0x88); // block update, and high resolution

    // Check WHO_AM_I register. should return 0x33    
    debug = spiRead(0x0F);
    
    while(1)
    {
        // Collect the X and Y values from the LIS3DH 	
  		x = spiRead(0x28) | (spiRead(0x29) << 8);
		y = spiRead(0x2A) | (spiRead(0x2B) << 8);

        delayLoop(100);
    }
}
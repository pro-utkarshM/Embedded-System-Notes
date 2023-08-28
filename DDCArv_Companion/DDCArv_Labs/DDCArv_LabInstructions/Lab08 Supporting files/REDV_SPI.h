// FE310_SPI.h
// Josh Brake
// jbrake@hmc.edu
// 01/11/2020
// Header for SPI peripheral control of FE310


#ifndef REDV_SPI_H
#define REDV_SPI_H

#include <stdint.h>

///////////////////////////////////////////////////////////////////////////////
// Constant Definitions
///////////////////////////////////////////////////////////////////////////////

#define QSPI0_BASE  (0x10014000U)   // QSPI0 memory-mapped base address
#define SPI1_BASE   (0x10024000U)   // SPI1 memory-mapped base address
#define SPI2_BASE   (0x10034000U)   // SPI2 memory-mapped base address

///////////////////////////////////////////////////////////////////////////////
// SPI Registers
///////////////////////////////////////////////////////////////////////////////

typedef struct
{
    volatile uint32_t   div         :   12; // Divisor for serial clock. div_width bits wide
    volatile uint32_t               :   20;
} sckdiv_bits;

typedef struct
{
    volatile uint32_t   pha         :   1; // Serial clock phase
    volatile uint32_t   pol         :   1; // Serial clock polarity
    volatile uint32_t               :   30;
} sckmode_bits;

typedef struct
{
    volatile uint32_t   csid        :   32; // Chip select ID. log2(cs_width) bits wide.
} csid_bits;

typedef struct
{
    volatile uint32_t   csdef       :   32; // Chip select default value. cs_widthbits wide, reset to all 1s.
} csdef_bits;

typedef struct
{
    volatile uint32_t   mode        :   2; // Chip select mode
    volatile uint32_t               :   30;
} csmode_bits;

typedef struct
{
    volatile uint32_t   cssck       :   8; // CS to SCK Delay
    volatile uint32_t               :   8;
    volatile uint32_t   sckcs       :   8; // SCK to CS Delay
    volatile uint32_t               :   8;
} delay0_bits;

typedef struct
{
    volatile uint32_t   intercs     :   8; // Minimum CS inactive time
    volatile uint32_t               :   8;
    volatile uint32_t   interxfr    :   8; // Maximum interframe delay
    volatile uint32_t               :   8;
} delay1_bits;

typedef struct
{
    volatile uint32_t   proto       :   2; // SPI protocol
    volatile uint32_t   endian      :   1; // SPI endianness
    volatile uint32_t   dir         :   1; // SPI I/O direcation.
    volatile uint32_t               :   12;
    volatile uint32_t   len         :   4; // Number of bits per frame
    volatile uint32_t               :   12;
} fmt_bits;

typedef struct
{
    volatile uint32_t   data        :   8; // Transmit data
    volatile uint32_t               :   23;
    volatile uint32_t   full        :   1; // FIFO full flag
} txdata_bits;

typedef struct
{
    volatile uint32_t   data        :   8; // Received data
    volatile uint32_t               :   23;
    volatile uint32_t   empty       :   1; // FIFO empty flag
} rxdata_bits;

typedef struct
{
    volatile uint32_t   txmark      :   3; // Transmit watermark
    volatile uint32_t               :   29;
} txmark_bits;

typedef struct
{
    volatile uint32_t   rxmark      :   3; // Receive watermark
    volatile uint32_t               :   29;
} rxmark_bits;

typedef struct
{
    volatile uint32_t   en          :   1; // SPI Flash Mode Select
    volatile uint32_t               :   31;
} fctrl_bits;

typedef struct
{
    volatile uint32_t   cmd_en      :   1; // Enable sending of command
    volatile uint32_t   addr_len    :   3; // Number of address bytes (0 to 4)
    volatile uint32_t   pad_cnt     :   4; // Number of dummy cycles
    volatile uint32_t   cmd_proto   :   2; // Protocol for transmitting command
    volatile uint32_t   addr_proto  :   2; // Protocol for transmitting address and padding
    volatile uint32_t   data_proto  :   2; // Protocol for receiving data bytes
    volatile uint32_t               :   2;
    volatile uint32_t   cmd_code    :   8; // Value of command byte
    volatile uint32_t   pad_code    :   8; // First 8 bits to transmit during dummy cycles
} ffmt_bits;

typedef struct
{
    volatile uint32_t   txwm        :   1; // Transmit watermark enable
    volatile uint32_t   rxwm        :   1; // Receive watermark enable
    volatile uint32_t               :   30;
} ie_bits;

typedef struct
{
    volatile uint32_t   txwm        :   1; // Transmit watermark pending
    volatile uint32_t   rxwm        :   1; // Receive watermark pending
    volatile uint32_t               :   30;
} ip_bits;

typedef struct
{
    volatile sckdiv_bits    sckdiv;         // (SPI offset 0x00) Serial clock divisor
    volatile sckmode_bits   sckmode;        // (SPI offset 0x04) Serial clock mode
    volatile uint32_t       Reserved1[2];
    volatile csid_bits      csid;           // (SPI offset 0x10) Chip select ID
    volatile csdef_bits     csdef;          // (SPI offset 0x14) Chip select default
    volatile csmode_bits    csmode;         // (SPI offset 0x18) Chip select mode
    volatile uint32_t       Reserved2[3];
    volatile delay0_bits    delay0;         // (SPI offset 0x28) Delay control 0
    volatile delay1_bits    delay1;         // (SPI offset 0x2C) Delay control 1
    volatile uint32_t       Reserved3[4];
    volatile fmt_bits       fmt;            // (SPI offset 0x40) Frame format
    volatile uint32_t       Reserved4[1];
    volatile txdata_bits    txdata;         // (SPI offset 0x48) Tx FIFO data
    volatile rxdata_bits    rxdata;         // (SPI offset 0x4C) Rx FIFO data
    volatile txmark_bits    txmark;         // (SPI offset 0x50) Tx FIFO watermark
    volatile rxmark_bits    rxmark;         // (SPI offset 0x54) Rx FIFO watermark
    volatile uint32_t       Reserved5[2];
    volatile fctrl_bits     fctrl;          // (SPI offset 0x60) SPI flash interface control*
    volatile ffmt_bits      ffmt;           // (SPI offset 0x64) SPI flash instruction format*
    volatile uint32_t       Reserved6[2];
    volatile ie_bits        ie;             // (SPI offset 0x70) SPI interrupt enable
    volatile ip_bits        ip;             // (SPI offset 0x74) SPI interrupt pending
    // Registers marked * are only present on controllers with the direct-map flash interface.

} SPI;

///////////////////////////////////////////////////////////////////////////////
// SPI
///////////////////////////////////////////////////////////////////////////////


#define QSPI0 ((SPI*) QSPI0_BASE)  // Set up pointer to struct of type SPI aligned at the base QSPI0 memory-mapped address
#define SPI1  ((SPI*) SPI1_BASE)  // Set up pointer to struct of type SPI aligned at the base SPI1 memory-mapped address
#define SPI2  ((SPI*) SPI2_BASE)  // Set up pointer to struct of type SPI aligned at the base SPI2 memory-mapped address

///////////////////////////////////////////////////////////////////////////////
// SPI User Functions
///////////////////////////////////////////////////////////////////////////////

/* Enables the SPI peripheral and intializes its clock speed (baud rate), polarity, and phase.
 *    -- clkdivide: (0 to 2^12-1). The SPI clk will be the master clock / 2*(div+1).
 *    -- cpol: clock polarity (0: inactive state is logical 0, 1: inactive state is logical 1).
 *    -- cpha: clock phase (0: data captured on leading edge of clk and changed on next edge,
 *             1: data changed on leading edge of clk and captured on next edge)
 */
void spiInit(uint32_t clkdivide, uint32_t cpol, uint32_t cpha);

/* Transmits a character (1 byte) over SPI and returns the received character.
 *    -- send: the character to send over SPI
 *    -- return: the character received over SPI 
 */
uint8_t spiSendReceive(uint8_t send);

/* Transmits short (2 bytes) over SPI and returns the received character.
 *    -- send: the character to send over SPI
 *    -- return: the character received over SPI */
uint16_t spiSendReceive16(uint16_t data);

#endif
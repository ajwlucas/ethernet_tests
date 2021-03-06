#include <xs1.h>
#include <print.h>
#include <platform.h>
#include <xscope.h>
#include "mii.h"

on stdcore[ETH_CORE_ID]: mii_interface_t mii = {
		XS1_CLKBLK_1,
		XS1_CLKBLK_2,
		PORT_ETH_RXCLK,
		PORT_ETH_RXER,
		PORT_ETH_RXD,
		PORT_ETH_RXDV,
		PORT_ETH_TXCLK,
		PORT_ETH_TXEN,
		PORT_ETH_TXD
};

on stdcore[ETH_CORE_ID]: clock clk_smi = XS1_CLKBLK_5;

#ifdef PORT_ETH_RST_N
on stdcore[ETH_CORE_ID]: out port p_mii_resetn = PORT_ETH_RST_N;
on stdcore[ETH_CORE_ID]: smi_interface_t smi = { PORT_ETH_MDIO, PORT_ETH_MDC, 0 };
#else
on stdcore[ETH_CORE_ID]: smi_interface_t smi = { PORT_ETH_RST_N_MDIO, PORT_ETH_MDC, 1 };
#endif

void wait(int ticks)
{
	timer tmr;
	unsigned t;
	tmr :> t;
	tmr when timerafter(t + ticks) :> t;
}

#pragma unsafe arrays
void mii_transmit(unsigned int buf[], int length, out buffered port:32 p_mii_txd, int bad_crc)
{
	register const unsigned poly = 0xEDB88320;
	timer tmr;
	unsigned int time;

	int bytes_left;
	unsigned int crc = 0;
	unsigned int word;
	int i=0,k=0;

	int j=0;
	bytes_left = length;

	p_mii_txd <: 0x55555555;
	p_mii_txd <: 0x55555555;
	p_mii_txd <: 0xD5555555;

	word = buf[i];
	p_mii_txd <: word;
	i++;
	crc32(crc, ~word, poly);
	bytes_left -=4;
	j+=4;

	word = buf[i];
	while ((j < (length-3)))
	{
		p_mii_txd <: word;
		i++;
		crc32(crc, word, poly);
		word = buf[i];
		j += 4;
	}
	bytes_left = length - j;
    
    if (bad_crc) crc |= 0x12345;

	switch (bytes_left)
	{
		case 0:
		crc32(crc, 0, poly);
		crc = ~crc;
		p_mii_txd <: crc;
		break;
		case 1:
		crc8shr(crc, word, poly);
		partout(p_mii_txd, 8, word);
		crc32(crc, 0, poly);
		crc = ~crc;
		p_mii_txd <: crc;
		break;
		case 2:
		partout(p_mii_txd, 16, word);
		word = crc8shr(crc, word, poly);
		crc8shr(crc, word, poly);
		crc32(crc, 0, poly);
		crc = ~crc;
		p_mii_txd <: crc;
		break;
		case 3:
		partout(p_mii_txd, 24, word);
		word = crc8shr(crc, word, poly);
		word = crc8shr(crc, word, poly);
		crc8shr(crc, word, poly);
		crc32(crc, 0, poly);
		crc = ~crc;
		p_mii_txd <: crc;
		break;
	}
		
		tmr :> time;
		time+=196;
		tmr when timerafter(time) :> int tmp;
}

int create_packet(unsigned char dest[], unsigned char source[], unsigned char etype[], unsigned int buf[], int num_bytes)
{
    for (int i=0; i < 6; i++)
    {
        (buf, unsigned char[])[i] = dest[i]; // Dest MAC
        (buf, unsigned char[])[i+6] = source[i]; // Source MAC
    }
    
    // Ethertype
    (buf, unsigned char[])[12] = etype[0];
    (buf, unsigned char[])[13] = etype[1];
    
    (buf, unsigned char[])[14] = 0;
    (buf, unsigned char[])[15] = 0;
    
    buf[4] = 0;
    
    for (int i=20; i < num_bytes; i++)
    {
        (buf, unsigned char[])[i] = i;
    }

    return 0;
}

void set_seq_num(unsigned int buf[], int n)
{
    buf[4] = n;
}

int test(out buffered port:32 p_mii_txd)
{
    unsigned int buf[100];
    int n = 0;
    unsigned char dest[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
    unsigned char src[] = {0x00, 0x12, 0x34, 0x56, 0x78, 0x90};
    unsigned char etype[] = {0xF0, 0xF0};
    
    create_packet(dest, src, etype, buf, 100);
    set_seq_num(buf, 0);
    
    printstrln(""); // Flush the output. Bug in XScope it seems.
    
    printstrln("TX 1: Good CRC");
    mii_transmit(buf, 100, p_mii_txd, 0);
    n++;
    set_seq_num(buf, n);
    printstrln("TX 2: Bad CRC");
    mii_transmit(buf, 100, p_mii_txd, 1);
    n++;
    set_seq_num(buf, n);
    printstrln("TX 3: Good CRC");
    mii_transmit(buf, 100, p_mii_txd, 0);
    n++;
    set_seq_num(buf, n);
    printstrln("TX 4: Bad CRC");
    mii_transmit(buf, 100, p_mii_txd, 1);
    n++;
    set_seq_num(buf, n);
    printstrln("TX 5: Good CRC");
    mii_transmit(buf, 100, p_mii_txd, 0);

    printstrln("Finish");

    return 0;
}

int main(void)
{
    par
    {
        on stdcore[ETH_CORE_ID]:
        {
        #if (XSCOPE_ENABLED)
            xscope_register(0, 0, "", 0, "");
            xscope_config_io(XSCOPE_IO_BASIC);
        #endif
            phy_init(clk_smi,
            #ifdef PORT_ETH_RST_N
            p_mii_resetn
            #else
            null
            #endif
            ,smi, mii);
            
            wait(600000000);
            
            test(mii.p_mii_txd);
        }
    }

    return 0;
}
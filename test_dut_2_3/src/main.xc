#include <xs1.h>
#include <print.h>
#include <platform.h>
#include <xscope.h>
#include <stdlib.h>
#include "ethernet_server.h"
#include "ethernet_rx_client.h"
#include "ethernet_tx_client.h"
#include "eth_phy.h"
#include "getmac.h"
#include "check_frame.h"

#define RUNTEST(name, x) printstrln("********** " name " **********"); \
							  printstrln( (x) ? "PASSED\n******" : "FAILED\n******" )


#define ERROR printstr("ERROR: "__FILE__ ":"); printintln(__LINE__);

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

// OTP Ports
on stdcore[ETH_CORE_ID]: port otp_data = XS1_PORT_32B; 		// OTP_DATA_PORT
on stdcore[ETH_CORE_ID]: out port otp_addr = XS1_PORT_16C;	// OTP_ADDR_PORT
on stdcore[ETH_CORE_ID]: port otp_ctrl = XS1_PORT_16D;		// OTP_CTRL_PORT

void wait(int ticks)
{
	timer tmr;
	unsigned t;
	tmr :> t;
	tmr when timerafter(t + ticks) :> t;
}

void print_mac_addr(chanend tx)
{
	char macaddr[6];
	mac_get_macaddr(tx, macaddr);
	printstr("MAC Address: ");
	for (int i = 0; i < 6; i++){
		printhex(macaddr[i]);
		if (i < 5)
			printstr(":");
	}
	printstrln("");
}

int init(chanend rx [], chanend tx[], int links)
{
	printstr("Connecting...\n");
	// wait(600000000);
	printstr("Ethernet initialised\n");

	print_mac_addr(tx[0]);
    
	for (int i = 0; i < links; ++i)
    {
        mac_set_custom_filter(rx[i], 1);
	}

	printstr("Filter configured\n");
	return 1;
}


unsigned short get_ethertype(unsigned char buf[])
{
	return ((unsigned short)buf[12]) << 8 | buf[13];
}

int dummy_rx(chanend rx)
{
	unsigned char rxbuffer[1600];
	while (1)
	{
		unsigned int src_port;
		unsigned int nbytes;
        unsigned short etype;

		mac_rx(rx, rxbuffer, nbytes, src_port);

		printstr("RX "); printint(nbytes); printstrln(" bytes");
	}

	return 1;

}

int len_receiver(chanend rx, int min_len, int max_len)
{
	unsigned char rxbuffer[1600];
    timer t;
    unsigned timeout;
    int expect_no_more = 0;

	while (1)
	{
		unsigned int src_port;
		unsigned int nbytes;
        unsigned short etype;

        select
        {
			case mac_rx(rx, rxbuffer, nbytes, src_port):
			{
				break;
			}
			// This timeout needs to be greater than the IFG+RX time of the next potential packet
			case expect_no_more => t when timerafter(timeout+500000) :> void :
			{
				printstrln("timeout");
				// Timed out before receiving another packet - PASS
				return 1;
			}

		}
		

		if (nbytes > max_len)
		{
			printstr("Error received ");
			printint(nbytes);
			printstr(" bytes, expected < ");
			printintln(max_len);
			return 0;
		}
        
        etype = get_ethertype(rxbuffer);
		if (etype != 0xF0F0)
		{
			printstr("Error in ethertype. Received ");
			printhex(etype);
			printstr(" expected ");
			printhexln(0xF0F0);
			return 0;
		}

        
        if (nbytes == max_len)
        {
        	if (!expect_no_more)
        	{
    			// Run once more to see if this is the maximum sized packet we can receive
    			expect_no_more = 1;
    			t:> timeout;
    		}
        }
        
	}

	return 1;
}

int mac_rx_untagged_len_test(chanend tx, chanend rx)
{
	return len_receiver(rx, 1514, 1518);
	// return dummy_rx(rx);
}

int mac_rx_runt_test(chanend tx, chanend rx)
{
	return 0;// receiver(rx, 5, 64, 0);
}

void runtests(chanend tx[], chanend rx[], int links)
{
	RUNTEST("init", init(rx, tx, links));
#ifdef TEST_3A
	RUNTEST("Test #2.3a - Reception of oversized frames (Part A = untagged)", mac_rx_untagged_len_test(tx[0], rx[0]));
#endif
#ifdef TEST_3B
	RUNTEST("Test #2.2b - Reception of fragments and runts (Part B = runts)", mac_rx_runt_test(tx[0], rx[0]));
#endif
	printstrln("Complete");
	_Exit(0);
}

int main()
{
    chan rx[1], tx[1];

    par
    {
        on stdcore[ETH_CORE_ID]:
        {
            int mac_address[2];
        #if (XSCOPE_ENABLED)
            xscope_register(0, 0, "", 0, "");
            xscope_config_io(XSCOPE_IO_BASIC);
        #endif
            ethernet_getmac_otp(otp_data, otp_addr, otp_ctrl, (mac_address, char[]));
            phy_init(clk_smi,
        #ifdef PORT_ETH_RST_N
            p_mii_resetn,
        #else
            null,
        #endif
            smi, mii);
            ethernet_server(mii, mac_address, rx, 1, tx, 1, null, null);

        }

        on stdcore[ETH_CORE_ID]: runtests(tx, rx, 1);
}

return 0;
}

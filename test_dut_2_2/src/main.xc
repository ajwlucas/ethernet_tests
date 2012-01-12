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
							  printstrln( (x) ? "PASSED" : "FAILED" )


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


int receiver(chanend rx)
{
	unsigned char rxbuffer[1600];
    int rx_frame_num = 0;
    int expected_seq_num = 0;

	while (1)
	{
		unsigned int src_port;
		unsigned int nbytes;
        unsigned short etype;
		mac_rx(rx, rxbuffer, nbytes, src_port);
        
        rx_frame_num++;

		if (nbytes != 100)
		{
			printstr("Error received ");
			printint(nbytes);
			printstr(" bytes, expected ");
			printintln(100);
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

		if (!check_test_frame(nbytes, expected_seq_num, rxbuffer))
		{
			return 0;
		}
        
        if (rx_frame_num == 3) return 1;
        
        expected_seq_num += 2;
        
        
	}

	return 1;
}

int mac_rx_bad_crc_test(chanend tx, chanend rx)
{
	return receiver(rx);
}

void runtests(chanend tx[], chanend rx[], int links)
{
	RUNTEST("init", init(rx, tx, links));
	RUNTEST("Test #2.1 - Reception of frames with FCS errors", mac_rx_bad_crc_test(tx[0], rx[0]));
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

#include <xs1.h>
#include <assert.h>
#include "mii.h"
#include "smi.h"
#include "eth_phy.h"

// Timing tuning constants
#define PAD_DELAY_RECEIVE    0
#define PAD_DELAY_TRANSMIT   0
#define CLK_DELAY_RECEIVE    0
#define CLK_DELAY_TRANSMIT   7  // Note: used to be 2 (improved simulator?)
// After-init delay (used at the end of mii_init)
#define PHY_INIT_DELAY 10000000

#define ETHERNET_IFS_AS_REF_CLOCK_COUNT  (96)   // 12 bytes

#ifdef ETH_REF_CLOCK
extern clock ETH_REF_CLOCK;
#endif

void mii_init(mii_interface_t &m)
{
#ifndef SIMULATION
	timer tmr;
	unsigned t;
#endif
	set_port_use_on(m.p_mii_rxclk);
    m.p_mii_rxclk :> int x;
	set_port_use_on(m.p_mii_rxd);
	set_port_use_on(m.p_mii_rxdv);
	set_port_use_on(m.p_mii_rxer);
#ifdef ETH_REF_CLOCK
	set_port_clock(m.p_mii_rxclk, ETH_REF_CLOCK);
	set_port_clock(m.p_mii_rxd, ETH_REF_CLOCK);
	set_port_clock(m.p_mii_rxdv, ETH_REF_CLOCK);
#endif

	set_pad_delay(m.p_mii_rxclk, PAD_DELAY_RECEIVE);

	set_port_strobed(m.p_mii_rxd);
	set_port_slave(m.p_mii_rxd);

	set_clock_on(m.clk_mii_rx);
	set_clock_src(m.clk_mii_rx, m.p_mii_rxclk);
	set_clock_ready_src(m.clk_mii_rx, m.p_mii_rxdv);
	set_port_clock(m.p_mii_rxd, m.clk_mii_rx);
	set_port_clock(m.p_mii_rxdv, m.clk_mii_rx);

	set_clock_rise_delay(m.clk_mii_rx, CLK_DELAY_RECEIVE);

	start_clock(m.clk_mii_rx);

	clearbuf(m.p_mii_rxd);

	set_port_use_on(m.p_mii_txclk);
	set_port_use_on(m.p_mii_txd);
	set_port_use_on(m.p_mii_txen);
	//  set_port_use_on(m.p_mii_txer);
#ifdef ETH_REF_CLOCK
	set_port_clock(m.p_mii_txclk, ETH_REF_CLOCK);
	set_port_clock(m.p_mii_txd, ETH_REF_CLOCK);
	set_port_clock(m.p_mii_txen, ETH_REF_CLOCK);
#endif

	set_pad_delay(m.p_mii_txclk, PAD_DELAY_TRANSMIT);

	m.p_mii_txd <: 0;
	m.p_mii_txen <: 0;
	//  m.p_mii_txer <: 0;
	sync(m.p_mii_txd);
	sync(m.p_mii_txen);
	//  sync(m.p_mii_txer);

	set_port_strobed(m.p_mii_txd);
	set_port_master(m.p_mii_txd);
	clearbuf(m.p_mii_txd);

	set_port_ready_src(m.p_mii_txen, m.p_mii_txd);
	set_port_mode_ready(m.p_mii_txen);

	set_clock_on(m.clk_mii_tx);
	set_clock_src(m.clk_mii_tx, m.p_mii_txclk);
	set_port_clock(m.p_mii_txd, m.clk_mii_tx);
	set_port_clock(m.p_mii_txen, m.clk_mii_tx);

	set_clock_fall_delay(m.clk_mii_tx, CLK_DELAY_TRANSMIT);

	start_clock(m.clk_mii_tx);

	clearbuf(m.p_mii_txd);

#ifndef SIMULATION
	tmr :> t;
	tmr when timerafter(t + PHY_INIT_DELAY) :> t;
#endif

}

void phy_init(clock clk_smi, out port ?p_mii_resetn, smi_interface_t &smi0, mii_interface_t &mii0)
{
    int setup = 0;
    smi_init(clk_smi, p_mii_resetn, smi0);
    smi_reset(p_mii_resetn, smi0);
    mii_init(mii0);
    setup = eth_phy_config(1, smi0);
    assert(!setup);
}
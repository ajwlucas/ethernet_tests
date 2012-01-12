#include <xs1.h>
#include <xccompat.h>
#include "smi.h"

#ifdef __XC__
/** Structure containing resources required for the MII ethernet interface.
 *
 *  This structure contains resources required to make up an MII interface. 
 *  It consists of 7 ports and 2 clock blocks.
 *
 *  The clock blocks can be any available clock blocks and will be clocked of 
 *  incoming rx/tx clock pins.
 *
 *  \sa ethernet_server()
 **/
typedef struct mii_interface_t {
  clock clk_mii_rx;            /**< MII RX Clock Block **/
  clock clk_mii_tx;            /**< MII TX Clock Block **/

  in port p_mii_rxclk;         /**< MII RX clock wire */
  in port p_mii_rxer;          /**< MII RX error wire */
  in buffered port:32 p_mii_rxd; /**< MII RX data wire */
  in port p_mii_rxdv;          /**< MII RX data valid wire */


  in port p_mii_txclk;       /**< MII TX clock wire */
  out port p_mii_txen;       /**< MII TX enable wire */
  out buffered port:32 p_mii_txd; /**< MII TX data wire */
} mii_interface_t;

void mii_init(REFERENCE_PARAM(mii_interface_t, m));
void phy_init(clock clk_smi, out port ?p_mii_resetn, smi_interface_t &smi0, mii_interface_t &mii0);
#endif
/*
 * Copyright (C) 2013-2017 ETH Zurich, University of Bologna
 * All rights reserved.
 *
 * This code is under development and not yet released to the public.
 * Until it is released, the code is under the copyright of ETH Zurich and
 * the University of Bologna, and may contain confidential and/or unpublished 
 * work. Any reuse/redistribution is strictly forbidden without written
 * permission from ETH Zurich.
 *
 * Bug fixes and contributions will eventually be released under the
 * SolderPad open hardware license in the context of the PULP platform
 * (http://www.pulp-platform.org), under the copyright of ETH Zurich and the
 * University of Bologna.
 */


import hci_package::*;

module cluster_interconnect_wrap
#(
  parameter NB_CORES        = 12,
  parameter HWPE_PRESENT    = 1,
  parameter NB_HWPE_PORTS   = 9,
  parameter NB_DMAS         = 4,
  parameter NB_MPERIPHS     = 1,
  parameter NB_TCDM_BANKS   = 16,
  parameter NB_SPERIPHS     = 10, //differ

  parameter DATA_WIDTH      = 32,
  parameter ADDR_WIDTH      = 32,
  parameter BE_WIDTH        = DATA_WIDTH/8,
  parameter logic [ADDR_WIDTH-1:0] ClusterBaseAddr        = 'h50000000,
  parameter logic [ADDR_WIDTH-1:0] ClusterPeripheralsOffs = 'h00200000,
  parameter logic [ADDR_WIDTH-1:0] ClusterExternalOffs    = 'h00400000,

  //TCDM PARAMETERS
  parameter TEST_SET_BIT    = 20,
  parameter ADDR_MEM_WIDTH  = 11,
  parameter LOG_CLUSTER     = 5,
  parameter PE_ROUTING_LSB  = 10,
  parameter PE_ROUTING_MSB  = PE_ROUTING_LSB+$clog2(NB_SPERIPHS)-1, //differ
  parameter CLUSTER_ALIAS   = 1,
  parameter CLUSTER_ALIAS_BASE = 12'h000,

  parameter USE_HETEROGENEOUS_INTERCONNECT = 1
)
(
  input logic                          clk_i,
  input logic                          rst_ni,
  input logic                    [5:0] cluster_id_i,
  hci_core_intf.target                 core_tcdm_slave   [0             : NB_CORES-1     ],
  hci_core_intf.target                 hwpe_tcdm_slave   [0             : 0              ],
  XBAR_PERIPH_BUS.Slave                core_periph_slave [NB_CORES-1    : 0              ],
  hci_core_intf.target                 ext_slave         [0             : 3              ],
  hci_core_intf.target                 dma_slave         [0             : NB_DMAS-1      ],
  XBAR_TCDM_BUS.Slave                  mperiph_slave     [NB_MPERIPHS-1 : 0              ],
  hci_core_intf.initiator              tcdm_sram_master  [0             : NB_TCDM_BANKS-1],
  XBAR_PERIPH_BUS.Master               speriph_master    [NB_SPERIPHS-1 : 0              ],
  input hci_interconnect_ctrl_t        hci_ctrl_i,
  input logic [1:0]                    TCDM_arb_policy_i
);

  localparam TCDM_ID_WIDTH = NB_CORES+NB_DMAS+4+NB_HWPE_PORTS;


  //-********************************************************
  //-*********** HETEROGENEOUS INTERCONNECT TO TCDM *********
  //-********************************************************
  // Wraps the Logarithmic Interconnect + a HWPE Interconnect
  generate
    if( USE_HETEROGENEOUS_INTERCONNECT || !HWPE_PRESENT ) begin : hci_gen

      hci_interconnect #(
        .N_HWPE ( HWPE_PRESENT             ),
        .N_CORE ( NB_CORES                 ),
        .N_DMA  ( NB_DMAS                  ),
        .N_EXT  ( 4                        ),
        .N_MEM  ( NB_TCDM_BANKS            ),
        .IW     ( TCDM_ID_WIDTH            ),
        .TS_BIT ( TEST_SET_BIT             )
      ) i_hci_interconnect (
        .clk_i  ( clk_i               ),
        .rst_ni ( rst_ni              ),
        .clear_i( 1'b0                ),
        .ctrl_i ( hci_ctrl_i          ),
        .cores  ( core_tcdm_slave     ),
        .hwpe   ( hwpe_tcdm_slave [0] ),
        .dma    ( dma_slave           ),
        .ext    ( ext_slave           ),
        .mems   ( tcdm_sram_master    )
      );

    end else begin : no_hci_gen

      hci_core_intf #(
        .DW ( 32 ),
        .AW ( 32 )
      ) core_hwpe_tcdm_slave [0:NB_CORES+NB_HWPE_PORTS-1] (
        .clk ( clk_i )
      );

      hci_core_intf #(
        .DW ( NB_HWPE_PORTS*32 ),
        .AW ( 32               )
      ) null_hwpe_tcdm_slave (
        .clk ( clk_i )
      );

      hci_core_split #(
        .DW          ( NB_HWPE_PORTS*32 ),
        .NB_OUT_CHAN ( NB_HWPE_PORTS    )
      ) i_hwpe_tcdm_splitter (
        .clk_i       ( clk_i                                                   ),
        .rst_ni      ( rst_ni                                                  ),
        .clear_i     ( clear_i                                                 ),
        .tcdm_slave  ( hwpe_tcdm_slave[0]                                      ),
        .tcdm_master ( core_hwpe_tcdm_slave[NB_CORES:NB_CORES+NB_HWPE_PORTS-1] )
      );
  
      for(genvar ii=0; ii<NB_CORES; ii++) begin : core_tcdm_slave_gen
        hci_core_assign i_assign (
          .tcdm_slave  ( core_tcdm_slave      [ii] ),
          .tcdm_master ( core_hwpe_tcdm_slave [ii] )
        );
      end

      hci_interconnect #(
        .N_HWPE ( 0                      ),
        .N_CORE ( NB_CORES+NB_HWPE_PORTS ),
        .N_DMA  ( NB_DMAS                ),
        .N_EXT  ( 4                      ),
        .N_MEM  ( NB_TCDM_BANKS          ),
        .IW     ( TCDM_ID_WIDTH          ),
        .AWC    ( ADDR_WIDTH             ),
        .DW_LIC ( DATA_WIDTH             ),
        .DW_SIC ( NB_HWPE_PORTS*32       ),
        .TS_BIT ( TEST_SET_BIT           ),
        .AWH    ( 32                     ),
        .DWH    ( 288                    ),
        .OWH    ( 1                      ),
        .AWM    ( ADDR_MEM_WIDTH+2       )
      ) i_hci_interconnect (
        .clk_i  ( clk_i                ),
        .rst_ni ( rst_ni               ),
        .clear_i( 1'b0                 ),
        .ctrl_i ( hci_ctrl_i           ),
        .cores  ( core_hwpe_tcdm_slave ),
        .hwpe   ( null_hwpe_tcdm_slave ),
        .dma    ( dma_slave            ),
        .ext    ( ext_slave            ),
        .mems   ( tcdm_sram_master     )
      );

    end
  endgenerate

  //********************************************************
  //******* LOGARITHMIC INTERCONNECT TO PERIPHERALS ********
  //********************************************************
  xbar_pe_wrap
  #(
    .NB_CORES               ( NB_CORES               ),
    .NB_MPERIPHS            ( NB_MPERIPHS            ),
    .NB_SPERIPHS            ( NB_SPERIPHS            ),
    .ADDR_WIDTH             ( ADDR_WIDTH             ),
    .DATA_WIDTH             ( DATA_WIDTH             ),
    .BE_WIDTH               ( BE_WIDTH               ),
    .PE_ROUTING_LSB         ( PE_ROUTING_LSB         ),
    .PE_ROUTING_MSB         ( PE_ROUTING_MSB         ),
    .CLUSTER_ALIAS          ( CLUSTER_ALIAS          ),
    .CLUSTER_ALIAS_BASE     ( CLUSTER_ALIAS_BASE     ),
    .ClusterBaseAddr        ( ClusterBaseAddr        ),
    .ClusterPeripheralsOffs ( ClusterPeripheralsOffs ),
    .ClusterExternalOffs    ( ClusterExternalOffs    )
   ) xbar_pe_inst      (
     .clk_i            ( clk_i            ),
     .rst_ni           ( rst_ni           ),
     .cluster_id_i     ( cluster_id_i     ),
     .core_periph_slave( core_periph_slave),
     .speriph_master   ( speriph_master   ),
     .mperiph_slave    ( mperiph_slave    )
   );


endmodule

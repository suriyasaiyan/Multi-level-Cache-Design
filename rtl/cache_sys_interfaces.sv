import axi_pkg::*;

interface axi4_lite_interface #(
   parameter integer C_AXI_ADDR_WIDTH = 32,
   parameter integer C_AXI_DATA_WIDTH = 32
)(
    
   // System Signals
    wire aclk,
    wire aclken,
    wire aresetn,

   // Master Interface Write Address Ports
    wire [C_AXI_ADDR_WIDTH-1:0]   m_axi_awaddr,
    wire                          m_axi_awvalid,
    wire                          m_axi_awready,

   // Master Interface Write Data Ports
    wire [C_AXI_DATA_WIDTH-1:0]   m_axi_wdata,
    wire [C_AXI_DATA_WIDTH/8-1:0] m_axi_wstrb,
    wire                          m_axi_wvalid,
    wire                          m_axi_wready,

   // Master Interface Write Response Ports
    wire [1:0]                    m_axi_bresp,
    wire                          m_axi_bvalid,
    wire                          m_axi_bready,

   // Master Interface Read Address Ports
    wire [C_AXI_ADDR_WIDTH-1:0]   m_axi_araddr,
    wire                          m_axi_arvalid,
    wire                          m_axi_arready,

   // Master Interface Read Data Ports
    wire [C_AXI_DATA_WIDTH-1:0]   m_axi_rdata,
    wire [1:0]                    m_axi_rresp,
    wire                          m_axi_rvalid,
    wire                          m_axi_rready,

   // Slave Interface Write Address Ports
    wire [C_AXI_ADDR_WIDTH-1:0]   s_axi_awaddr,
    wire                          s_axi_awvalid,
    wire                          s_axi_awready,

   // Slave Interface Write Data Ports
    wire [C_AXI_DATA_WIDTH-1:0]   s_axi_wdata,  
    wire [C_AXI_DATA_WIDTH/8-1:0] s_axi_wstrb,
    wire                          s_axi_wvalid,
    wire                          s_axi_wready,

   // Slave Interface Write Response Ports
    wire [1:0]                    s_axi_bresp,
    wire                          s_axi_bvalid,
    wire                          s_axi_bready,

   // Slave Interface Read Address Ports
    wire [C_AXI_ADDR_WIDTH-1:0]   s_axi_araddr,
    wire                          s_axi_arvalid,
    wire                          s_axi_arready,

   // Slave Interface Read Response Ports
    wire [C_AXI_DATA_WIDTH-1:0]   s_axi_rdata,
    wire [1:0]                    s_axi_rresp,
    wire                          s_axi_rvalid,
    wire                          s_axi_rready
);
    // master Modport
    modport master(
        output m_axi_awaddr, m_axi_awvalid, m_axi_wdata, m_axi_wstrb, 
        m_axi_wvalid, m_axi_bready, m_axi_araddr, m_axi_arvalid, m_axi_rready,

        input aclk, aresetn, m_axi_awready, m_axi_wready, m_axi_bresp, 
        m_axi_bvalid, m_axi_arready, m_axi_rdata, m_axi_rresp, m_axi_rvalid
    );

    // Slave Modport
    modport slave(
        input s_axi_awaddr, s_axi_awvalid, s_axi_wdata, s_axi_wstrb, s_axi_wvalid, 
        s_axi_bready, s_axi_araddr, s_axi_arvalid, s_axi_rready,

        output aclk, aresetn, s_axi_awready, s_axi_wready, s_axi_bresp, s_axi_bvalid, 
        s_axi_arready, s_axi_rdata, s_axi_rresp, s_axi_rvalid
    );
endinterface


interface axi4_main_interface #(
   parameter C_AXI_PROTOCOL                      = 0,
   parameter C_AXI_INTERFACE_MODE                = 1,  //master, slave and bypass
   parameter integer C_AXI_ADDR_WIDTH            = 32,
   parameter integer C_AXI_WDATA_WIDTH           = 32,
   parameter integer C_AXI_RDATA_WIDTH           = 32,
)(
   // System Signals
   input wire aclk,
   input wire aclken,
   input wire aresetn,

   // Slave Interface Write Address Ports
   input  wire [C_AXI_ADDR_WIDTH-1:0]                              s_axi_awaddr,
   input  wire [((C_AXI_PROTOCOL == 1) ? 4 : 8)-1:0]               s_axi_awlen,
   input  wire [3-1:0]                                             s_axi_awsize,
   input  wire [2-1:0]                                             s_axi_awburst,
   input  wire [((C_AXI_PROTOCOL == 1) ? 2 : 1)-1:0]               s_axi_awlock,
   input  wire [4-1:0]                                             s_axi_awcache,
   input  wire [3-1:0]                                             s_axi_awprot,
   input  wire [4-1:0]                                             s_axi_awregion,
   input  wire [4-1:0]                                             s_axi_awqos,
   input  wire                                                     s_axi_awvalid,
   output wire                                                     s_axi_awready,

   // Slave Interface Write Data Ports
   input  wire [C_AXI_WDATA_WIDTH-1:0]                             s_axi_wdata,
   input  wire [C_AXI_WDATA_WIDTH/8==0 ?0:C_AXI_WDATA_WIDTH/8-1:0] s_axi_wstrb,
   input  wire                                                     s_axi_wlast,
   input  wire                                                     s_axi_wvalid,
   output wire                                                     s_axi_wready,

   // Slave Interface Write Response Ports
   output wire [2-1:0]                                             s_axi_bresp,
   output wire                                                     s_axi_bvalid,
   input  wire                                                     s_axi_bready,

   // Slave Interface Read Address Ports
   input  wire [C_AXI_ADDR_WIDTH-1:0]                              s_axi_araddr,
   input  wire [((C_AXI_PROTOCOL == 1) ? 4 : 8)-1:0]               s_axi_arlen,
   input  wire [3-1:0]                                             s_axi_arsize,
   input  wire [2-1:0]                                             s_axi_arburst,
   input  wire [((C_AXI_PROTOCOL == 1) ? 2 : 1)-1:0]               s_axi_arlock,
   input  wire [4-1:0]                                             s_axi_arcache,
   input  wire [3-1:0]                                             s_axi_arprot,
   input  wire [4-1:0]                                             s_axi_arregion,
   input  wire [4-1:0]                                             s_axi_arqos,
   input  wire                                                     s_axi_arvalid,
   output wire                                                     s_axi_arready,

   // Slave Interface Read Data Ports
   output wire [C_AXI_RDATA_WIDTH-1:0]                             s_axi_rdata,
   output wire [2-1:0]                                             s_axi_rresp,
   output wire                                                     s_axi_rlast,
   output wire                                                     s_axi_rvalid,
   input  wire                                                     s_axi_rready,
   
   // Master Interface Write Address Port
   output wire [C_AXI_ADDR_WIDTH-1:0]                              m_axi_awaddr,
   output wire [((C_AXI_PROTOCOL == 1) ? 4 : 8)-1:0]               m_axi_awlen,
   output wire [3-1:0]                                             m_axi_awsize,
   output wire [2-1:0]                                             m_axi_awburst,
   output wire [((C_AXI_PROTOCOL == 1) ? 2 : 1)-1:0]               m_axi_awlock,
   output wire [4-1:0]                                             m_axi_awcache,
   output wire [3-1:0]                                             m_axi_awprot,
   output wire [4-1:0]                                             m_axi_awregion,
   output wire [4-1:0]                                             m_axi_awqos,
   output wire                                                     m_axi_awvalid,
   input  wire                                                     m_axi_awready,
   
   // Master Interface Write Data Ports
   output wire [C_AXI_WDATA_WIDTH-1:0]                             m_axi_wdata,
   output wire [C_AXI_WDATA_WIDTH/8 ==0?0:C_AXI_WDATA_WIDTH/8-1:0] m_axi_wstrb,
   output wire                                                     m_axi_wlast,
   output wire                                                     m_axi_wvalid,
   input  wire                                                     m_axi_wready,
   
   // Master Interface Write Response Ports
   input  wire [2-1:0]                                             m_axi_bresp,
   input  wire                                                     m_axi_bvalid,
   output wire                                                     m_axi_bready,
   
   // Master Interface Read Address Port
   output wire [ C_AXI_ADDR_WIDTH-1:0]                             m_axi_araddr,
   output wire [((C_AXI_PROTOCOL == 1) ? 4 : 8)-1:0]               m_axi_arlen,
   output wire [3-1:0]                                             m_axi_arsize,
   output wire [2-1:0]                                             m_axi_arburst,
   output wire [((C_AXI_PROTOCOL == 1) ? 2 : 1)-1:0]               m_axi_arlock,
   output wire [4-1:0]                                             m_axi_arcache,
   output wire [3-1:0]                                             m_axi_arprot,
   output wire [4-1:0]                                             m_axi_arregion,
   output wire [4-1:0]                                             m_axi_arqos,
   output wire                                                     m_axi_arvalid,
   input  wire                                                     m_axi_arready,
   
   // Master Interface Read Data Ports
   input  wire [C_AXI_RDATA_WIDTH-1:0]                             m_axi_rdata,
   input  wire [2-1:0]                                             m_axi_rresp,
   input  wire                                                     m_axi_rlast,
   input  wire                                                     m_axi_rvalid,
   output wire                                                     m_axi_rready
  );
endinterface 
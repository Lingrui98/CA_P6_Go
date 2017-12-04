/*----------------------------------------------------------------*
// Filename      :  mycpu_top.v
// Description   :  5 pipelined CPU top
// Author        :  Gou Lingrui & Wu Jiahao
// Created Time  :  2017-12-04 15:24:31
//----------------------------------------------------------------*/
`define SIMU_DEBUG
`timescale 10ns / 1ns

module mycpu_top(
    input         clk,
    input         resetn, 
    input  [ 5:0] int_i,
    // read address channel
    output [ 3:0] cpu_arid,         // M->S 
    output [31:0] cpu_araddr,       // M->S 
    output [ 7:0] cpu_arlen,        // M->S 
    output [ 2:0] cpu_arsize,       // M->S 
    output [ 1:0] cpu_arburst,      // M->S 
    output [ 1:0] cpu_arlock,       // M->S 
    output [ 3:0] cpu_arcache,      // M->S 
    output [ 2:0] cpu_arprot,       // M->S 
    output        cpu_arvalid,      // M->S 
    input         cpu_arready,      // S->M 
    // read data channel
    input  [ 3:0] cpu_rid,          // S->M 
    input  [31:0] cpu_rdata,        // S->M 
    input  [ 1:0] cpu_rresp,        // S->M 
    input         cpu_rlast,        // S->M 
    input         cpu_rvalid,       // S->M 
    output        cpu_rready,       // M->S
    // write address channel 
    output [ 3:0] cpu_awid,         // M->S
    output [31:0] cpu_awaddr,       // M->S
    output [ 7:0] cpu_awlen,        // M->S
    output [ 2:0] cpu_awsize,       // M->S
    output [ 1:0] cpu_awburst,      // M->S
    output [ 1:0] cpu_awlock,       // M->S
    output [ 3:0] cpu_awcache,      // M->S
    output [ 2:0] cpu_awprot,       // M->S
    output        cpu_awvalid,      // M->S
    input         cpu_awready,      // S->M
    // write data channel
    output [ 3:0] cpu_wid,          // M->S
    output [31:0] cpu_wdata,        // M->S
    output [ 3:0] cpu_wstrb,        // M->S
    output        cpu_wlast,        // M->S
    output        cpu_wvalid,       // M->S
    input         cpu_wready,       // S->M
    // write response channel
    input  [ 3:0] cpu_bid,          // S->M 
    input  [ 1:0] cpu_bresp,        // S->M 
    input         cpu_bvalid,       // S->M 
    output        cpu_bready        // M->S 

    // debug signals
  `ifdef SIMU_DEBUG
   ,output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
  `endif    
  );

wire        inst_req;
wire [ 1:0] inst_size;
wire [31:0] inst_addr;
wire [31:0] inst_rdata;
wire        inst_addr_ok;
wire        inst_data_ok;

wire        data_req;
wire        data_wr;

wire [ 1:0] data_rsize;
wire [31:0] data_raddr;
wire [31:0] data_rdata;
wire        data_raddr_ok;
wire        data_rdata_ok;

wire [ 1:0] data_wsize;
wire [31:0] data_waddr;
wire [31:0] data_wdata;
wire        data_waddr_ok;
wire        data_wdata_ok;

mycpu cpu(
    .clk                 ( clk               ),
    .resetn              ( resetn            ),
    .int_i               ( int_i             ),

    .inst_req            ( inst_req         ),   
    .inst_size           ( inst_size        ),    
    .inst_addr           ( inst_addr        ),    
    .inst_rdata          ( inst_rdata       ),     
    .inst_addr_ok        ( inst_addr_ok     ),       
    .inst_data_ok        ( inst_data_ok     ),       
                                                                    
    .data_req            ( data_req         ),   
    .data_wr             ( data_wr          ),  

    .data_rsize          ( data_rsize       ),    
    .data_raddr          ( data_raddr       ),    
    .data_rdata          ( data_rdata       ),     
    .data_raddr_ok       ( data_raddr_ok    ),       
    .data_rdata_ok       ( data_rdata_ok    ),

    .data_wsize          ( data_wsize       ),    
    .data_waddr          ( data_waddr       ),    
    .data_wdata          ( data_wdata       ),     
    .data_waddr_ok       ( data_waddr_ok    ),    //write addr and data ok   
    .data_wdata_ok       ( data_wdata_ok    ),    //write response

    //debug
    .debug_wb_pc         ( debug_wb_pc       ),
    .debug_wb_rf_wen     ( debug_wb_rf_wen   ),
    .debug_wb_rf_wnum    ( debug_wb_rf_wnum  ),
    .debug_wb_rf_wdata   ( debug_wb_rf_wdata )
);


cpu_axi_interface axi_interface(
    .clk                 ( clk              ),
    .resetn              ( resetn           ),
                         
    .inst_req            ( inst_req         ),   
    .inst_size           ( inst_size        ),    
    .inst_addr           ( inst_addr        ),    
    .inst_rdata          ( inst_rdata       ),     
    .inst_addr_ok        ( inst_addr_ok     ),       
    .inst_data_ok        ( inst_data_ok     ),       
                                                                    
    .data_req            ( data_req         ),   
    .data_wr             ( data_wr          ),  

    .data_rsize          ( data_rsize       ),    
    .data_raddr          ( data_raddr       ),    
    .data_rdata          ( data_rdata       ),     
    .data_raddr_ok       ( data_raddr_ok    ),       
    .data_rdata_ok       ( data_rdata_ok    ),

    .data_wsize          ( data_wsize       ),    
    .data_waddr          ( data_waddr       ),    
    .data_wdata          ( data_wdata       ),     
    .data_waddr_ok       ( data_waddr_ok    ),    //write addr and data ok   
    .data_wdata_ok       ( data_wdata_ok    ),    //write response
                                                                    
    .arid                ( cpu_arid         ), 
    .araddr              ( cpu_araddr       ), 
    .arlen               ( cpu_arlen        ), 
    .arsize              ( cpu_arsize       ), 
    .arburst             ( cpu_arburst      ), 
    .arlock              ( cpu_arlock       ), 
    .arcache             ( cpu_arcache      ), 
    .arprot              ( cpu_arprot       ), 
    .arvalid             ( cpu_arvalid      ), 
    .arready             ( cpu_arready      ), 
                                                                                    
    .rid                 ( cpu_rid          ), 
    .rdata               ( cpu_rdata        ), 
    .rresp               ( cpu_rresp        ), 
    .rlast               ( cpu_rlast        ), 
    .rvalid              ( cpu_rvalid       ), 
    .rready              ( cpu_rready       ), 
                                      
    .awid                ( cpu_awid         ), 
    .awaddr              ( cpu_awaddr       ), 
    .awlen               ( cpu_awlen        ), 
    .awsize              ( cpu_awsize       ), 
    .awburst             ( cpu_awburst      ), 
    .awlock              ( cpu_awlock       ), 
    .awcache             ( cpu_awcache      ), 
    .awprot              ( cpu_awprot       ), 
    .awvalid             ( cpu_awvalid      ), 
    .awready             ( cpu_awready      ), 
                               
    .wid                 ( cpu_wid          ), 
    .wdata               ( cpu_wdata        ), 
    .wstrb               ( cpu_wstrb        ), 
    .wlast               ( cpu_wlast        ), 
    .wvalid              ( cpu_wvalid       ), 
    .wready              ( cpu_wready       ), 
                               
    .bid                 ( cpu_bid          ), 
    .bresp               ( cpu_bresp        ), 
    .bvalid              ( cpu_bvalid       ), 
    .bready              ( cpu_bready       )  
);    


endmodule
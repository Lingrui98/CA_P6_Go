module cpu_axi_interface(
    input          clk,
    input          resetn,

    input          inst_req,
    input          inst_wr,
    input   [ 1:0] inst_size,
    input   [31:0] inst_addr,
    input   [31:0] inst_wdata,
    output  [31:0] inst_rdata,
    output         inst_addr_ok,
    output         inst_data_ok,

    input          data_req,
    input          data_wr,
    input   [ 1:0] data_size,
    input   [31:0] data_addr,
    input   [31:0] data_wdata,
    output  [31:0] data_rdata,
    output         data_addr_ok,
    output         data_data_ok,

    output  [ 3:0] arid,       //1'b0
    output  [31:0] araddr,
    output  [ 7:0] arlen,      //1'b0
    output  [ 2:0] arsize,
    output  [ 1:0] arburst,    //2'b01
    output  [ 1:0] arlock,     //1'b0
    output  [ 3:0] arcache,    //1'b0
    output  [ 2:0] arprot,     //1'b0
    output         arvalid,    //To slave
    input          arready,    //From slave

    input   [ 3:0] rid,        //Can be ignored
    input   [31:0] rdata,
    input   [ 1:0] rresp,      //Can be ignored
    input          rlast,      //Can be ignored
    input          rvalid,     //From slave
    output         rready,     //To slave

    output  [ 3:0] awid,       //1'b0
    output  [31:0] awaddr,
    output  [ 7:0] awlen,      //1'b0
    output  [ 2:0] awsize,
    output  [ 1:0] awburst,    //2'b01
    output  [ 1:0] awlock,     //1'b0
    output  [ 3:0] awcache,    //1'b0
    output  [ 2:0] awprot,     //1'b0
    output         awvalid,    //To slave
    input          awready,    //From slave

    output  [ 3:0] wid,        //1'b0
    output  [31:0] wdata,
    output  [ 3:0] wstrb,
    output         wlast,      //1'b1
    output         wvalid,     //To slave
    input          wready,     //From slave

    input   [ 3:0] bid,        //Can be ignored
    input   [ 1:0] bresp,      //Can be ignored
    input          bvalid,     //From slave
    output         bready      //To slave
);    

    reg [31:0] araddr_r;
    reg [ 2:0] arsize_r;
    reg        arvalid_r;
    reg        arready_r;

    reg        rready_r;

    reg [31:0] awaddr_r;
    reg [ 2:0] awsize_r;
    reg        awvalid_r;
    reg        awready_r;

    reg [31:0] wdata_r;
    reg        wvalid_r;
    reg        wready_r;

    reg        bvalid_r;
    reg        bready_r;

    reg        inst_req_r;
    reg        inst_wr_r;
    reg [ 1:0] inst_size_r;
    reg [31:0] inst_addr_r;
    reg [31:0] inst_wdata_r;
    reg [31:0] inst_rdata_r;

    reg        data_req_r;
    reg        data_wr_r;
    reg [ 1:0] data_size_r;
    reg [31:0] data_addr_r;
    reg [31:0] data_wdata_r;
    reg [31:0] data_rdata_r;



    assign arid    = 4'd0;
    assign arlen   = 8'd0;
    assign arburst = 2'b01; // 2'd0?
    assign arlock  = 2'd0;
    assign arcache = 4'd0;
    assign arprot  = 3'd0;

    assign awid  = 4'd0;
    assign awlen = 8'd0;
    assign awburst = 2'b01; // 2'd0?
    assign awlock  = 2'd0;
    assign awcache = 4'd0;
    assign awprot  = 3'd0;
    
    assign wid    = 4'd0;
    assign wlast  = 1'b1;
    
//    assign araddr = inst_addr | data_addr;
//    assign arsize = inst_size | data_size;
    
/*  always @ (posedge clk) begin
    if (~resetn) begin
        inst_req_r   <= 1'd0;
        inst_wr_r    <= 1'd0;
        inst_size_r  <= 2'd0;
        inst_addr_r  <= 32'd0;
        inst_wdata_r <= 32'd0;
        inst_rdata_r <= 32'd0;
    end
    else if ()


    

    end    
*/    


reg do_r_req,    do_w_req;
reg do_r_req_or, do_w_req_or;
reg [ 1:0] do_r_size_r, do_w_size_r;
reg [31:0] do_r_addr_r, do_w_addr_r;
reg [31:0] do_wdata_r;
wire r_data_back, w_data_back;

assign inst_addr_ok = !do_r_req&&!do_w_req&&!data_req;
assign data_addr_ok = !do_r_req&&!do_w_req;

always @ (posedge clk) begin
    do_r_req    <= ~resetn                                                  ? 1'b0 :
                   (inst_req&&~inst_wr || data_req&&~data_wr) && ~do_r_req  ? 1'b1 :
                   r_data_back                                              ? 1'b0 : do_r_req;
    do_r_req_or <= ~resetn   ? 1'b0 :
                   ~do_r_req ? (data_req&&~data_wr) : do_r_req_or;
    do_r_size_r <= (data_req&&~data_wr)&&data_addr_ok ? data_size :
                   (inst_req&&~inst_wr)&&inst_addr_ok ? inst_size : do_r_size_r;
    do_r_addr_r <= (data_req&&~data_wr)&&data_addr_ok ? data_addr :
                   (inst_req&&~inst_wr)&&inst_addr_ok ? inst_addr : do_r_addr_r;
end

always @ (posedge clk) begin
    do_w_req    <= ~resetn                                                ? 1'b0 :
                   (inst_req&&inst_wr || data_req&&data_wr) && ~do_w_req  ? 1'b1 :
                   w_data_back                                            ? 1'b0 : do_w_req;
    do_w_req_or <= ~resetn   ? 1'b0 :
                   ~do_w_req ? (data_req&&data_wr) : do_w_req_or;
    do_w_size_r <= (data_req&&data_wr)&&data_addr_ok ? data_size :
                   (inst_req&&inst_wr)&&inst_addr_ok ? inst_size : do_w_size_r;
    do_w_addr_r <= (data_req&&data_wr)&&data_addr_ok ? data_addr :
                   (inst_req&&inst_wr)&&inst_addr_ok ? inst_addr : do_w_addr_r;
    do_wdata_r  <= (data_req&&data_wr)&&data_addr_ok ? data_wdata : 
                   (inst_req&&inst_wr)&&inst_addr_ok ? inst_wdata : do_wdata_r;
end

assign inst_data_ok = (do_r_req&&~do_r_req_or&&r_data_back) || (do_w_req&&~do_w_req_or&&w_data_back); //Must have problems here
assign data_data_ok = (do_r_req&& do_r_req_or&&r_data_back) || (do_w_req&& do_w_req_or&&w_data_back); //Must have problems here
assign inst_rdata   = rdata;
assign data_rdata   = rdata;



reg r_addr_rcv, w_addr_rcv;
reg wdata_rcv;

assign r_data_back = r_addr_rcv && (rvalid && rready);
assign w_data_back = w_addr_rcv && (bvalid && bready);

always @ (posedge clk) begin
    r_addr_rcv <= ~resetn            ? 1'b0 :
                  arvalid&&arready   ? 1'b1 :
                  r_data_back        ? 1'b0 : r_addr_rcv;
end

always @ (posedge clk) begin
    w_addr_rcv <= ~resetn            ? 1'b0 :
                  awvalid&&awready   ? 1'b1 :
                  w_data_back        ? 1'b0 : w_addr_rcv;
    wdata_rcv  <= ~resetn            ? 1'b0 :
                  wvalid&&wready     ? 1'b1 :
                  w_data_back        ? 1'b0 : wdata_rcv;
end

assign araddr  = do_r_addr_r;
assign arsize  = do_r_size_r;
assign arvalid = do_r_req && ~r_addr_rcv;

assign rready  = 1'b1;

assign awaddr  = do_w_addr_r;
assign awsize  = do_w_size_r;
assign awvalid = do_w_req && ~w_addr_rcv;

assign wdata  = do_wdata_r;
assign wstrb  = do_w_size_r==2'd0 ? 4'b0001<<do_w_addr_r[1:0] :
                do_w_size_r==2'd1 ? 4'b0011<<do_w_addr_r[1:0] : 4'b1111;
assign wvalid = do_w_req&&~wdata_rcv;

assign bready = 1'b1;

endmodule
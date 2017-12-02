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
    output  reg    rready,     //To slave

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
    output  reg    bready      //To slave
);    


//    assign arid    = 4'd0;
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

    reg  do_req_raddr;
    reg  do_req_raddr_or;
    reg  r_addr_rcv;
    wire r_data_back;


    always @ (posedge clk) begin

        do_req_raddr    <= !resetn                                         ? 1'b0 :
                           (inst_req||data_req&&!data_wr) && !do_req_raddr ? 1'b1 :
                           arvalid&&arready                                ? 1'b0 : do_req_raddr;
        do_req_raddr_or <= !resetn        ? 1'b0 :
                           !do_req_raddr  ? (data_req&&!data_wr) : do_req_raddr_or;
    end
    assign arid    = do_req_raddr&&!do_req_raddr_or ? 4'd0 :
                     do_req_raddr&& do_req_raddr_or ? 4'd1 : 4'hx;
    assign arvalid = do_req_raddr&&!r_addr_rcv;
    assign araddr  = do_req_raddr&& do_req_raddr_or ? data_addr :
                     do_req_raddr&&!do_req_raddr_or ? inst_addr : 32'hxxxxxxxx;
    assign arsize  = do_req_raddr&& do_req_raddr_or ? data_size :
                     do_req_raddr&&!do_req_raddr_or ? inst_size : 3'hx;

    assign inst_addr_ok = arvalid&&arready && do_req_raddr&&!do_req_raddr_or;

    wire r_addr_rcv_pos;
    assign r_data_back = r_addr_rcv && (rvalid && rready);
    
    always @(posedge clk) begin
        r_addr_rcv <= !resetn          ? 1'b0 :
                      arvalid&&arready ? 1'b1 :
                      r_data_back      ? 1'b0 : r_addr_rcv;
        rready     <= !resetn          ? 1'b0 :
                      r_addr_rcv_pos   ? 1'b1 :
                      r_data_back      ? 1'b0 : rready;
    end

    reg  do_req_waddr;
    reg  do_req_wdata;
    reg  w_addr_rcv;
    reg  w_data_rcv;
    wire w_data_back;

    reg [31:0] do_wdata_r;
    reg [31:0] do_waddr_r;
    reg [ 1:0] do_dsize_r;

//    reg [31:0] do_waddr_r [0:15];
    reg  [1:0] data_in_ready, data_in_ready_r;
    wire data_in_ready_pos;

    reg  w_addr_rcv_r,   w_data_rcv_r;
    wire w_addr_rcv_pos, w_data_rcv_pos;

//    wire data_wdata_ready;
//    wire data_waddr_ready;

    always @ (posedge clk) begin
        do_req_waddr     <= !resetn                            ? 1'b0 : 
                            data_req&&data_wr && !do_req_waddr ? 1'b1 :
                            awvalid&&awready                   ? 1'b0 : do_req_waddr;
        do_req_wdata     <= !resetn                            ? 1'b0 :
                            data_req&&data_wr && !do_req_wdata ? 1'b1 :
                            wvalid&&wready                     ? 1'b0 : do_req_wdata;
        do_wdata_r       <= data_addr_ok ? data_wdata : do_wdata_r;
        do_waddr_r       <= data_addr_ok ? data_addr  : do_waddr_r;
        do_dsize_r       <= data_addr_ok ? data_size  : do_dsize_r;
        data_in_ready    <= !resetn                        ? 2'd0 :
                            w_addr_rcv_pos&&w_data_rcv_pos ? 2'd2 :
                            w_addr_rcv_pos                 ? data_in_ready + 1'd1 :
                            w_data_rcv_pos                 ? data_in_ready + 1'd1 :
                            w_data_back                    ? 2'd0 : data_in_ready;
    end
    
    assign data_addr_ok  = arvalid&&arready && do_req_raddr&& do_req_raddr_or || data_in_ready_pos;
//    assign data_wdata_ready = wvalid &&wready  && do_req_wdata;
//    assign data_waddr_ready = awvalid&&awready && do_req_waddr;

    assign awvalid = do_req_waddr && !w_addr_rcv;
    assign awaddr  = do_req_waddr ? do_waddr_r : 32'hxxxxxxxx;
    assign awsize  = do_req_waddr ? do_dsize_r : 3'hx;

    assign wdata = do_wdata_r;
    assign wstrb = do_dsize_r==2'd0 ? 4'b0001<<do_waddr_r[1:0] :
                   do_dsize_r==2'd1 ? 4'b0011<<do_waddr_r[1:0] : 4'b1111;
    assign wvalid = !w_data_rcv; // problems here

    assign w_data_back = (w_addr_rcv&&w_data_rcv) && (bvalid && bready);

    always @ (posedge clk) begin
        w_addr_rcv <= !resetn            ? 1'b0 :             //slave receives waddr and haven't received wdata.
                      awvalid&&awready   ? 1'b1 :
                      w_data_back        ? 1'b0 : w_addr_rcv; 
        w_data_rcv <= !resetn            ? 1'b0 :             //slave receives wdata and haven't send response
                      wvalid&&wready     ? 1'b1 :
                      w_data_back        ? 1'b0 : w_data_rcv;
        bready     <= !resetn                ? 1'b0 :
                      w_addr_rcv&&w_data_rcv ? 1'b1 :
                      w_data_back            ? 1'b0 : bready;
    end

    assign inst_data_ok =  r_data_back && rid==4'd0;                 //Problems here
    assign data_data_ok = (r_data_back && rid==4'd1) || w_data_back; //Problems here
    assign inst_rdata = rdata;
    assign data_rdata = rdata;


    reg r_addr_rcv_r;
    always @ (posedge clk) begin
        r_addr_rcv_r    <= !resetn ? 1'b0 : r_addr_rcv;
        data_in_ready_r <= !resetn ? 2'd0 : data_in_ready;
        w_addr_rcv_r    <= !resetn ? 1'b0 : w_addr_rcv;
        w_data_rcv_r    <= !resetn ? 1'b0 : w_data_rcv;
    end

    assign r_addr_rcv_pos    = r_addr_rcv          & ~r_addr_rcv_r;
    assign data_in_ready_pos = data_in_ready==2'd2 & data_in_ready_r!=2'd2;
    assign w_addr_rcv_pos    = w_addr_rcv          & ~w_addr_rcv_r;
    assign w_data_rcv_pos    = w_data_rcv          & ~w_data_rcv_r;
endmodule


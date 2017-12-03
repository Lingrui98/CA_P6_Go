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
    output  reg    arvalid,    //To slave
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



    


//    reg        do_req_raddr;
    reg        do_req_raddr_or; //Read from data_sram or not
    reg [ 3:0] do_arid;         //Current arid
    reg [31:0] do_araddr;       //Current araddr
    reg [31:0] do_arsize;       //Current arsize
    reg  r_addr_rcv;            //Read address received by slave and read data haven't returned, one cycle after handshake.
    reg  r_addr_rcv_r;
    wire r_data_back;           //Read data returns, goes high as soon as handshake occurs in r_channel
    wire r_addr_rcv_pos;        //Postive edge of r_addr_rcv


    reg  do_req_waddr;          //Doing request of write address, goes down when write address received.
    reg  do_req_wdata;          //Doing request of write data, goes down when write data received.
    reg  w_addr_rcv;            //Write address received by slave and write response haven't returned, one cycle after handshake in aw_channel.
    reg  w_data_rcv;            //Write data received by slave and write response haven't returned, one cycle after handshake in w_channel.
    wire w_data_back;           //Write response returns, goes high as soon as handshake occurs in b_channel.

    reg [31:0] do_wdata_r;      //Current write data.  
    reg [31:0] do_waddr_r;      //Current write address.
    reg [ 1:0] do_dsize_r;      //Current write size.

    reg [ 1:0] data_in_ready;   //Indicates whether aw_channel and w_channel is ready, the lower bit standing for waddr and the higher bit standing for wdata
    reg [ 1:0] data_in_ready_r; //Used for data_in_ready_pos
    wire data_in_ready_pos;     //Positive edge of data_in_ready, goes high in the cycle when data_in_ready achieves 2'b11

    reg  w_addr_rcv_r;
    reg  w_data_rcv_r;
    wire w_addr_rcv_pos;        //Positive edge of w_addr_rcv
    wire w_data_rcv_pos;        //Positive edge of w_data_rcv


    assign inst_addr_ok = arvalid&&arready && !do_req_raddr_or;
    assign data_addr_ok  = arvalid&&arready && do_req_raddr_or || data_in_ready==2'b01 && wvalid&&wready && do_waddr_r!=32'hxxxxxxxx || data_in_ready==2'b10 && awvalid&&awready && do_waddr_r!=32'hxxxxxxxx;

    always @ (posedge clk) begin
//        do_req_raddr    <= !resetn                                         ? 1'b0 :
//                           (inst_req||data_req&&!data_wr) && !do_req_raddr ? 1'b1 :
//                           r_addr_rcv_pos                                  ? 1'b0 : do_req_raddr;
        do_req_raddr_or <= !resetn          ? 1'b0 :
                           arready&&arvalid ? (data_req&&!data_wr) : do_req_raddr_or;
        do_arid         <= !resetn        ? 4'd0 :
                           r_addr_rcv_pos ? (do_req_raddr_or ? 4'd1 : 4'd0) : do_arid;              
        do_araddr       <= !resetn        ? 32'd0 :
                           r_addr_rcv_pos ? (do_req_raddr_or ? data_addr : inst_addr) : do_araddr;
        do_arsize       <= !resetn        ? 3'd0 :
                           r_addr_rcv_pos ? (do_req_raddr_or ? data_size : inst_size) : do_arsize;
        arvalid         <= !resetn                                        ? 1'b0 :
                           r_addr_rcv_pos&&(inst_req||data_req&&!data_wr) ? 1'b1 :
                           arready                                        ? 1'b0 : 1'b1;

    end


    
    always @(posedge clk) begin
        r_addr_rcv <= !resetn          ? 1'b0 :
                      arvalid&&arready ? 1'b1 :
                      r_data_back      ? 1'b0 : r_addr_rcv;
        rready     <= !resetn          ? 1'b0 :
                      r_addr_rcv_pos   ? 1'b1 :
                      r_data_back      ? 1'b0 : rready;
    end


    assign r_data_back = r_addr_rcv && (rvalid && rready);




//    reg [32:0] do_waddr_r [0:3];
//    reg [ 3:0] do_dsize_r [0:3];




//    wire [2:0] write_id_n;
//Select awid, wid
//    assign write_id_n = do_waddr_r[0] == 32'hxxxxxxxx ? 3'd0 :
//                        do_waddr_r[1] == 32'hxxxxxxxx ? 3'd1 :
//                        do_waddr_r[2] == 32'hxxxxxxxx ? 3'd2 :
//                        do_waddr_r[3] == 32'hxxxxxxxx ? 3'd3 : 3'd4;

//    wire data_wdata_ready;
//    wire data_waddr_ready;

    always @ (posedge clk) begin
        do_req_waddr     <= !resetn                            ? 1'b0 : 
                            data_req&&data_wr && !do_req_waddr ? 1'b1 :
                            awvalid&&awready                   ? 1'b0 : do_req_waddr;
        do_req_wdata     <= !resetn                            ? 1'b0 :
                            data_req&&data_wr && !do_req_wdata ? 1'b1 :
                            wvalid&&wready                     ? 1'b0 : do_req_wdata;
        do_wdata_r       <= data_in_ready_pos ? data_wdata : do_wdata_r;
        do_waddr_r       <= data_in_ready_pos ? data_addr  : do_waddr_r;
        do_dsize_r       <= data_in_ready_pos ? data_size  : do_dsize_r;
        data_in_ready    <= !resetn                        ? 2'b00 :
                            w_addr_rcv_pos&&w_data_rcv_pos ? 2'b11 :
                            w_addr_rcv_pos                 ? data_in_ready + 2'b01 :
                            w_data_rcv_pos                 ? data_in_ready + 2'b10 :
                            w_data_back                    ? 2'b00 : data_in_ready;
//       if (write_id_n==3'd0) begin
//            do_waddr_r[0]
 //       end
    end
    
//    assign data_wdata_ready = wvalid &&wready  && do_req_wdata;
//    assign data_waddr_ready = awvalid&&awready && do_req_waddr;
//    assign awid = write_id_n;
//    assign wid  = write_id_n;

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

    assign w_data_back = (w_addr_rcv&&w_data_rcv) && (bvalid && bready);



/////////////////////////////////////////////////////////////////////
//ar_channel
    assign arid   = do_arid;
    assign araddr = do_araddr;
    assign arsize = do_arsize;

    assign arlen   = 8'd0;
    assign arburst = 2'b01; // 2'd0?
    assign arlock  = 2'd0;
    assign arcache = 4'd0;
    assign arprot  = 3'd0;

/////////////////////////////////////////////////////////////////////
//aw_channel
    assign awvalid = do_req_waddr && !w_addr_rcv; //&& write_id_n!=3'd4;
    assign awaddr  = do_req_waddr ? do_waddr_r : 32'hxxxxxxxx;
    assign awsize  = do_req_waddr ? do_dsize_r : 3'hx;

    assign awid  = 4'd0;
    assign awlen = 8'd0;
    assign awburst = 2'b01; // 2'd0?
    assign awlock  = 2'd0;
    assign awcache = 4'd0;
    assign awprot  = 3'd0;

/////////////////////////////////////////////////////////////////////
//w_channel
    assign wdata = do_wdata_r;
    assign wstrb = do_dsize_r==2'd0 ? 4'b0001<<do_waddr_r[1:0] :
                   do_dsize_r==2'd1 ? 4'b0011<<do_waddr_r[1:0] : 4'b1111;
    assign wvalid = do_req_wdata && !w_data_rcv;// && write_id_n!=3'd4; // problems here
    assign wid    = 4'd0;
    assign wlast  = 1'b1;



    assign inst_data_ok =  r_data_back && rid==4'd0;                 //Problems here
    assign data_data_ok = (r_data_back && rid==4'd1) || w_data_back; //Problems here
    assign inst_rdata = rid==4'd0 ? rdata : 32'hxxxxxxxx;
    assign data_rdata = rid==4'd1 ? rdata : 32'hxxxxxxxx;

/////////////////////////////////////////////////////////////////////
//All posedges
    always @ (posedge clk) begin
        r_addr_rcv_r    <= !resetn ? 1'b0 : r_addr_rcv;
        data_in_ready_r <= !resetn ? 2'd0 : data_in_ready;
        w_addr_rcv_r    <= !resetn ? 1'b0 : w_addr_rcv;
        w_data_rcv_r    <= !resetn ? 1'b0 : w_data_rcv;
    end

    assign r_addr_rcv_pos    = r_addr_rcv          & ~r_addr_rcv_r;
    assign data_in_ready_pos = data_in_ready==2'd3 & data_in_ready_r!=2'd3;
    assign w_addr_rcv_pos    = w_addr_rcv          & ~w_addr_rcv_r;
    assign w_data_rcv_pos    = w_data_rcv          & ~w_data_rcv_r;


endmodule


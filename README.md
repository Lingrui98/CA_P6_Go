# CA_P6_Go
Add support for AXI Bus
## 第一部分问题
* 仿真显示，当且仅当arvalid和arready同拍置1时，rdata能读出有效值。这表明，ar通道的采样可能发生在arvalid置1期间，而不是在某一上升沿检测到arvalid&&arready为高电平的瞬间采样。
* virtual cpu中data端传出写通道数据靠data_addr_cnt计数，但该变量每当data_addr_ok传入增1，此时data_wdata不一定就绪，故实际上应该是waddr和wdata都就绪以后才传入cpudata_addr_ok。此处坑甚大。
### 目前interface的问题
* data_addr_ok由data的读写通道准备完成信号进行或运算，但造成了一个问题：读操作未获得响应时，之前的写操作获得了响应，传出了data_addr_ok，将cnt变为错误的值。
#### 第一阶段data通道的测试过程梳理
   首先，第一个测试点data发出写操作，在返回addr_ok后，data通道发出下一个req。注意data通道的req变更是由data_addr_ok触发的。这样存在问题。例如，按我们的读写通道分离逻辑，data发出的读请求还没有返回data_data_ok之前，可能发出下一个写请求。而如果写请求在读请求之前完成，则会触发对应读请求cnt的测试点。而这个data_back是写响应信号，rdata并没有返回值。这样会造成测试错误。
   
   由此可以想到，如果要通过第一阶段的测试，对于data通道一定要顺序返回data_ok。如何实现这一点呢？可能的做法如下：
   1. 前一个data通道的data_ok返回前，不处理下一个data_req。
   2. 如果存在读写操作的data_ok顺序颠倒，若请求顺序为读、写，则将先返回的写响应寄存，等到读操作data返回后再送出写响应的data_ok。这样实现起来太过复杂。
   
   实际上，这个顺序返回data_ok的限制是由data通道读写共用的特性造成的。如果直接对应axi接口，将data的写通道接到aw、w、b通道，读通道和inst的读通道一起接到ar和r通道，由仲裁逻辑判断执行哪一个，则不存在须顺序返回的问题。但是这样会造成潜在的读写相关。我们设想中的访存级行为是：对于读操作，在其数据返回之前，将流水线阻塞；对于写操作，可以继续执行下去。这样带来了下文中提到的问题，对此的解决方案也在下文列出。

## 第二部分注意事项
* 读请求之前有未完成的inst读请求（地址握手成功但数据未握手），将inst的读数据导入FIFO，直到返回data的读数据。当FIFO中存在有效数据时，IR从FIFO中更新数据，否则从AXI rdata端更新。这样可以将inst的id设为0，data设为1，以作区分。
* data部分写数据请求不需要阻塞，这样带来了一个问题，写响应未返回前，即数据未写入该地址时，可能对对应的地址有读请求，这样可能读出错误数据。对此的解决办法是，记录未完成的写操作的地址，读请求到来时，判断地址是否在此列表中，若是，则不发读请求的arvalid，否则正常运行。写操作可以用id号标识，同时维护未完成写操作也可以对应id号。~~表的地址默认值为32'hxxxxxxxx，若非，则该id有未完成的写操作。~~
这样也解决了分配id号的问题。如果表满，阻塞之（事实上基本不会发生）。
> *更正：前述将表地址默认值设为32'hxxxxxxxx的做法是错误的。因为实测中，类似 addr!=32'hxxxxxxxx 的逻辑，在addr值为不定态的时候，是一定也会成为不定态的。修正方法是：表地址设为33位，多出来的一位作为该id是否有效的标识。*
* 若将CPU访存接口修改为类SRAM接口，CPU相应的动作也须做出如下调整：
   1. 接口传入en信号即发出req，inst读通道直到传回addr_ok再拉低req，等待rvalid信号传回，data_ok置一，写IR，并在读地址握手成功前阻塞。
   2. data读通道同理，在addr_ok后拉低req，但流水级阻塞直到r通道返回rvalid，即返回data_ok。
   3. data写通道直到传回awready和wready才拉低req，但此时可以继续流水级，因为维护了一张表。表满造成的影响是：新的sw的req无法发出，直到一个表项空出。
#### 有关inst_FIFO的事项：
>   1. 此FIFO永远只用于等待LW返回读数据之前存储之前送入ram的inst读地址的读数据。
>   2. 在LW指令发出读地址后，将标记位置1，标记位为1期间，屏蔽inst_req，读通道返回的rid为0的数据，即指令，加上一位有效位，存入inst_FIFO。除此之外读数据直接给IR。前述标记位在LW数据返回后置0.
>   3. 写IR的逻辑中，可以从FIFO的尾端开始判断，若有效位为1，则从中读数据，依次向前，若全无效，从rdata端读数据，同时给出rready信号，axi的r_channel继续“流动”。
>   4. 从FIFO的任意项任意读出数据后，将有效位置0。
#### 有关PC_FIFO的事项
>   1. 此FIFO在每一次inst读地址握手成功时流动。
>   2. 其中每项仍需要有效位。
>   3. 每次IR更新时，从此FIFO中读有效PC，与指令一起向下传递，并将有效位置0。
>   4. FIFO满时不可继续发arvalid。
>   5. 有关分支跳
#### 有关同拍inst和data同时发read_req的问题
   按优先级来讲，肯定优先将data的读请求放入ar通道。但此时inst_req如何保持？见下文。
   
#### AXI读通道：PC与memraddr
* 将next_PC_gen模块视为一个提供AXI ar通道数据的选择，在需要时将它送入，否则保持。
* ar通道握手成功且arid为0时，送入读指令请求，当且仅当此时更新next_PC。
* 取指的outstanding值为2，为此设寄存器一个(PC_buffer)，当且仅当ar通道握手成功且arid是0时，将araddr写入PC_buffer。以备读出指令时传下debug_PC。
* 当且仅当r通道握手成功且rid为0时，更新IR，将上述寄存器的值传给debug_PC。
* 如果上升沿收到来自mem stage的读请求，优先处理data_req。直接送入ar通道，arid设1。当且仅当这次ar通道握手成功时，将一个标志位do_data_req置1。
``` Verilog
///////////////////////////////////////////////////
//logic for AXI ar&r channel
      assign rready = decode_allowin || data_req;      
      if (!IR_buffer[32]) begin
         if (rready&&rvalid) begin
            if (!do_data_req) begin
               if (rid==4'd0) begin            
                  debug_PC  <= PC_buffer;
                  IR        <= rdata;
                  arvalid_r <= 1'b1;
               end
            end
            else if (rid==4'd0) begin
                  IR_buffer <= {1'b1,rdata};
            end
            else if (rid==4'd1) begin  //隐含在else中，不必要
               mem_rdata   <= rdata;   //传给mem级
               do_data_req <= 1'b0;
            end
         end
      end
      else begin
         if (decode_allowin) begin
            IR            <= IR_buffer;
            debug_PC      <= PC_buffer;
            IR_buffer[32] <= 1'b0;
            arvalid_r     <= 1'b1;
         end
      end 
      
      reg arvalid_r;
      if (arready&&arvalid&&arid==1'b0) begin
         PC_buffer <= araddr;
         PC        <= next_PC; //刷新PC
         arvalid_r <= 1'b0;
      end
      

      assign arvalid = first_fetch || arvalid_r&&!do_data_req || data_req;

      assign arid = data_req;
      assign araddr = data_req ? data_raddr : PC;
      assign arsize = data_req ? data_rsize : 3'd2;
      
 ```
#### store表的维护
* mem级收到store指令，检查write_id_n，若write_id_n != 4，即表未满，可以发data_w_req。即
```Verilog
      reg [32:0] do_waddr_r [0:3]; //最高位为有效位
      reg [ 3:0] do_dsize_r [0:3]; //用于计算是否能发出读data的request。
      
      wire [2:0] write_id_n;       //下个写操作的id号，若表满则为4，否则为最低有效值
      assign write_id_n = do_waddr_r[0][32]==1'b0 ? 3'd0 :
                          do_waddr_r[1][32]==1'b0 ? 3'd1 :
                          do_waddr_r[2][32]==1'b0 ? 3'd2 :
                          do_waddr_r[3][32]==1'b0 ? 3'd3 : 3'd4; 
      
      //若表满，则不能发写请求
      data_w_req <= !data_w_req   ? memwrite && write_id_n!=3'd4 :
                    data_in_ready ? 1'b0                         : data_w_req;
      
      //有潜在的相关可能，则不能发读请求
      data_r_req <= !data_r_req ? memread && pot_hazard :
                    r_data_back ? 1'b0                  : data_r_req; 
      
      //写响应返回，则拉低对应表项的有效位
      if (bvalid&&bready) begin
         if (bid==4'd0) do_waddr_r[0][32] <= 1'b0;
         if (bid==4'd1) do_waddr_r[1][32] <= 1'b0;
         if (bid==4'd2) do_waddr_r[2][32] <= 1'b0;
         if (bid==4'd3) do_waddr_r[3][32] <= 1'b0;
      end
      
      //与拉高写请求的判断逻辑相同，表项更新与写请求发出同时进行，有效位置1
      if (!data_w_req&&memwrite&&write_id_n!=3'd4) begin
         if (write_id_n==4'd0) begin
            do_waddr_r[0] <= {1'b1,data_waddr};
            do_dsize_r[0] <= data_wsize;
         end
         if (write_id_n==4'd1) begin
            do_waddr_r[1] <= {1'b1,data_waddr};
            do_dsize_r[1] <= data_wsize;
         end
         if (write_id_n==4'd2) begin
            do_waddr_r[2] <= {1'b1,data_waddr};
            do_dsize_r[2] <= data_wsize;
         end
         if (write_id_n==4'd3) begin
            do_waddr_r[3] <= {1'b1,data_waddr};
            do_dsize_r[3] <= data_wsize;
         end
      end
```
      
   
### 第二部分所需修改
* 修改各级流水前进逻辑，使之能适应握手环境
* 各种例外，中断重新考虑
* ...

## 第二部分问题
* Error 1
```Verilog
    [   2395 ns] Error!!!
    reference: PC = 0xbfc0068c, wb_rf_wnum = 0x05, wb_rf_wdata = 0xfffff004
    mycpu    : PC = 0xbfc00688, wb_rf_wnum = 0x04, wb_rf_wdata = 0xfffff008  
    
    错误原因： 新指令未取出之前，IR存着旧指令，每一拍持续向下一级发送，导致指令重复执行。   
    调整方法： 在各级间加入valid信号，具体逻辑见Verilog复习.pdf
```
* Error 2
```Verilog
   错误现象：debugPC = 0xbfc84768，陷入循环
   错误原因：向前追溯发现在一拍取指的arvalid已经发出的前提下，ar通道被data的读请求抢占，导致在arvalid置1期间，ar通道的数据改变。

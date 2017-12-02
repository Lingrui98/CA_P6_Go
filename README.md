# CA_P6_Go
Add support for AXI Bus
## 第一部分问题
* 仿真显示，当且仅当arvalid和arready同拍置1时，rdata能读出有效值。这表明，ar通道的采样可能发生在arvalid置1期间，而不是在某一上升沿检测到arvalid&&arready为高电平的瞬间采样。
* virtual cpu中data端传出写通道数据靠data_addr_cnt计数，但该变量每当data_addr_ok传入增1，此时data_wdata不一定就绪，故实际上应该是waddr和wdata都就绪以后才传入cpudata_addr_ok。此处坑甚大。

## 第二部分注意事项
* 读请求之前有未完成的inst读请求（地址握手成功但数据未握手），将inst的读数据导入FIFO，直到返回data的读数据。当FIFO中存在有效数据时，IR从FIFO中更新数据，否则从AXI rdata端更新。这样可以将inst的id设为0，data设为1，以作区分。
* data部分写数据请求不需要阻塞，这样带来了一个问题，写响应未返回前，即数据未写入该地址时，可能对对应的地址有读请求，这样可能读出错误数据。对此的解决办法是，记录未完成的写操作的地址，读请求到来时，判断地址是否在此列表中，若是，则不发读请求的arvalid，否则正常运行。写操作可以用id号标识，同时维护未完成写操作也可以对应id号。表的地址默认值为32'hxxxxxxxx。若非，则该id有未完成的写操作。这样也解决了分配id号的问题。如果表满，阻塞之（事实上基本不会发生）。

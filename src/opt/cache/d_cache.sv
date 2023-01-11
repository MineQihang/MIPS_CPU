`timescale 1ns / 1ps

module d_cache (
    input wire clk, rst,
    //mips core  上层接口
    input         cpu_data_req     ,  // cpu是否发出数据请求
    input         cpu_data_wr      ,  // cpu是否要写数据
    input  [1 :0] cpu_data_size    ,  // 结合地址最低两位，确定数据的有效字节（用于sb、sh等指令）
    input  [31:0] cpu_data_addr    ,  // 数据地址, 一个字
    input  [31:0] cpu_data_wdata   ,  // 要写入的数据
    output [31:0] cpu_data_rdata   ,  // 读出的数据
    output        cpu_data_addr_ok ,  // cache已经收到地址
    output        cpu_data_data_ok ,  // 可以读出数据了

    //axi interface  下层接口
    output         cache_data_req     ,  // 是否要发送访存请求
    output         cache_data_wr      ,  // 是否要写数据
    output  [1 :0] cache_data_size    ,  // 数据大小
    output  [31:0] cache_data_addr    ,  // 数据写入地址
    output  [31:0] cache_data_wdata   ,  // 要写入的数据
    input   [31:0] cache_data_rdata   ,  // 要读出的数据
    input          cache_data_addr_ok ,  // 下方已经收到地址
    input          cache_data_data_ok    // 下方是否已经准备好了数据
);
//==============================Cache配置与访问=================================
    //Cache配置
    parameter INDEX_WIDTH = 10, OFFSET_WIDTH = 2, DATA_WIDTH = 32;
    localparam TAG_WIDTH = 32 - INDEX_WIDTH - OFFSET_WIDTH;
    localparam CACHE_DEEPTH = 1 << INDEX_WIDTH;
    
    
    //Cache存储单元
    reg [2:0]              cache_pLRU  [CACHE_DEEPTH - 1 : 0]; // 记录是否最近被使用的
    reg [3:0]              cache_dirty [CACHE_DEEPTH - 1 : 0];
    reg [3:0]              cache_valid [CACHE_DEEPTH - 1 : 0];
    reg [4*TAG_WIDTH-1:0]  cache_tag   [CACHE_DEEPTH - 1 : 0];
    reg [4*DATA_WIDTH-1:0] cache_block [CACHE_DEEPTH - 1 : 0];

    //访问地址分解
    wire [OFFSET_WIDTH-1:0] offset;
    wire [INDEX_WIDTH-1:0] index;
    wire [TAG_WIDTH-1:0] tag;
    
    assign {tag, index, offset} = cpu_data_addr;

//=================================处理返回数据====================================
    //[New]判断是否命中
    wire [3:0] hit_way; // [New]哪路命中
    wire hit, miss; // [New]命中了哪个cache line
    wire [1:0] hit_num;
    wire [31:0] c_block; // 取出命中的block
    assign hit_way[0] = (cache_tag[index][1*TAG_WIDTH-1:0*TAG_WIDTH]==tag) & cache_valid[index][0];
    assign hit_way[1] = (cache_tag[index][2*TAG_WIDTH-1:1*TAG_WIDTH]==tag) & cache_valid[index][1];
    assign hit_way[2] = (cache_tag[index][3*TAG_WIDTH-1:2*TAG_WIDTH]==tag) & cache_valid[index][2];
    assign hit_way[3] = (cache_tag[index][4*TAG_WIDTH-1:3*TAG_WIDTH]==tag) & cache_valid[index][3];
    assign hit = hit_way[0] | hit_way[1] | hit_way[2] | hit_way[3];  //cache line的valid位为1，且tag与地址中tag相等
    assign miss = ~hit;
    assign hit_num = hit_way[0] ? 0 :
                     hit_way[1] ? 1 : 
                     hit_way[2] ? 2 : 3;
    assign c_block = (hit_num==0) ? cache_block[index][1*DATA_WIDTH-1:0*DATA_WIDTH] : 
                     (hit_num==1) ? cache_block[index][2*DATA_WIDTH-1:1*DATA_WIDTH] :
                     (hit_num==2) ? cache_block[index][3*DATA_WIDTH-1:2*DATA_WIDTH] :
                                    cache_block[index][4*DATA_WIDTH-1:3*DATA_WIDTH] ;

    // [New]判断是否有无效块
    wire valid;
    wire [1:0] invalid_num;
    assign valid = cache_valid[index][0] & cache_valid[index][1] & cache_valid[index][2] & cache_valid[index][3];
    assign invalid_num = ~cache_valid[index][0] ? 0 : 
                         ~cache_valid[index][1] ? 1 : 
                         ~cache_valid[index][2] ? 2 : 3;

    // [New]伪LRU算出要替换哪一块
    wire [1:0] lru_num;
    assign lru_num = ~cache_pLRU[index][0] & ~cache_pLRU[index][1] ? 0 :
                     ~cache_pLRU[index][0] &  cache_pLRU[index][1] ? 1 :
                     cache_pLRU[index][0] & ~cache_pLRU[index][2] ? 2 : 3;

    // [New]最后究竟替换哪一块
    wire [1:0] replace_num;
    assign replace_num = valid ? lru_num : invalid_num;

    // [New]替换的块是否dirty
    wire dirty, clean;
    assign dirty = cache_dirty[index][replace_num];
    assign clean = ~dirty;

    //读或写
    wire read, write;
    assign write = cpu_data_wr;
    assign read = ~write;

    //FSM
    //IDLE:空闲状态, RM:读取内存, WM:写内存
    parameter IDLE = 2'b00, RM = 2'b01, WM = 2'b10;
    reg [1:0] state;
    always @(posedge clk) begin
        if(rst) begin
            state <= IDLE;
        end
        else begin
            case(state)
                IDLE:   state <= cpu_data_req & miss & dirty ? WM :
                                 cpu_data_req & miss & clean ? RM :
                                 cpu_data_req & hit ? IDLE : IDLE;
                RM:     state <= cache_data_data_ok ? IDLE : RM;
                WM:     state <= cache_data_data_ok ? RM : WM;
            endcase
        end
    end

    // 现在是什么状态
    wire read_req;
    assign read_req = state==RM;  // RM状态发起请求
    wire write_req;  
    assign write_req = state==WM;  // WM状态发起写请求
    
    // 内存读写地址
    wire [31:0] r_address;  // 读地址
    wire [31:0] w_address;  // 写地址
    assign r_address = {cpu_data_addr[31:2], 2'b00};  // 装入地址为cpu读取地址
    // [New] 写回地址为脏数据地址
    wire[TAG_WIDTH-1: 0] cache_old_tag = (replace_num==0) ? cache_tag[index][1*TAG_WIDTH-1:0*TAG_WIDTH] :
                                         (replace_num==1) ? cache_tag[index][2*TAG_WIDTH-1:1*TAG_WIDTH] :
                                         (replace_num==2) ? cache_tag[index][3*TAG_WIDTH-1:2*TAG_WIDTH] :
                                                            cache_tag[index][4*TAG_WIDTH-1:3*TAG_WIDTH] ;
    assign w_address = {cache_old_tag, index, 2'b00};
    
    // 锁存addr_ok, 正在处理
    reg addr_rcv;
    always @(posedge clk) begin
        addr_rcv <= rst ? 1'b0 :
                    cache_data_req & cache_data_addr_ok ? 1'b1 :  // 收到addr
                    cache_data_data_ok ? 1'b0 : addr_rcv;  // 收到data(中间1的过程说明正在对内存进行操作)
    end

    //output to mips core
    // hit了就直接把cache中数据发回, 不然就发回内存的数据
    assign cpu_data_rdata   = hit ? c_block : cache_data_rdata;  
    // 地址是否准备好了
    // hit都可以直接返回(无需read)；miss读写都会读内存(read_req)
    assign cpu_data_addr_ok = (cpu_data_req & hit) | (cache_data_req & cache_data_addr_ok & read_req);  
    // 数据是否准备好了
    // hit都可以直接返回(无需read)；miss读写都会读内存(read_req)
    assign cpu_data_data_ok = (cpu_data_req & hit) | (cache_data_data_ok & read_req);  // 数据是否准备好了

    //output to axi interface
    // 要读或者要写
    assign cache_data_req   = (read_req | write_req) & ~addr_rcv;
    // 下方是否需要写数据
    // 由于在CPU请求写的时候，如果写缺失并且Cache line为clean的，并不一定会去写内存
    assign cache_data_wr    = write_req;
    // 数据的有效字节(为了实现sb, sh)
    assign cache_data_size  = cpu_data_size;
    // [New]究竟要写哪个地址?
    assign cache_data_addr  = write_req ? w_address : r_address;
    // [New]写进去的数据一定是原本Cache line的数据
    wire[31:0] cache_old_data = (replace_num==0) ? cache_block[index][1*DATA_WIDTH-1:0*DATA_WIDTH] : 
                                (replace_num==1) ? cache_block[index][2*DATA_WIDTH-1:1*DATA_WIDTH] :
                                (replace_num==2) ? cache_block[index][3*DATA_WIDTH-1:2*DATA_WIDTH] :
                                                   cache_block[index][4*DATA_WIDTH-1:3*DATA_WIDTH] ;
    assign cache_data_wdata = hit ? c_block : cache_old_data;

//=================================改变Cache====================================
    //保存地址中的tag, index，防止addr发生改变
    reg [TAG_WIDTH-1:0]   tag_save;
    reg [INDEX_WIDTH-1:0] index_save;
    reg [31:0]            wdata_save;
    reg                   wr_save;
    reg [1:0]             replace_num_save;
    // 下面主要是起暂存作用(暂存一个周期)
    always @(posedge clk) begin
        tag_save   <= rst ? 0 :
                      cpu_data_req ? tag : tag_save; // 发起了请求才存成当前tag
        index_save <= rst ? 0 :
                      cpu_data_req ? index : index_save; // 发起了请求才存成当前index
        wdata_save <= rst ? 0 : 
                      cpu_data_req ? cpu_data_wdata : wdata_save; // 发起了请求才存成当前数据
        wr_save    <= rst ? 0 : 
                      cpu_data_req ? write : wr_save; // 发起了请求才存是否要写数据
        replace_num_save <= rst ? 0 : 
                            cpu_data_req ? replace_num : replace_num_save;
        
    end

    wire [31:0] write_cache_data, write_cache_data_wr, mask32;
    wire [3:0] write_mask;

    //根据地址低两位和size，生成写掩码（针对sb，sh等不是写完整一个字的指令），4位对应1个字（4字节）中每个字的写使能
    assign write_mask = cpu_data_size==2'b00 ? // sb
                            (cpu_data_addr[1] ? (cpu_data_addr[0] ? 4'b1000 : 4'b0100):
                                                (cpu_data_addr[0] ? 4'b0010 : 4'b0001)) :
                            (cpu_data_size==2'b01 ? (cpu_data_addr[1] ? 4'b1100 : 4'b0011) : 4'b1111); // sh

    //掩码的使用：位为1的代表需要更新的。
    //位拓展：{8{1'b1}} -> 8'b11111111
    assign mask32 = {{8{write_mask[3]}}, {8{write_mask[2]}}, {8{write_mask[1]}}, {8{write_mask[0]}}};
    // new_data = (old_data & ~mask) | (write_data & mask)
    // [New]原数据是cache line中的数据, 要写入的数据是cpu传过来的数据
    assign write_cache_data = (c_block & ~mask32) | (cpu_data_wdata & mask32);
    // [New]原数据是memory读出的数据, 要写入的数据是cpu传过来的数据(不过锁存了一下)
    assign write_cache_data_wr = (cache_data_rdata & ~mask32) | (wdata_save & mask32);

    wire[31:0] update_data = wr_save ? write_cache_data_wr : cache_data_rdata;

    //更新Cache
    integer t, w, way = 4;
    always @(negedge clk) begin
        if(rst) begin
            cache_valid <= '{default: '0};
            cache_dirty <= '{default: '0};
            cache_pLRU <= '{default: '0};
        end
        else begin
            // [New]命中时写直接更新cache
            // 原来: if(cpu_data_wr & cpu_data_req & hit) begin 少了cpu_data_wr 因为更新LRU是都要做的
            if(cpu_data_req & hit) begin
                // 更新Cache line
                // cache_valid[index][hit_num] <= 1'b1;
                // cache_tag  [index][hit_num] <= tag;
                if(cpu_data_wr) begin
                    cache_dirty[index][hit_num] <= 1;
                    case(hit_num)
                        0: cache_block[index][1*DATA_WIDTH-1:0*DATA_WIDTH] <= write_cache_data;
                        1: cache_block[index][2*DATA_WIDTH-1:1*DATA_WIDTH] <= write_cache_data;
                        2: cache_block[index][3*DATA_WIDTH-1:2*DATA_WIDTH] <= write_cache_data;
                        3: cache_block[index][4*DATA_WIDTH-1:3*DATA_WIDTH] <= write_cache_data;
                        default: ;
                    endcase
                end
                // 更新LRU
                case (hit_num)
                    0 : begin
                        cache_pLRU[index][0] <= 1;
                        cache_pLRU[index][1] <= 1;
                    end
                    1 : begin
                        cache_pLRU[index][0] <= 1;
                        cache_pLRU[index][1] <= 0;
                    end
                    2 : begin
                        cache_pLRU[index][0] <= 0;
                        cache_pLRU[index][2] <= 1;
                    end
                    3 : begin
                        cache_pLRU[index][0] <= 0;
                        cache_pLRU[index][2] <= 0;
                    end
                endcase
            end
            // 不命中时从内存读入数据后更新cache(为什么:见状态图, 在RM阶段看是否是由WM阶段转移过来的(在这个阶段更新cache line), 这也是为什么上面write_cache_data_wr的新数据是wdata_save)
            if (read_req & cache_data_data_ok) begin
                // 更新Cache
                cache_valid[index_save][replace_num] <= 1'b1;
                cache_dirty[index_save][replace_num] <= wr_save;
                case(replace_num)
                    0: begin
                        cache_block[index_save][1*DATA_WIDTH-1:0*DATA_WIDTH] <= update_data;
                        cache_tag  [index_save][1*TAG_WIDTH-1:0*TAG_WIDTH] <= tag_save;
                        cache_pLRU[index_save][0] <= 1;
                        cache_pLRU[index_save][1] <= 1;
                    end 
                    1: begin
                        cache_block[index_save][2*DATA_WIDTH-1:1*DATA_WIDTH] <= update_data;
                        cache_tag  [index_save][2*TAG_WIDTH-1:1*TAG_WIDTH] <= tag_save;
                        cache_pLRU[index_save][0] <= 1;
                        cache_pLRU[index_save][1] <= 0;
                    end 
                    2: begin
                        cache_block[index_save][3*DATA_WIDTH-1:2*DATA_WIDTH] <= update_data;
                        cache_tag  [index_save][3*TAG_WIDTH-1:2*TAG_WIDTH] <= tag_save;
                        cache_pLRU[index_save][0] <= 0;
                        cache_pLRU[index_save][2] <= 1;
                    end 
                    3: begin
                        cache_block[index_save][4*DATA_WIDTH-1:3*DATA_WIDTH] <= update_data;
                        cache_tag  [index_save][4*TAG_WIDTH-1:3*TAG_WIDTH] <= tag_save;
                        cache_pLRU[index_save][0] <= 0;
                        cache_pLRU[index_save][2] <= 0;
                    end 
                    default: ;
                endcase
            end
        end
    end

    // wire debug_valid = cache_valid[10'h197][0];
    // wire debug_valid2 = cache_valid[index_save][replace_num];
    // wire[TAG_WIDTH-1: 0] debug_tag1 = cache_tag[10'h197][2'b00];
    // wire[TAG_WIDTH-1: 0] debug_tag2 = cache_tag[10'h197][2'b01];
    // wire[TAG_WIDTH-1: 0] debug_tag3 = cache_tag[10'h197][2'b10];
    // wire[TAG_WIDTH-1: 0] debug_tag4 = cache_tag[10'h197][2'b11];
    // wire debug_valid3 = cache_valid[index][0];
    // wire [1:0] debug_invaild_num = ~cache_valid[index][0] ? 0 : 3;
endmodule
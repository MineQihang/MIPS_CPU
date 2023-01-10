`timescale 1ns / 1ps

module mips(
    input   wire        clk,
    input   wire        rst,
    input   wire [5:0]  ext_int,

    //instruction
    output  wire        inst_req,
    output  wire        inst_wr,
    output  wire [1:0]  inst_size,
    output  wire [31:0] inst_addr,
    output  wire [31:0] inst_wdata,
    input   wire        inst_addr_ok,
    input   wire        inst_data_ok,
    input   wire [31:0] inst_rdata,

    //data
    output  wire        data_req,
    output  wire        data_wr,
    output  wire [1:0]  data_size,
    output  wire [31:0] data_addr,
    output  wire [31:0] data_wdata,
    input   wire        data_addr_ok,
    input   wire        data_data_ok,
    input   wire [31:0] data_rdata,

    //debug
    output  wire [31:0] debug_wb_pc,      
    output  wire [3:0]  debug_wb_rf_wen,
    output  wire [4:0]  debug_wb_rf_wnum, 
    output  wire [31:0] debug_wb_rf_wdata
);
    //datapath传出来的sram信号
    wire inst_sram_en, inst_en;
    wire [31:0] inst_sram_addr;  // pc
    wire [31:0] inst_sram_rdata;  // instr
    wire i_stall;
    wire data_sram_en;
    wire [31:0] data_sram_addr;  // alu_out
    wire [31:0] data_sram_rdata;
    wire [3:0] data_sram_wen;  // memwrite
    wire [31:0] data_sram_wdata;
    wire d_stall;
    wire stall_all;

    assign inst_sram_en = ~rst & inst_en;

    datapath u_datapath(
        .clk(clk), .rst(rst),
        .ext_int    (ext_int), 
        // instruction
        .pc         (inst_sram_addr),
        .inst       (inst_sram_rdata),
        .inst_en    (inst_en),
        .i_stall    (i_stall), 
        // data
        .addr       (data_sram_addr), 
        .writedata  (data_sram_wdata), 
        .readdata   (data_sram_rdata), 
        .mem_wen    (data_sram_wen), 
        .mem_en     (data_sram_en), 
        .d_stall    (d_stall), 
        // stall
        .stall_all  (stall_all), 
        // debug
        .debug_wb_pc        (debug_wb_pc), 
        .debug_wb_rf_wen    (debug_wb_rf_wen), 
        .debug_wb_rf_wnum   (debug_wb_rf_wnum), 
        .debug_wb_rf_wdata  (debug_wb_rf_wdata)
    );

    //inst sram to sram-like
    i_sram_to_sram_like i_sram_to_sram_like(
        .clk(clk), .rst(rst),
        //sram
        .inst_sram_en   (inst_sram_en),
        .inst_sram_addr (inst_sram_addr),
        .inst_sram_rdata(inst_sram_rdata),
        .i_stall        (i_stall),
        //sram like
        .inst_req       (inst_req), 
        .inst_wr        (inst_wr),
        .inst_size      (inst_size),
        .inst_addr      (inst_addr),   
        .inst_wdata     (inst_wdata),
        .inst_addr_ok   (inst_addr_ok),
        .inst_data_ok   (inst_data_ok),
        .inst_rdata     (inst_rdata),
        .longest_stall  (stall_all)
    );
    //data sram to sram-like
    d_sram_to_sram_like d_sram_to_sram_like(
        .clk(clk), .rst(rst),
        //sram
        .data_sram_en   (data_sram_en),
        .data_sram_addr (data_sram_addr),
        .data_sram_rdata(data_sram_rdata),
        .data_sram_wen  (data_sram_wen),
        .data_sram_wdata(data_sram_wdata),
        .d_stall        (d_stall),
        //sram like
        .data_req       (data_req),    
        .data_wr        (data_wr),
        .data_size      (data_size),
        .data_addr      (data_addr),   
        .data_wdata     (data_wdata),
        .data_addr_ok   (data_addr_ok),
        .data_data_ok   (data_data_ok),
        .data_rdata     (data_rdata),
        .longest_stall  (stall_all)
    );

endmodule

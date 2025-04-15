`include "VX_define.vh"

module VX_alu_dot8 #(
    parameter `STRING INSTANCE_ID = "",
    parameter NUM_LANES = 1
) (
    input wire          clk,
    input wire          reset,

    // Inputs
    VX_execute_if.slave execute_if,

    // Outputs
    VX_commit_if.master commit_if
);
    `UNUSED_SPARAM (INSTANCE_ID)
    
    localparam PID_BITS = `CLOG2(`NUM_THREADS / NUM_LANES);
    localparam PID_WIDTH = `UP(PID_BITS);
    localparam TAG_WIDTH = `UUID_WIDTH + `NW_WIDTH + NUM_LANES + `XLEN + `NR_BITS + 1 + PID_WIDTH + 1 + 1 - 1;
    localparam LATENCY_DOT8 = `LATENCY_DOT8;
    localparam PE_RATIO = 2;
    localparam NUM_PES = `UP(NUM_LANES / PE_RATIO);

    `UNUSED_VAR (execute_if.data.op_type)
    `UNUSED_VAR (execute_if.data.tid)
    `UNUSED_VAR (execute_if.data.rs3_data)

    wire [NUM_LANES-1:0][2*`XLEN-1:0] data_in;

    for (genvar i = 0; i < NUM_LANES; ++i) begin : g_data_in
        assign data_in[i][0 +: `XLEN] = execute_if.data.rs1_data[i];
        assign data_in[i][`XLEN +: `XLEN] = execute_if.data.rs2_data[i];
    end

    wire pe_enable;
    wire [NUM_PES-1:0][2*`XLEN-1:0] pe_data_in;
    wire [NUM_PES-1:0][`XLEN-1:0] pe_data_out;

    // 使用修正后的TAG_WIDTH值
    wire [TAG_WIDTH-1:0] tag_in;
    wire [TAG_WIDTH-1:0] tag_out;
    
    assign tag_in = {
        execute_if.data.uuid,
        execute_if.data.wid,
        execute_if.data.tmask,
        execute_if.data.PC,
        execute_if.data.rd,
        execute_if.data.wb,
        execute_if.data.pid,
        execute_if.data.sop,
        execute_if.data.eop
    };
    
    assign {
        commit_if.data.uuid,
        commit_if.data.wid,
        commit_if.data.tmask,
        commit_if.data.PC,
        commit_if.data.rd,
        commit_if.data.wb,
        commit_if.data.pid,
        commit_if.data.sop,
        commit_if.data.eop
    } = tag_out;

    // PEs time-multiplexing - 使用修正后的TAG_WIDTH
    VX_pe_serializer #(
        .NUM_LANES  (NUM_LANES),
        .NUM_PES    (NUM_PES),
        .LATENCY    (LATENCY_DOT8),
        .DATA_IN_WIDTH (2*`XLEN),
        .DATA_OUT_WIDTH (`XLEN),
        .TAG_WIDTH  (TAG_WIDTH),
        .PE_REG     (1)
    ) pe_serializer (
        .clk        (clk),
        .reset      (reset),
        .valid_in   (execute_if.valid),
        .data_in    (data_in),
        .tag_in     (tag_in),
        .ready_in   (execute_if.ready),
        .pe_enable  (pe_enable),
        .pe_data_out(pe_data_in),
        .pe_data_in (pe_data_out),
        .valid_out  (commit_if.valid),
        .data_out   (commit_if.data.data),
        .tag_out    (tag_out),
        .ready_out  (commit_if.ready)
    );

    // PEs instancing
    for (genvar i = 0; i < NUM_PES; ++i) begin : g_alus
        // 获取输入的32位数据，包含4个int8_t元素
        wire [31:0] a = pe_data_in[i][0 +: 32]; // 第一个操作数（rs1）
        wire [31:0] b = pe_data_in[i][32 +: 32]; // 第二个操作数（rs2）
        
        // 提取每个字节，并作为有符号8位整数处理
        wire signed [7:0] a0 = a[7:0];
        wire signed [7:0] a1 = a[15:8];
        wire signed [7:0] a2 = a[23:16];
        wire signed [7:0] a3 = a[31:24];
        
        wire signed [7:0] b0 = b[7:0];
        wire signed [7:0] b1 = b[15:8];
        wire signed [7:0] b2 = b[23:16];
        wire signed [7:0] b3 = b[31:24];
        
        // 执行四个8位整数的乘法，得到16位结果
        wire signed [15:0] p0 = a0 * b0;
        wire signed [15:0] p1 = a1 * b1;
        wire signed [15:0] p2 = a2 * b2;
        wire signed [15:0] p3 = a3 * b3;
        
        // 将所有乘积显式扩展到32位后累加
        wire signed [31:0] p0_32 = {{16{p0[15]}}, p0};
        wire signed [31:0] p1_32 = {{16{p1[15]}}, p1};
        wire signed [31:0] p2_32 = {{16{p2[15]}}, p2};
        wire signed [31:0] p3_32 = {{16{p3[15]}}, p3};
        
        // 累加32位结果
        wire signed [31:0] result = p0_32 + p1_32 + p2_32 + p3_32;
        
        // 将结果扩展到XLEN（64位），保留符号
        wire [`XLEN-1:0] extended_result = {{(`XLEN-32){result[31]}}, result};
        
        // 使用寄存器缓存结果
        VX_pipe_register #(
            .DATAW  (`XLEN),
            .RESETW (1),
            .DEPTH  (LATENCY_DOT8)
        ) result_buffer (
            .clk      (clk),
            .reset    (reset),
            .enable   (pe_enable),
            .data_in  (extended_result),
            .data_out (pe_data_out[i])
        );
    end

endmodule 


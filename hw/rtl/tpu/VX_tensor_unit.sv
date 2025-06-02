// Copyright © 2019-2023
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`include "VX_define.vh"

module VX_tensor_unit #(
    parameter M         = 4,
    parameter N         = 4,
    parameter K         = 4,
    parameter IN_DATAW  = 16,
    parameter OUT_DATAW = 32,
    parameter LATENCY   = 2
) (
    input  logic                clk,
    input  logic                reset,

    // Control signals
    input  logic                start,
    output logic                busy,
    output logic                done,

    // Input data ports
    input  logic [IN_DATAW-1:0] a_data [M-1:0][K-1:0],  // Matrix A (MxK)
    input  logic [IN_DATAW-1:0] b_data [K-1:0][N-1:0],  // Matrix B (KxN)
    input  logic [OUT_DATAW-1:0] c_data [M-1:0][N-1:0],  // Matrix C (MxN)

    // Output data port
    output logic [OUT_DATAW-1:0] result [M-1:0][N-1:0]   // Result matrix (MxN)
);
    // State machine states
    typedef enum logic [2:0] {
        IDLE,
        LOADING,
        COMPUTING,
        DRAINING,
        DONE_STATE
    } state_t;

    state_t state, next_state;

    // Counters for loading and computation
    logic [$clog2(K+M+N):0] counter;
    logic [$clog2(K+M+N):0] total_cycles;

    // Internal signals
    logic [IN_DATAW-1:0]  a_inputs [M-1:0];
    logic [IN_DATAW-1:0]  b_inputs [N-1:0];
    logic [OUT_DATAW-1:0] c_inputs [M-1:0][N-1:0];
    logic [OUT_DATAW-1:0] c_outputs [M-1:0][N-1:0];

    // Control signals for VX_MMA
    logic mma_enable;
    logic mma_clear;

    // Calculate total cycles needed for computation
    // For systolic array: K cycles to load + (M+N-1) cycles to drain
    assign total_cycles = K + M + N - 1;

    // State machine for controlling the TPU operation
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            counter <= '0;
            busy <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    counter <= '0;
                    busy <= start ? 1'b1 : 1'b0;
                    done <= 1'b0;
                end

                LOADING, COMPUTING, DRAINING: begin
                    counter <= counter + 1'b1;
                    busy <= 1'b1;
                    done <= 1'b0;
                end

                DONE_STATE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end

                default: begin
                    counter <= counter;
                    busy <= busy;
                    done <= done;
                end
            endcase
        end
    end

    // Next state logic
    always_comb begin
        next_state = state;
        case (state)
        IDLE: begin
            if (start) begin
                next_state = LOADING;
            end
        end

        LOADING: begin
            if (counter >= K - 1) begin
                next_state = COMPUTING;
            end
        end

        COMPUTING: begin
            if (counter >= K + M + N - 2) begin
                next_state = DONE_STATE;
            end
        end

        DONE_STATE: begin
            next_state = IDLE;
        end

        default: begin
            next_state = IDLE;
        end
        endcase
    end

    // Control signals for VX_MMA
    assign mma_enable = (state == LOADING || state == COMPUTING);
    assign mma_clear = (state == IDLE);

    // Input dispatch logic - skewed data feeding for systolic array
    genvar i, j;
    generate
        for (i = 0; i < M; i++) begin : gen_a_dispatch
            always_comb begin
                a_inputs[i] = '0;
                if (state == LOADING || state == COMPUTING) begin
                    // Calculate which element of matrix A to feed
                    if (counter >= i && counter < K + i) begin
                        a_inputs[i] = a_data[i][counter - i];
                    end
                end
            end
        end

        for (j = 0; j < N; j++) begin : gen_b_dispatch
            always_comb begin
                b_inputs[j] = '0;
                if (state == LOADING || state == COMPUTING) begin
                    // Calculate which element of matrix B to feed
                    if (counter >= j && counter < K + j) begin
                        b_inputs[j] = b_data[counter - j][j];
                    end
                end
            end
        end

        // Initialize c_inputs with the input c_data
        for (i = 0; i < M; i++) begin : gen_c_inputs_i
            for (j = 0; j < N; j++) begin : gen_c_inputs_j
                assign c_inputs[i][j] = c_data[i][j];
            end
        end
    endgenerate

    // Instantiate the VX_MMA systolic array
    VX_MMA #(
        .M(M),
        .N(N),
        .K(K),
        .IN_DATAW(IN_DATAW),
        .OUT_DATAW(OUT_DATAW),
        .LATENCY(LATENCY)
    ) mma_inst (
        .clk(clk),
        .reset(reset),
        .enable(mma_enable),
        .clear(mma_clear),

        .a_inputs(a_inputs),
        .b_inputs(b_inputs),
        .c_inputs(c_inputs),

        .c_outputs(c_outputs)
    );

    // Output gathering logic
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < M; i++) begin
                for (int j = 0; j < N; j++) begin
                    result[i][j] <= '0;
                end
            end
        end else if (state == DONE_STATE) begin
            // Gather outputs when computation is complete
            for (int i = 0; i < M; i++) begin
                for (int j = 0; j < N; j++) begin
                    result[i][j] <= c_outputs[i][j];
                end
            end
        end
    end

endmodule

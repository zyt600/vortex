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

module VX_fma_unit #(
    parameter IN_DATAW  = 16,
    parameter OUT_DATAW = 16,
    parameter LATENCY   = 2
) (
    input  logic                clk,
    input  logic                reset,
    input  logic                enable,
    input  logic                clear,

    // Data input ports
    input  logic [IN_DATAW-1:0] in_a,
    input  logic [IN_DATAW-1:0] in_b,
    input  logic [OUT_DATAW-1:0] in_c,

    // Data output ports (for passing to adjacent cells)
    output logic [IN_DATAW-1:0] out_a,
    output logic [IN_DATAW-1:0] out_b,
    output logic [OUT_DATAW-1:0] out_c
);
    // Internal signals
    logic [IN_DATAW+IN_DATAW-1:0] mult_result;
    logic [OUT_DATAW-1:0] add_result;

    // Pipeline registers for multiplication and accumulation
    logic [IN_DATAW-1:0] a_pipe [LATENCY-1:0];
    logic [IN_DATAW-1:0] b_pipe [LATENCY-1:0];
    logic [IN_DATAW+IN_DATAW-1:0] mult_pipe [LATENCY-1:0];

    // Multiplication
    assign mult_result = in_a * in_b;

    // Truncate multiplication result if needed
    logic [OUT_DATAW-1:0] mult_truncated;
    assign mult_truncated = mult_pipe[LATENCY-1][OUT_DATAW-1:0];

    // Accumulation with input c
    assign add_result = mult_truncated + in_c;

    // Registers for systolic data flow with proper pipelining
    always_ff @(posedge clk) begin
        if (reset) begin
            // Reset all pipeline registers
            for (int i = 0; i < LATENCY; i++) begin
                a_pipe[i] <= '0;
                b_pipe[i] <= '0;
                mult_pipe[i] <= '0;
            end
            out_c <= '0;
        end else if (enable) begin
            // Input stage of pipeline
            a_pipe[0] <= in_a;
            b_pipe[0] <= in_b;
            mult_pipe[0] <= mult_result;

            // Middle stages of pipeline
            for (int i = 1; i < LATENCY; i++) begin
                a_pipe[i] <= a_pipe[i-1];
                b_pipe[i] <= b_pipe[i-1];
                mult_pipe[i] <= mult_pipe[i-1];
            end

            // Output computation result or clear
            out_c <= clear ? '0 : add_result;
        end
    end

    // Connect outputs to pass data to adjacent cells
    // Use the properly delayed values based on LATENCY
    assign out_a = a_pipe[LATENCY-1];
    assign out_b = b_pipe[LATENCY-1];

endmodule

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

module VX_mma_unit #(
    parameter M         = 4,
    parameter N         = 4,
    parameter K         = 4,
    parameter IN_DATAW  = 16,
    parameter OUT_DATAW = 32,
    parameter LATENCY   = 2
) (
    input  logic                clk,
    input  logic                reset,
    input  logic                enable,
    input  logic                clear,

    // Input data ports
    input  logic [IN_DATAW-1:0] a_inputs [M-1:0],    // Row inputs for matrix A
    input  logic [IN_DATAW-1:0] b_inputs [N-1:0],    // Column inputs for matrix B
    input  logic [OUT_DATAW-1:0] c_inputs [M-1:0][N-1:0], // Initial values for matrix C

    // Output data ports
    output logic [OUT_DATAW-1:0] c_outputs [M-1:0][N-1:0] // Result matrix C
);
    // Internal connections between MAC units
    logic [IN_DATAW-1:0]  a_connections [M:0][N:0];
    logic [IN_DATAW-1:0]  b_connections [M:0][N:0];
    logic [OUT_DATAW-1:0] c_connections [M:0][N:0];

    // Initialize boundary conditions
    for (genvar m = 0; m < M; m++) begin : gen_a_inputs
        assign a_connections[m][0] = a_inputs[m];
    end

    // Top edge: b inputs
    for (genvar n = 0; n < N; n++) begin : gen_b_inputs
        assign b_connections[0][n] = b_inputs[n];
    end

    // Initialize other boundary edges to 0
    for (genvar m = M; m <= M; m++) begin : gen_a_boundary
        for (n = 0; n <= N; n++) begin : gen_a_boundary_n
            assign a_connections[m][n] = '0;
        end
    end

    for (genvar m = 0; m <= M; m++) begin : gen_b_boundary
        for (n = N; n <= N; n++) begin : gen_b_boundary_n
            assign b_connections[m][n] = '0;
        end
    end

    // Connect c_inputs to the first c_connections
    for (genvar m = 0; m < M; m++) begin : gen_c_inputs_m
        for (n = 0; n < N; n++) begin : gen_c_inputs_n
            assign c_connections[m][n] = c_inputs[m][n];
        end
    end

    // Generate the systolic array of MAC units
    for (genvar m = 0; m < M; m++) begin : gen_mac_row
        for (genvar n = 0; n < N; n++) begin : gen_mac_col
            VX_mac_unit #(
                .IN_DATAW(IN_DATAW),
                .OUT_DATAW(OUT_DATAW),
                .LATENCY(LATENCY)
            ) mac_unit (
                .clk(clk),
                .reset(reset),
                .enable(enable),
                .clear(clear),

                .in_a(a_connections[m][n]),
                .in_b(b_connections[m][n]),
                .in_c(c_connections[m][n]),

                .out_a(a_connections[m][n+1]),
                .out_b(b_connections[m+1][n]),
                .out_c(c_connections[m+1][n+1])
            );
        end
    end

    // Connect the outputs
    for (genvar m = 0; m < M; m++) begin : gen_c_outputs_m
        for (genvar n = 0; n < N; n++) begin : gen_c_outputs_n
            assign c_outputs[m][n] = c_connections[m+1][n+1];
        end
    end

endmodule

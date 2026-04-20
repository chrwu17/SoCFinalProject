// csr.sv
// Christian Wu & Eastan Oo
// chrwu@g.hmc.edu & eoo@g.hmc.edu
// 03/31/2026
 
module csr (
    input  logic        clk,
    input  logic        reset,
 
    // Zicntr events
    input  logic        InstrRetiredW,
 
    // Zihpm events
    input  logic [11:0] CSRAdr,
    output logic [31:0] CSRReadData
);
 
    // Zicntr: 64-bit counters
    logic [63:0] cycle_cnt;
    logic [63:0] instret_cnt;
 
    always_ff @(posedge clk) begin
        if (reset) begin
            cycle_cnt   <= 64'd0;
            instret_cnt <= 64'd0;
        end else begin
            cycle_cnt <= cycle_cnt + 1;
            if (InstrRetiredW)
                instret_cnt <= instret_cnt + 1;
        end
    end
 
    always_comb begin
        case (CSRAdr)
            // Zicntr (64-bit, read as low/high halves)
            12'hC00: CSRReadData = cycle_cnt[31:0];
            12'hC80: CSRReadData = cycle_cnt[63:32];
            12'hC01: CSRReadData = cycle_cnt[31:0];    // time == cycle
            12'hC81: CSRReadData = cycle_cnt[63:32];
            12'hC02: CSRReadData = instret_cnt[31:0];
            12'hC82: CSRReadData = instret_cnt[63:32];
 
            // Zihpm high halves (always 0 for 32-bit counters)
            12'hC83: CSRReadData = 32'b0;
            12'hC84: CSRReadData = 32'b0;
            12'hC85: CSRReadData = 32'b0;
            12'hC86: CSRReadData = 32'b0;
            12'hC87: CSRReadData = 32'b0;
            12'hC88: CSRReadData = 32'b0;
            12'hC89: CSRReadData = 32'b0;
            12'hC8A: CSRReadData = 32'b0;
 
            default: CSRReadData = 32'b0;
        endcase
    end
 
endmodule
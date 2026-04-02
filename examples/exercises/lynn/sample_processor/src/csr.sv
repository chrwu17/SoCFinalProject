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
    input  logic        IsAdd,          // hpm3: ADD or ADDI executed
    input  logic        IsBranch,       // hpm4: branch instruction evaluated
    input  logic        IsBranchTaken,  // hpm5: branch actually taken
    input  logic        IsLoad,         // hpm6: load instruction
    input  logic        IsStore,        // hpm7: store instruction
    input  logic        IsJump,         // hpm8: JAL or JALR
    input  logic        IsCSR,          // hpm9: CSR read
    input  logic        IsALUImm,       // hpm10: I-type ALU (non-add immediates)

    input  logic [11:0] CSRAdr,
    output logic [31:0] CSRReadData
);

    logic [63:0] cycle_cnt;
    logic [63:0] instret_cnt;

    logic [63:0] hpm3,  hpm4,  hpm5,  hpm6;
    logic [63:0] hpm7,  hpm8,  hpm9,  hpm10;

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

    always_ff @(posedge clk) begin
        if (reset) begin
            hpm3  <= 64'd0;
            hpm4  <= 64'd0;
            hpm5  <= 64'd0;
            hpm6  <= 64'd0;
            hpm7  <= 64'd0;
            hpm8  <= 64'd0;
            hpm9  <= 64'd0;
            hpm10 <= 64'd0;
        end else begin
            if (IsAdd & InstrRetiredW)         hpm3  <= hpm3  + 1;
            if (IsBranch & InstrRetiredW)      hpm4  <= hpm4  + 1;
            if (IsBranchTaken & InstrRetiredW) hpm5  <= hpm5  + 1;
            if (IsLoad & InstrRetiredW)        hpm6  <= hpm6  + 1;
            if (IsStore & InstrRetiredW)       hpm7  <= hpm7  + 1;
            if (IsJump & InstrRetiredW)        hpm8  <= hpm8  + 1;
            if (IsCSR & InstrRetiredW)         hpm9  <= hpm9  + 1;
            if (IsALUImm & InstrRetiredW)      hpm10 <= hpm10 + 1;
        end
    end

    always_comb begin
        case (CSRAdr)
            // Zicntr
            12'hC00: CSRReadData = cycle_cnt[31:0];
            12'hC80: CSRReadData = cycle_cnt[63:32];
            12'hC01: CSRReadData = cycle_cnt[31:0];    // time == cycle
            12'hC81: CSRReadData = cycle_cnt[63:32];
            12'hC02: CSRReadData = instret_cnt[31:0];
            12'hC82: CSRReadData = instret_cnt[63:32];

            12'hC03: CSRReadData = hpm3[31:0];
            12'hC04: CSRReadData = hpm4[31:0];
            12'hC05: CSRReadData = hpm5[31:0];
            12'hC06: CSRReadData = hpm6[31:0];
            12'hC07: CSRReadData = hpm7[31:0];
            12'hC08: CSRReadData = hpm8[31:0];
            12'hC09: CSRReadData = hpm9[31:0];
            12'hC0A: CSRReadData = hpm10[31:0];

            12'hC83: CSRReadData = hpm3[63:32];
            12'hC84: CSRReadData = hpm4[63:32];
            12'hC85: CSRReadData = hpm5[63:32];
            12'hC86: CSRReadData = hpm6[63:32];
            12'hC87: CSRReadData = hpm7[63:32];
            12'hC88: CSRReadData = hpm8[63:32];
            12'hC89: CSRReadData = hpm9[63:32];
            12'hC8A: CSRReadData = hpm10[63:32];

            default: CSRReadData = 32'b0;
        endcase
    end

endmodule
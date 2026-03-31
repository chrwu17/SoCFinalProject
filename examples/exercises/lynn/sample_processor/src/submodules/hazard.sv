// hazard.sv
// Christian Wu & Eastan Oo
// 03/31/2026
// chrwu@g.hmc.edu eoo@g.hmc.edu

module hazard (
    input   logic [4:0] Rs1D, Rs2D,
    input   logic [4:0] Rs1E, Rs2E, RdE,
    input   logic [4:0] RdM, RdW,
    input   logic       RegWriteM, RegWriteW,
    input   logic       MemReadE,
    input   logic       PCSrcE,
    output  logic       StallF, StallD,
    output  logic       FlushD, FlushE,
    output  logic [1:0] ForwardAE, ForwardBE
);
    logic LoadStall;
    assign LoadStall = MemReadE & ((RdE == Rs1D) | (RdE == Rs2D));

    assign StallF    = LoadStall;
    assign StallD    = LoadStall;
    assign FlushD    = PCSrcE;
    assign FlushE    = LoadStall | PCSrcE;

    always_comb begin
        if      (RegWriteM && RdM != 0 && RdM == Rs1E) ForwardAE = 2'b10;
        else if (RegWriteW && RdW != 0 && RdW == Rs1E) ForwardAE = 2'b01;
        else                                           ForwardAE = 2'b00;
        
        if      (RegWriteM && RdM != 0 && RdM == Rs2E) ForwardBE = 2'b10;
        else if (RegWriteW && RdW != 0 && RdW == Rs2E) ForwardBE = 2'b01;
        else                                           ForwardBE = 2'b00;
    end
endmodule
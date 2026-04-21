// hazard.sv
// Christian Wu & Eastan Oo
// 03/31/2026
// chrwu@g.hmc.edu eoo@g.hmc.edu
 
module hazard (
    input   logic [4:0] Rs1D, Rs2D,
    input   logic [4:0] RdE, RdM, RdW,
    input   logic       RegWriteE, RegWriteM, RegWriteW,
    input   logic       ValidE, ValidM, ValidW, 
    input   logic       MemReadE,
    input   logic       CSRInE,
    input   logic       MulStallE,
    input   logic       PCSrcE,
    output  logic       StallF, StallD, StallE,
    output  logic       FlushD, FlushE,
    output  logic [1:0] ForwardAD, ForwardBD
);

    logic LoadStall, CSRStall;
 
    assign LoadStall = MemReadE && (RdE != 5'd0) && ((RdE == Rs1D) || (RdE == Rs2D));
    assign CSRStall  = CSRInE    && (RdE != 5'd0) && ((RdE == Rs1D) || (RdE == Rs2D));
 
    assign StallF = LoadStall || CSRStall || MulStallE;
    assign StallD = LoadStall || CSRStall || MulStallE;
    assign StallE = MulStallE;  // Hold Execute stage registers during multiply cycle 1
 
    assign FlushD = PCSrcE;
    assign FlushE = LoadStall || CSRStall || PCSrcE;
 
    always_comb begin
        if      (ValidE && RegWriteE && (RdE != 5'd0) && (RdE == Rs1D)) ForwardAD = 2'b10;
        else if (ValidM && RegWriteM && (RdM != 5'd0) && (RdM == Rs1D)) ForwardAD = 2'b01;
        else                                                            ForwardAD = 2'b00;
 
        if      (ValidE && RegWriteE && (RdE != 5'd0) && (RdE == Rs2D)) ForwardBD = 2'b10;
        else if (ValidM && RegWriteM && (RdM != 5'd0) && (RdM == Rs2D)) ForwardBD = 2'b01;
        else                                                            ForwardBD = 2'b00;
    end
endmodule
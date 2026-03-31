// riscvpipelined.sv
// Christian Wu & Eastan Oo
// 03/31/2026
// chrwu@g.hmc.edu eoo@g.hmc.edu

module riscvpipelined (
    input  logic        clk, reset,
    output logic [31:0] PC,
    input  logic [31:0] Instr,       
    output logic [31:0] IEUAdr,      
    input  logic [31:0] ReadData,    
    output logic [31:0] WriteData,
    output logic        MemEn,
    output logic        WriteEn,
    output logic [3:0]  WriteByteEn
);
    logic [31:0] PCF, PCPlus4F;
    logic [31:0] InstrD, PCD, PCPlus4D;
    logic [31:0] RD1D, RD2D, ImmExtD;
    logic [4:0]  Rs1D, Rs2D, RdD;
    logic [31:0] RD1E, RD2E, ImmExtE, PCE, PCPlus4E;
    logic [31:0] SrcAE, SrcBE, ALUResultE, PCTargetE, WriteDataE;
    logic [4:0]  Rs1E, Rs2E, RdE;
    logic [1:0]  ForwardAE, ForwardBE;
    logic        PCSrcE;
    logic [31:0] ALUResultM, WriteDataM, PCPlus4M;
    logic [4:0]  RdM;
    logic [31:0] ALUResultW, ReadDataW, PCPlus4W, ResultW;
    logic [4:0]  RdW;
    logic StallF, StallD, FlushD, FlushE;
endmodule


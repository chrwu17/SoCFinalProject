//ieu.sv
// Christian Wu & Eastan Oo
// 04/01/2026
// chrwu@g.hmc.edu eoo@g.hmc.edu

`include "parameters.svh"

module ieu(
        input  logic        clk, reset,
        input  logic [31:0] Instr,
        input  logic [31:0] PC, PCPlus4,
        output logic        PCSrc,
        output logic [1:0]  MemRW,
        output logic [31:0] IEUAdr,
        output logic [31:0] WriteData,
        input  logic [31:0] LoadResult
    );

    // Internal signals
    logic [2:0]  ALUSelect;
    logic        SubArith;
    logic        ALUResultSrc;
    logic [1:0]  ResultSrc;
    logic        W64;
    logic        Eq, LT, LTU;
    logic [31:0] Result;
    logic [1:0]  ALUSrc;
    logic        RegWrite;
    logic [2:0]  ImmSrc;

    logic        CSREn;
    logic [31:0] CSRReadData;

    logic        MulOp;
    logic [1:0]  MulSel;

    logic        ZBBOp;
    logic [3:0]  ZBBSel;
    logic        ZBBOrcB;

    logic        Branch, Jump;
    logic        BranchTaken;

    logic IsAdd, IsBranch, IsLoad, IsStore, IsJump, IsCSR, IsALUImm;

    controller c(
        .Op(Instr[6:0]),
        .Funct3(Instr[14:12]),
        .Funct7b5(Instr[30]),
        .Funct7(Instr[31:25]),
        .Rs2(Instr[24:20]),
        .ALUResultSrc,
        .ResultSrc,
        .MemRW,
        .MemRead(),
        .ALUSrc,
        .ImmSrc,
        .RegWrite,
        .W64,
        .ALUSelect,
        .SubArith,
        .CSREn,
        .MulOp,
        .MulSel,
        .Branch,
        .Jump,
        .ZBBOp,
        .ZBBSel,
        .ZBBOrcB,
        .IsAdd,
        .IsBranch,
        .IsLoad,
        .IsStore,
        .IsJump,
        .IsCSR,
        .IsALUImm
    );

    datapath dp(
        .clk, .reset,
        .ALUSrc,
        .RegWrite,
        .ImmSrc,
        .ALUSelect,
        .SubArith,
        .ALUResultSrc,
        .ResultSrc,
        .MulOp,
        .MulSel,
        .ZBBOp,
        .ZBBSel,
        .ZBBOrcB,
        .Eq, .LT, .LTU,
        .PC, .PCPlus4,
        .Instr,
        .IEUAdr,
        .WriteData,
        .LoadResult,
        .CSRReadData,
        .Result
    );

    always_comb begin
        case (Instr[14:12])
            3'b000:  BranchTaken = Eq;
            3'b001:  BranchTaken = ~Eq;
            3'b100:  BranchTaken = LT;
            3'b101:  BranchTaken = ~LT;
            3'b110:  BranchTaken = LTU;
            3'b111:  BranchTaken = ~LTU;
            default: BranchTaken = 1'b0;
        endcase
    end

    assign PCSrc = (Branch & BranchTaken) | Jump;

    logic InstrRetired;
    assign InstrRetired = ~reset & (Instr != 32'b0);

    csr csr_unit(
        .clk,
        .reset,
        .InstrRetired (InstrRetired),
        .IsAdd        (IsAdd        & InstrRetired),
        .IsBranch     (IsBranch     & InstrRetired),
        .IsBranchTaken(BranchTaken  & InstrRetired),
        .IsLoad       (IsLoad       & InstrRetired),
        .IsStore      (IsStore      & InstrRetired),
        .IsJump       (IsJump       & InstrRetired),
        .IsCSR        (IsCSR        & InstrRetired),
        .IsALUImm     (IsALUImm     & InstrRetired),
        .CSRAdr       (Instr[31:20]),
        .CSRReadData  (CSRReadData)
    );


endmodule

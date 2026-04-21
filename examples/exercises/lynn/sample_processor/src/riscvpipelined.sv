// riscvpipelined.sv
// Christian Wu & Eastan Oo
// 04/01/2026
// chrwu@g.hmc.edu eoo@g.hmc.edu
 
`include "parameters.svh"
 
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
 
// FETCH SIGNALS
logic [31:0] PCF, PCPlus4F;
 
// DECODE SIGNALS
logic [31:0] InstrD, PCD, PCPlus4D;
logic [31:0] RD1D, RD2D;
logic [31:0] ImmExtD;
logic [4:0]  Rs1D, Rs2D, RdD;
logic        RegWriteD, MemReadD, ALUResultSrcD, CSREnD, MulOpD, BranchD, JumpD;
logic [1:0]  ResultSrcD, MemRWD, ALUSrcD, MulSelD;
logic [2:0]  ImmSrcD, ALUSelectD;
logic        SubArithD;
logic        ZBBOpD;
logic [3:0]  ZBBSelD;
logic        ZBBOrcBD;
logic        IsCSRD;
logic        ValidD;
 
// EXECUTE SIGNALS
logic [31:0] RD1E, RD2E, ImmExtE, PCE, PCPlus4E;
logic [4:0]  Rs1E, Rs2E, RdE;
logic [2:0]  Funct3E;
logic [11:0] CSRAdrE;
logic        RegWriteE, MemReadE, ALUResultSrcE, MulOpE, BranchE, JumpE;
logic [1:0]  ResultSrcE, MemRWE, ALUSrcE, MulSelE;
logic [2:0]  ALUSelectE;
logic        SubArithE;
logic        ZBBOpE;
logic [3:0]  ZBBSelE;
logic        ZBBOrcBE;
logic        ValidE;
logic [31:0] SrcAE, SrcBE;
logic [31:0] ALUResultE, PCTargetE;
logic [31:0] WriteDataE;
logic [31:0] PCTargetMuxE;
logic        PCSrcE;
logic        BranchTakenE;
logic [1:0]  ForwardAE, ForwardBE;
logic        CSRReadE;
 
// MEMORY SIGNALS
logic [31:0] ALUResultM, WriteDataM, PCPlus4M;
logic [4:0]  RdM;
logic [2:0]  Funct3M;
logic [11:0] CSRAdrM;
logic        RegWriteM, MemReadM;
logic [1:0]  MemRWM, ResultSrcM;
logic        ValidM;
 
// WRITEBACK SIGNALS
logic [31:0] Result, ResultW, PCPlus4W, ReadDataW;
logic [4:0]  RdW;
logic [11:0] CSRAdrW;
logic        RegWriteW;
logic [1:0]  ResultSrcW;
logic        InstrRetiredW;
logic        ValidW;
logic [31:0] ALUResultW, ForwardResultW;
 
// HAZARD SIGNALS
logic StallF, StallD, StallE, FlushD, FlushE;
 
// CSR read data
logic [31:0] CSRReadDataW;
 
logic MulStallE;
logic [1:0] MulCntE;
logic MulActiveE;
 
assign MulActiveE = MulOpE && ValidE && !PCSrcE;
 
always_ff @(posedge clk) begin
    if (reset || FlushE || !MulActiveE)
        MulCntE <= 2'd0;
    else if (MulCntE < 2'd2)
        MulCntE <= MulCntE + 2'd1;
end
 
// Stall while multiply is active but hasn't completed both register stages
assign MulStallE = MulActiveE && (MulCntE < 2'd2);
 
// FETCH
assign PC = PCF;
 
ifu ifu(
    .clk,
    .reset,
    .PCSrcE,
    .PCTargetE  (PCTargetMuxE),
    .StallF,
    .PCF,
    .PCPlus4F
);
 
flopenr #(32, 32'h00000013) IF_ID_Instr  (clk, reset | FlushD, ~StallD, Instr,    InstrD);
flopenr #(32)               IF_ID_PC     (clk, reset | FlushD, ~StallD, PCF,      PCD);
flopenr #(32)               IF_ID_PCPlus4(clk, reset | FlushD, ~StallD, PCPlus4F, PCPlus4D);
flopenr #(1)                IF_ID_Valid  (clk, reset | FlushD, ~StallD, 1'b1,     ValidD);
 
// DECODE
assign Rs1D = InstrD[19:15];
assign Rs2D = InstrD[24:20];
assign RdD  = InstrD[11:7];
 
regfile rf(
    .clk,
    .WE3  (RegWriteW & ValidW),
    .A1   (Rs1D),
    .A2   (Rs2D),
    .A3   (RdW),
    .WD3  (ResultW),
    .RD1  (RD1D),
    .RD2  (RD2D)
);
 
extend ext(
    .Instr  (InstrD[31:7]),
    .ImmSrc (ImmSrcD),
    .ImmExt (ImmExtD)
);
 
controller ctrl(
    .Op           (InstrD[6:0]),
    .Funct3       (InstrD[14:12]),
    .Funct7b5     (InstrD[30]),
    .Funct7       (InstrD[31:25]),
    .Rs2          (InstrD[24:20]),
    .ALUResultSrc (ALUResultSrcD),
    .ResultSrc    (ResultSrcD),
    .MemRW        (MemRWD),
    .MemRead      (MemReadD),
    .ALUSrc       (ALUSrcD),
    .ImmSrc       (ImmSrcD),
    .RegWrite     (RegWriteD),
    .W64          (),
    .ALUSelect    (ALUSelectD),
    .SubArith     (SubArithD),
    .CSREn        (CSREnD),
    .MulOp        (MulOpD),
    .MulSel       (MulSelD),
    .ZBBOp        (ZBBOpD),
    .ZBBSel       (ZBBSelD),
    .ZBBOrcB      (ZBBOrcBD),
    .Branch       (BranchD),
    .Jump         (JumpD),
    .IsCSR        (IsCSRD)
);
 
// ID/EX PIPELINE REGISTERS
// Enable is ~StallE so they HOLD during multiply stall cycles
logic EnE;
assign EnE = ~StallE;
 
flopenr #(1)  ID_EX_Valid       (clk, reset | FlushE, EnE, ValidD,        ValidE);
flopenr #(1)  ID_EX_RegWrite    (clk, reset | FlushE, EnE, RegWriteD,     RegWriteE);
flopenr #(1)  ID_EX_MemRead     (clk, reset | FlushE, EnE, MemReadD,      MemReadE);
flopenr #(2)  ID_EX_MemRW       (clk, reset | FlushE, EnE, MemRWD,        MemRWE);
flopenr #(2)  ID_EX_ResultSrc   (clk, reset | FlushE, EnE, ResultSrcD,    ResultSrcE);
flopenr #(2)  ID_EX_ALUSrc      (clk, reset | FlushE, EnE, ALUSrcD,       ALUSrcE);
flopenr #(3)  ID_EX_ALUSelect   (clk, reset | FlushE, EnE, ALUSelectD,    ALUSelectE);
flopenr #(1)  ID_EX_SubArith    (clk, reset | FlushE, EnE, SubArithD,     SubArithE);
flopenr #(1)  ID_EX_ALUResultSrc(clk, reset | FlushE, EnE, ALUResultSrcD, ALUResultSrcE);
flopenr #(1)  ID_EX_Branch      (clk, reset | FlushE, EnE, BranchD,       BranchE);
flopenr #(1)  ID_EX_Jump        (clk, reset | FlushE, EnE, JumpD,         JumpE);
flopenr #(1)  ID_EX_MulOp       (clk, reset | FlushE, EnE, MulOpD,        MulOpE);
flopenr #(2)  ID_EX_MulSel      (clk, reset | FlushE, EnE, MulSelD,       MulSelE);
flopenr #(1)  ID_EX_ZBBOp       (clk, reset | FlushE, EnE, ZBBOpD,        ZBBOpE);
flopenr #(4)  ID_EX_ZBBSel      (clk, reset | FlushE, EnE, ZBBSelD,       ZBBSelE);
flopenr #(1)  ID_EX_ZBBOrcB     (clk, reset | FlushE, EnE, ZBBOrcBD,      ZBBOrcBE);
 
flopenr #(32) ID_EX_RD1         (clk, reset | FlushE, EnE, RD1D,          RD1E);
flopenr #(32) ID_EX_RD2         (clk, reset | FlushE, EnE, RD2D,          RD2E);
flopenr #(32) ID_EX_ImmExt      (clk, reset | FlushE, EnE, ImmExtD,       ImmExtE);
flopenr #(32) ID_EX_PC          (clk, reset | FlushE, EnE, PCD,           PCE);
flopenr #(32) ID_EX_PCPlus4     (clk, reset | FlushE, EnE, PCPlus4D,      PCPlus4E);
 
flopenr #(5)  ID_EX_Rs1         (clk, reset | FlushE, EnE, Rs1D,          Rs1E);
flopenr #(5)  ID_EX_Rs2         (clk, reset | FlushE, EnE, Rs2D,          Rs2E);
flopenr #(5)  ID_EX_Rd          (clk, reset | FlushE, EnE, RdD,           RdE);
 
flopenr #(3)  ID_EX_Funct3      (clk, reset | FlushE, EnE, InstrD[14:12], Funct3E);
flopenr #(12) ID_EX_CSRAdr      (clk, reset | FlushE, EnE, InstrD[31:20], CSRAdrE);
 
logic [1:0] ForwardAD, ForwardBD;
 
// Forward signals also hold during MulStall
floprc #(2) ID_EX_ForwardA (clk, reset, FlushE & ~MulStallE, ForwardAD, ForwardAE);
floprc #(2) ID_EX_ForwardB (clk, reset, FlushE & ~MulStallE, ForwardBD, ForwardBE);
 
 
assign ForwardResultW = (ResultSrcW == 2'b01) ? PCPlus4W : (ResultSrcW == 2'b10) ? ReadDataW : (ResultSrcW == 2'b11) ? CSRReadDataW : ALUResultW;
 
mux3 #(32) ForwardMuxA(RD1E, ForwardResultW, ALUResultM, ForwardAE, SrcAE);
mux3 #(32) ForwardMuxB(RD2E, ForwardResultW, ALUResultM, ForwardBE, WriteDataE);
 
logic [31:0] SrcBfinal;
mux2 #(32) SrcBMux(WriteDataE, ImmExtE, ALUSrcE[0], SrcBfinal);
assign SrcBE = SrcBfinal;
 
logic [31:0] SrcAfinal;
mux2 #(32) SrcAMux(SrcAE, PCE, ALUSrcE[1], SrcAfinal);
 
logic [31:0] ALUResultRaw;
logic [31:0] IEUAdrE;
alu alu(
    .clk       (clk),
    .SrcA      (SrcAfinal),
    .SrcB      (SrcBE),
    .ALUSelect (ALUSelectE),
    .SubArith  (SubArithE),
    .MulOp     (MulOpE),
    .MulSel    (MulSelE),
    .ZBBOp     (ZBBOpE),
    .ZBBSel    (ZBBSelE),
    .ZBBOrcB   (ZBBOrcBE),
    .ALUResult (ALUResultRaw),
    .IEUAdr    (IEUAdrE)
);
 
assign ALUResultE = ALUResultSrcE ? ImmExtE : ALUResultRaw;
 
adder BranchAdder(PCE, ImmExtE, PCTargetE);
 
logic EqE, LTE, LTUE;
cmp cmpE(.R1(SrcAE), .R2(WriteDataE), .Eq(EqE), .LT(LTE), .LTU(LTUE));
 
always_comb
    case (Funct3E)
        3'b000:  BranchTakenE = EqE;       // BEQ
        3'b001:  BranchTakenE = ~EqE;      // BNE
        3'b100:  BranchTakenE = LTE;       // BLT
        3'b101:  BranchTakenE = ~LTE;      // BGE
        3'b110:  BranchTakenE = LTUE;      // BLTU
        3'b111:  BranchTakenE = ~LTUE;     // BGEU
        default: BranchTakenE = 1'b0;
    endcase
 
assign PCSrcE = (BranchE & BranchTakenE) | JumpE;
assign PCTargetMuxE = (JumpE & ~ALUSrcE[1]) ? {IEUAdrE[31:1], 1'b0} : PCTargetE;
 
// EX/MEM PIPELINE REGISTER
// During MulStall, insert bubble into Memory stage
logic        ValidE_toM;
logic        RegWriteE_toM;
logic [1:0]  MemRWE_toM;
logic        MemReadE_toM;
 
assign ValidE_toM    = MulStallE ? 1'b0 : ValidE;
assign RegWriteE_toM = MulStallE ? 1'b0 : RegWriteE;
assign MemRWE_toM    = MulStallE ? 2'b0 : MemRWE;
assign MemReadE_toM  = MulStallE ? 1'b0 : MemReadE;
 
flopr #(1)  EX_MEM_Valid        (clk, reset, ValidE_toM,    ValidM);
flopr #(1)  EX_MEM_RegWrite     (clk, reset, RegWriteE_toM, RegWriteM);
flopr #(2)  EX_MEM_MemRW        (clk, reset, MemRWE_toM,    MemRWM);
flopr #(2)  EX_MEM_ResultSrc    (clk, reset, ResultSrcE,    ResultSrcM);
 
flopr #(32) EX_MEM_ALUResult    (clk, reset, ALUResultE,    ALUResultM);
flopr #(32) EX_MEM_WriteData    (clk, reset, WriteDataE,    WriteDataM);
flopr #(32) EX_MEM_PCPlus4      (clk, reset, PCPlus4E,      PCPlus4M);
flopr #(5)  EX_MEM_Rd           (clk, reset, RdE,           RdM);
flopr #(3)  EX_MEM_Funct3       (clk, reset, Funct3E,       Funct3M);
flopr #(12) EX_MEM_CSRAdr       (clk, reset, CSRAdrE,       CSRAdrM);
 
// MEMORY STAGE
logic [31:0] LoadResultM;
 
lsu lsu(
    .ALUResult   (ALUResultM),
    .WriteData   (WriteDataM),
    .ReadData    (ReadData),
    .Funct3      (Funct3M),
    .MemRW       (MemRWM),
    .IEUAdr      (IEUAdr),
    .StoreData   (WriteData),
    .LoadResult  (LoadResultM),
    .WriteByteEn (WriteByteEn),
    .MemEn       (MemEn)
);
 
assign WriteEn = MemRWM[0];
 
// MEM/WB PIPELINE REGISTER
flopr #(1)  MEM_WB_Valid        (clk, reset, ValidM,        ValidW);
flopr #(1)  MEM_WB_RegWrite    (clk, reset, RegWriteM,     RegWriteW);
flopr #(2)  MEM_WB_ResultSrc    (clk, reset, ResultSrcM,    ResultSrcW);
flopr #(32) MEM_WB_ReadData    (clk, reset, LoadResultM,   ReadDataW);
flopr #(32) MEM_WB_PCPlus4     (clk, reset, PCPlus4M,      PCPlus4W);
flopr #(5)  MEM_WB_Rd          (clk, reset, RdM,            RdW);
flopr #(32) MEM_WB_ALUResult   (clk, reset, ALUResultM,    ALUResultW);
flopr #(12) MEM_WB_CSRAdr      (clk, reset, CSRAdrM,       CSRAdrW); 
// WRITEBACK STAGE
always_comb begin
      case (ResultSrcW)
          2'b01:   Result = PCPlus4W;
          2'b10:   Result = ReadDataW;
          2'b11:   Result = CSRReadDataW;
          default: Result = ALUResultW;
      endcase
  end
 
assign ResultW = Result;
 
assign InstrRetiredW = ValidW;

csr csr_unit(
    .clk,
    .reset,
    .InstrRetiredW  (InstrRetiredW),
    .CSRAdr         (CSRAdrW),
    .CSRReadData    (CSRReadDataW)
);

logic CSRInE;
flopenr #(1) ID_EX_IsCSR (clk, reset | FlushE, EnE, IsCSRD, CSRInE);
 
// HAZARD UNIT
hazard hazard_unit(
    .Rs1D, .Rs2D,
    .RdE,
    .RdM,  .RdW,
    .RegWriteE, .RegWriteM, .RegWriteW,
    .ValidE, .ValidM, .ValidW,
    .MemReadE,
    .CSRInE,
    .MulStallE,
    .PCSrcE,
    .StallF, .StallD, .StallE,
    .FlushD, .FlushE,
    .ForwardAD, .ForwardBD
);
 
endmodule
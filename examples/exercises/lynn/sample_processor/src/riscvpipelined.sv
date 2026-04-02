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
logic        IsAddD, IsBranchD, IsLoadD, IsStoreD, IsJumpD, IsCSRD, IsALUImmD;
 
// EXECUTE SIGNALS
logic [31:0] RD1E, RD2E, ImmExtE, PCE, PCPlus4E;
logic [4:0]  Rs1E, Rs2E, RdE;
logic [2:0]  Funct3E;         
logic [11:0] CSRAdrE;         
logic        RegWriteE, MemReadE, ALUResultSrcE, CSREnE, MulOpE, BranchE, JumpE;
logic [1:0]  ResultSrcE, MemRWE, ALUSrcE, MulSelE;
logic [2:0]  ALUSelectE;
logic        SubArithE;
logic        IsAddE, IsBranchE, IsLoadE, IsStoreE, IsJumpE, IsCSRE, IsALUImmE;
logic [31:0] SrcAE, SrcBE;
logic [31:0] ALUResultE, PCTargetE;
logic [31:0] WriteDataE;
logic [31:0] PCTargetMuxE;
logic        PCSrcE;
logic        BranchTakenE;
logic [1:0]  ForwardAE, ForwardBE;
 

// MEMORY SIGNALS
logic [31:0] ALUResultM, WriteDataM, PCPlus4M;
logic [31:0] ForwardResultM;
logic [4:0]  RdM;
logic [2:0]  Funct3M;
logic [11:0] CSRAdrM;
logic        RegWriteM, MemReadM;
logic [1:0]  ResultSrcM, MemRWM;
logic        IsAddM, IsBranchM, IsBranchTakenM, IsLoadM, IsStoreM;
logic        IsJumpM, IsCSRM, IsALUImmM;
 

// WRITEBACK SIGNALS
logic [31:0] ALUResultW, ReadDataW, PCPlus4W, ResultW;
logic [4:0]  RdW;
logic [11:0] CSRAdrW;
logic        RegWriteW;
logic [1:0]  ResultSrcW;
logic        IsAddW, IsBranchW, IsBranchTakenW, IsLoadW, IsStoreW;
logic        IsJumpW, IsCSRW, IsALUImmW;
logic        InstrRetiredW;
 
// HAZARD SIGNALS
logic StallF, StallD, FlushD, FlushE;
 
// CSR read data
logic [31:0] CSRReadDataW;
 

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
 

// DECODE
assign Rs1D = InstrD[19:15];
assign Rs2D = InstrD[24:20];
assign RdD  = InstrD[11:7];

regfile rf(
    .clk,
    .WE3  (RegWriteW),
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
    .Op         (InstrD[6:0]),
    .Funct3     (InstrD[14:12]),
    .Funct7b5   (InstrD[30]),
    .Funct7     (InstrD[31:25]),
    .ALUResultSrc (ALUResultSrcD),
    .ResultSrc  (ResultSrcD),
    .MemRW      (MemRWD),
    .MemRead    (MemReadD),
    .ALUSrc     (ALUSrcD),
    .ImmSrc     (ImmSrcD),
    .RegWrite   (RegWriteD),
    .W64        (),             // unused in RV32
    .ALUSelect  (ALUSelectD),
    .SubArith   (SubArithD),
    .CSREn      (CSREnD),
    .MulOp      (MulOpD),
    .MulSel     (MulSelD),
    .Branch     (BranchD),
    .Jump       (JumpD),
    .IsAdd      (IsAddD),
    .IsBranch   (IsBranchD),
    .IsLoad     (IsLoadD),
    .IsStore    (IsStoreD),
    .IsJump     (IsJumpD),
    .IsCSR      (IsCSRD),
    .IsALUImm   (IsALUImmD)
);

flopenr #(1)  ID_EX_RegWrite    (clk, reset | FlushE, 1'b1, RegWriteD,     RegWriteE);
flopenr #(1)  ID_EX_MemRead     (clk, reset | FlushE, 1'b1, MemReadD,      MemReadE);
flopenr #(2)  ID_EX_MemRW       (clk, reset | FlushE, 1'b1, MemRWD,        MemRWE);
flopenr #(2)  ID_EX_ResultSrc   (clk, reset | FlushE, 1'b1, ResultSrcD,    ResultSrcE);
flopenr #(2)  ID_EX_ALUSrc      (clk, reset | FlushE, 1'b1, ALUSrcD,       ALUSrcE);
flopenr #(3)  ID_EX_ALUSelect   (clk, reset | FlushE, 1'b1, ALUSelectD,    ALUSelectE);
flopenr #(1)  ID_EX_SubArith    (clk, reset | FlushE, 1'b1, SubArithD,     SubArithE);
flopenr #(1)  ID_EX_ALUResultSrc(clk, reset | FlushE, 1'b1, ALUResultSrcD, ALUResultSrcE);
flopenr #(1)  ID_EX_Branch      (clk, reset | FlushE, 1'b1, BranchD,       BranchE);
flopenr #(1)  ID_EX_Jump        (clk, reset | FlushE, 1'b1, JumpD,         JumpE);
flopenr #(1)  ID_EX_CSREn       (clk, reset | FlushE, 1'b1, CSREnD,        CSREnE);
flopenr #(1)  ID_EX_MulOp       (clk, reset | FlushE, 1'b1, MulOpD,        MulOpE);
flopenr #(2)  ID_EX_MulSel      (clk, reset | FlushE, 1'b1, MulSelD,       MulSelE);
 
flopenr #(32) ID_EX_RD1         (clk, reset | FlushE, 1'b1, RD1D,          RD1E);
flopenr #(32) ID_EX_RD2         (clk, reset | FlushE, 1'b1, RD2D,          RD2E);
flopenr #(32) ID_EX_ImmExt      (clk, reset | FlushE, 1'b1, ImmExtD,       ImmExtE);
flopenr #(32) ID_EX_PC          (clk, reset | FlushE, 1'b1, PCD,           PCE);
flopenr #(32) ID_EX_PCPlus4     (clk, reset | FlushE, 1'b1, PCPlus4D,      PCPlus4E);
 
flopenr #(5)  ID_EX_Rs1         (clk, reset | FlushE, 1'b1, Rs1D,          Rs1E);
flopenr #(5)  ID_EX_Rs2         (clk, reset | FlushE, 1'b1, Rs2D,          Rs2E);
flopenr #(5)  ID_EX_Rd          (clk, reset | FlushE, 1'b1, RdD,           RdE);
 
flopenr #(3)  ID_EX_Funct3      (clk, reset | FlushE, 1'b1, InstrD[14:12], Funct3E);
 
flopenr #(12) ID_EX_CSRAdr      (clk, reset | FlushE, 1'b1, InstrD[31:20], CSRAdrE);
 
flopenr #(1)  ID_EX_IsAdd       (clk, reset | FlushE, 1'b1, IsAddD,        IsAddE);
flopenr #(1)  ID_EX_IsBranch    (clk, reset | FlushE, 1'b1, IsBranchD,     IsBranchE);
flopenr #(1)  ID_EX_IsLoad      (clk, reset | FlushE, 1'b1, IsLoadD,       IsLoadE);
flopenr #(1)  ID_EX_IsStore     (clk, reset | FlushE, 1'b1, IsStoreD,      IsStoreE);
flopenr #(1)  ID_EX_IsJump      (clk, reset | FlushE, 1'b1, IsJumpD,       IsJumpE);
flopenr #(1)  ID_EX_IsCSR       (clk, reset | FlushE, 1'b1, IsCSRD,        IsCSRE);
flopenr #(1)  ID_EX_IsALUImm    (clk, reset | FlushE, 1'b1, IsALUImmD,     IsALUImmE);
 
// EXECUTE STAGE
mux3 #(32) ForwardMuxA(RD1E, ResultW, ForwardResultM, ForwardAE, SrcAE);
mux3 #(32) ForwardMuxB(RD2E, ResultW, ForwardResultM, ForwardBE, WriteDataE);

logic [31:0] SrcBfinal;
mux2 #(32) SrcBMux(WriteDataE, ImmExtE, ALUSrcE[0], SrcBfinal);
assign SrcBE = SrcBfinal;
 
logic [31:0] SrcAfinal;
mux2 #(32) SrcAMux(SrcAE, PCE, ALUSrcE[1], SrcAfinal);
 
logic [31:0] ALUResultRaw;
logic [31:0] IEUAdrE;
alu alu(
    .SrcA      (SrcAfinal),
    .SrcB      (SrcBE),
    .ALUSelect (ALUSelectE),
    .SubArith  (SubArithE),
    .MulOp     (MulOpE),
    .MulSel    (MulSelE),
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
flopr #(1)  EX_MEM_RegWrite   (clk, reset, RegWriteE,   RegWriteM);
flopr #(1)  EX_MEM_MemRead    (clk, reset, MemReadE,    MemReadM);
flopr #(2)  EX_MEM_MemRW      (clk, reset, MemRWE,      MemRWM);
flopr #(2)  EX_MEM_ResultSrc  (clk, reset, ResultSrcE,  ResultSrcM);
 
flopr #(32) EX_MEM_ALUResult  (clk, reset, ALUResultE,  ALUResultM);
flopr #(32) EX_MEM_WriteData  (clk, reset, WriteDataE,  WriteDataM);
flopr #(32) EX_MEM_PCPlus4    (clk, reset, PCPlus4E,    PCPlus4M);
flopr #(5)  EX_MEM_Rd         (clk, reset, RdE,         RdM);
flopr #(3)  EX_MEM_Funct3     (clk, reset, Funct3E,     Funct3M);
flopr #(12) EX_MEM_CSRAdr     (clk, reset, CSRAdrE,     CSRAdrM);
 
flopr #(1)  EX_MEM_IsAdd        (clk, reset, IsAddE,        IsAddM);
flopr #(1)  EX_MEM_IsBranch     (clk, reset, IsBranchE,     IsBranchM);
flopr #(1)  EX_MEM_IsBranchTaken(clk, reset, BranchTakenE,  IsBranchTakenM);
flopr #(1)  EX_MEM_IsLoad       (clk, reset, IsLoadE,       IsLoadM);
flopr #(1)  EX_MEM_IsStore      (clk, reset, IsStoreE,      IsStoreM);
flopr #(1)  EX_MEM_IsJump       (clk, reset, IsJumpE,       IsJumpM);
flopr #(1)  EX_MEM_IsCSR        (clk, reset, IsCSRE,        IsCSRM);
flopr #(1)  EX_MEM_IsALUImm     (clk, reset, IsALUImmE,     IsALUImmM);

logic CSRReadE;
assign CSRReadE = (ResultSrcE == 2'b11);

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
assign ForwardResultM = (ResultSrcM == 2'b10) ? LoadResultM : ALUResultM;

// MEM/WB PIPELINE REGISTER
flopr #(1)  MEM_WB_RegWrite   (clk, reset, RegWriteM,    RegWriteW);
flopr #(2)  MEM_WB_ResultSrc  (clk, reset, ResultSrcM,   ResultSrcW);

flopr #(32) MEM_WB_ALUResult  (clk, reset, ALUResultM,   ALUResultW);
flopr #(32) MEM_WB_ReadData   (clk, reset, LoadResultM,  ReadDataW);
flopr #(32) MEM_WB_PCPlus4    (clk, reset, PCPlus4M,     PCPlus4W);
flopr #(5)  MEM_WB_Rd         (clk, reset, RdM,          RdW);
flopr #(12) MEM_WB_CSRAdr     (clk, reset, CSRAdrM,      CSRAdrW);
 
flopr #(1) MEM_WB_IsAdd        (clk, reset, IsAddM,         IsAddW);
flopr #(1) MEM_WB_IsBranch     (clk, reset, IsBranchM,      IsBranchW);
flopr #(1) MEM_WB_IsBranchTaken(clk, reset, IsBranchTakenM, IsBranchTakenW);
flopr #(1) MEM_WB_IsLoad       (clk, reset, IsLoadM,        IsLoadW);
flopr #(1) MEM_WB_IsStore      (clk, reset, IsStoreM,       IsStoreW);
flopr #(1) MEM_WB_IsJump       (clk, reset, IsJumpM,        IsJumpW);
flopr #(1) MEM_WB_IsCSR        (clk, reset, IsCSRM,          IsCSRW);
flopr #(1) MEM_WB_IsALUImm     (clk, reset, IsALUImmM,      IsALUImmW);
 

// WRITEBACK STAGE
always_comb
    case (ResultSrcW)
        2'b00:   ResultW = ALUResultW;    // ALU result
        2'b01:   ResultW = PCPlus4W;      // JAL/JALR return address
        2'b10:   ResultW = ReadDataW;     // load result
        2'b11:   ResultW = CSRReadDataW;  // CSR read
        default: ResultW = ALUResultW;
    endcase
 
assign InstrRetiredW = RegWriteW | IsStoreW | IsBranchW;

csr csr_unit(
    .clk,
    .reset,
    .InstrRetiredW  (InstrRetiredW),
    .IsAdd          (IsAddW),
    .IsBranch       (IsBranchW),
    .IsBranchTaken  (IsBranchTakenW),
    .IsLoad         (IsLoadW),
    .IsStore        (IsStoreW),
    .IsJump         (IsJumpW),
    .IsCSR          (IsCSRW),
    .IsALUImm       (IsALUImmW),
    .CSRAdr         (CSRAdrW),
    .CSRReadData    (CSRReadDataW)
);
 

// HAZARD UNIT
hazard hazard_unit(
    .Rs1D, .Rs2D,
    .Rs1E, .Rs2E, .RdE,
    .RdM,  .RdW,
    .RegWriteM, .RegWriteW,
    .MemReadE,
    .CSRReadE,
    .PCSrcE,
    .StallF, .StallD,
    .FlushD, .FlushE,
    .ForwardAE, .ForwardBE
);
 
endmodule
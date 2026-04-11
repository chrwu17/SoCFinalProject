// riscvsingle.sv
// RISC-V single-cycle processor
// David_Harris@hmc.edu 2020

module datapath(
        input  logic        clk, reset,
        input  logic [1:0]  ALUSrc,
        input  logic        RegWrite,
        input  logic [2:0]  ImmSrc,
        input  logic [2:0]  ALUSelect,
        input  logic        SubArith,
        input  logic        ALUResultSrc,
        input  logic [1:0]  ResultSrc,
        input  logic        MulOp,
        input  logic [1:0]  MulSel,
        input  logic        ZBBOp,
        input  logic [3:0]  ZBBSel,
        input  logic        ZBBOrcB,
        output logic        Eq, LT, LTU,
        input  logic [31:0] PC, PCPlus4,
        input  logic [31:0] Instr,
        output logic [31:0] IEUAdr,
        output logic [31:0] WriteData,
        input  logic [31:0] LoadResult,
        input  logic [31:0] CSRReadData,
        output logic [31:0] Result
    );

    logic [31:0] R1, R2, SrcA, SrcB;
    logic [31:0] ImmExt;
    logic [31:0] ALUResult, IEUResult;

    regfile rf(
        .clk, .WE3(RegWrite),
        .A1(Instr[19:15]), .A2(Instr[24:20]), .A3(Instr[11:7]),
        .WD3(Result), .RD1(R1), .RD2(R2)
    );

    extend ext(.Instr(Instr[31:7]), .ImmSrc, .ImmExt);

    cmp cmp(.R1, .R2, .Eq, .LT, .LTU);

    mux2 #(32) srcamux(R1, PC, ALUSrc[1], SrcA);
    mux2 #(32) srcbmux(R2, ImmExt, ALUSrc[0], SrcB);

    alu alu(.SrcA, .SrcB, .ALUSelect, .SubArith, .MulOp, .MulSel, .ZBBOp, .ZBBSel, .ZBBOrcB, .ALUResult, .IEUAdr);

    assign IEUResult = ALUResultSrc ? ImmExt : ALUResult;

    always_comb
        case (ResultSrc)
            2'b00:   Result = IEUResult;
            2'b01:   Result = PCPlus4;
            2'b10:   Result = LoadResult;
            2'b11:   Result = CSRReadData;
            default: Result = IEUResult;
        endcase

    assign WriteData = R2;
endmodule

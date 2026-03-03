// riscvsingle.sv
// RISC-V single-cycle processor
// David_Harris@hmc.edu 2020

module datapath(
        input  logic        clk, reset,
        input  logic [1:0]  ALUSrc,        // {ALUSrcA, ALUSrcB}
        input  logic        RegWrite,
        input  logic [2:0]  ImmSrc,
        input  logic [2:0]  ALUSelect,
        input  logic        SubArith,
        input  logic        ALUResultSrc,
        input  logic [1:0]  ResultSrc,
        input  logic        MulOp,
        input  logic [1:0]  MulSel,
        output logic        Eq, LT, LTU,
        input  logic [31:0] PC, PCPlus4,
        input  logic [31:0] Instr,
        output logic [31:0] IEUAdr,
        output logic [31:0] WriteData,
        input  logic [31:0] LoadResult,
        input  logic [31:0] CSRResult,
        output logic [31:0] Result
    );

    logic [31:0] R1, R2, SrcA, SrcB;
    logic [31:0] ImmExt;
    logic [31:0] ALUResult, IEUResult;

    // Register file
    regfile rf(
        .clk, .WE3(RegWrite),
        .A1(Instr[19:15]), .A2(Instr[24:20]), .A3(Instr[11:7]),
        .WD3(Result), .RD1(R1), .RD2(R2)
    );

    // Extend
    extend ext(.Instr(Instr[31:7]), .ImmSrc, .ImmExt);

    // Comparator — inputs direct from register file, not SrcA/B
    cmp cmp(.R1, .R2, .Eq, .LT, .LTU);

    // SrcA mux — ALUSrc[1]: 0=R1, 1=PC
    mux2 #(32) srcamux(R1, PC, ALUSrc[1], SrcA);

    // SrcB mux — ALUSrc[0]: 0=R2, 1=ImmExt
    mux2 #(32) srcbmux(R2, ImmExt, ALUSrc[0], SrcB);

    // ALU
    alu alu(.SrcA, .SrcB, .ALUSelect, .SubArith, .MulOp, .MulSel, .ALUResult, .IEUAdr);

    // IEUResult
    assign IEUResult = ALUResultSrc ? ImmExt : ALUResult;

    // Result
    always_comb
        case (ResultSrc)
            2'b00:   Result = IEUResult;   // normal
            2'b01:   Result = PCPlus4;     // jal/jalr return address
            2'b10:   Result = LoadResult;  // load
            2'b11:   Result = CSRResult;
            default: Result = IEUResult;
        endcase

    assign WriteData = R2;
endmodule

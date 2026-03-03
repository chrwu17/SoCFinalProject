// riscvsingle.sv
// RISC-V single-cycle processor
// David_Harris@hmc.edu 2020

module alu(
        input   logic [31:0]    SrcA, SrcB,
        input   logic [2:0]     ALUSelect,
        input   logic           SubArith,
        input   logic           MulOp,
        input   logic [1:0]     MulSel,
        output  logic [31:0]    ALUResult, IEUAdr
    );

    logic [31:0] CondInvb, Sum, SLT, SLTU;
    logic        Overflow, Neg, LT;
    logic [4:0]  shiftAmount;

    // Add support for new instructions for Lab 3
    assign shiftAmount = SrcB[4:0];
    assign SLTU = {31'b0, ($unsigned(SrcA) < $unsigned(SrcB))};

    // Add or subtract
    assign CondInvb = SubArith ? ~SrcB : SrcB;
    assign Sum = SrcA + CondInvb + {{(31){1'b0}}, SubArith};
    assign IEUAdr = Sum; // Send this out to IFU and LSU

    // Set less than based on subtraction result
    assign Overflow = (SrcA[31] ^ SrcB[31]) & (SrcA[31] ^ Sum[31]);
    assign Neg = Sum[31];
    assign LT = Neg ^ Overflow;
    assign SLT = {31'b0, LT};

    // Zmmul
    logic [63:0] mul_ss, mul_su, mul_uu;
    logic [31:0] mul_result;

    assign mul_ss = $signed({{32{SrcA[31]}}, SrcA}) * $signed({{32{SrcB[31]}}, SrcB});
    assign mul_su = $signed({{32{SrcA[31]}}, SrcA}) * $unsigned({32'b0, SrcB});
    assign mul_uu = $unsigned({32'b0, SrcA})        * $unsigned({32'b0, SrcB});

    always_comb begin
        case (MulSel)
            2'b00: mul_result = mul_ss[31:0];   // MUL    lower 32 (ss == uu for low half)
            2'b01: mul_result = mul_ss[63:32];  // MULH   upper signed×signed
            2'b10: mul_result = mul_su[63:32];  // MULHSU upper signed×unsigned
            2'b11: mul_result = mul_uu[63:32];  // MULHU  upper unsigned×unsigned
            default: mul_result = 32'bx;
        endcase
    end

    logic [31:0] alu_result;

    always_comb begin
        case (ALUSelect)
            3'b000: alu_result = Sum;
            3'b001: alu_result = SrcA << shiftAmount;
            3'b010: alu_result = SLT;
            3'b011: alu_result = SLTU;
            3'b100: alu_result = SrcA ^ SrcB;
            3'b101: alu_result = SubArith ?
                $unsigned($signed(SrcA) >>> shiftAmount) :
                SrcA >> shiftAmount;
            3'b110: alu_result = SrcA | SrcB;
            3'b111: alu_result = SrcA & SrcB;
            default: alu_result = 32'bx;
        endcase
    end

    assign ALUResult = MulOp ? mul_result : alu_result;
endmodule

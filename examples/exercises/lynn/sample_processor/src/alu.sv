// alu.sv
// Christian Wu & Eastan Oo
// 04/10/2026
// chrwu@g.hmc.edu eoo@g.hmc.edu

module alu(
        input   logic [31:0]    SrcA, SrcB,
        input   logic [2:0]     ALUSelect,
        input   logic           SubArith,
        input   logic           MulOp,
        input   logic [1:0]     MulSel,
        input   logic           ZBBOp,
        input   logic [3:0]     ZBBSel,
        input   logic           ZBBOrcB, 
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

    // ZBB extension

    // CLZ: count leading zeros.
    logic [5:0] clz_count;
    always_comb begin
        clz_count = 6'd32;                   // default: all zeros
        for (int i = 0; i <= 31; i++)        // low to high — highest set bit wins
            if (SrcA[i]) clz_count = 6'(31 - i);
    end

    // CTZ: count trailing zeros.
    logic [5:0] ctz_count;
    always_comb begin
        ctz_count = 6'd32;                   // default: all zeros
        for (int i = 31; i >= 0; i--)        // high to low — lowest set bit wins
            if (SrcA[i]) ctz_count = 6'(i);
    end

    // CPOP: population count — order doesn't matter, just accumulate
    logic [5:0] cpop_count;
    always_comb begin
        cpop_count = 6'd0;
        for (int i = 0; i < 32; i++)
            cpop_count = cpop_count + {5'b0, SrcA[i]};
    end

    // ORC.B: each byte → 0xFF if any bit set, else 0x00
    logic [31:0] orcb_result;
    assign orcb_result = {
        {8{|SrcA[31:24]}},
        {8{|SrcA[23:16]}},
        {8{|SrcA[15:8]}},
        {8{|SrcA[7:0]}}
    };

    // REV8: byte-reverse the 32-bit word
    logic [31:0] rev8_result;
    assign rev8_result = {SrcA[7:0], SrcA[15:8], SrcA[23:16], SrcA[31:24]};

    // ROL / ROR — rotation by shiftAmount = SrcB[4:0]
    // rot_comp = 32 - shiftAmount (6-bit to handle shiftAmount=0 safely)
    logic [31:0] rol_result, ror_result;
    logic [5:0]  rot_comp;
    assign rot_comp  = 6'd32 - {1'b0, shiftAmount};
    assign rol_result = (SrcA << shiftAmount) | (SrcA >> rot_comp[4:0]);
    assign ror_result = (SrcA >> shiftAmount) | (SrcA << rot_comp[4:0]);

    logic [31:0] zbb_result;
    always_comb begin
        case (ZBBSel)
            4'd0:    zbb_result = SrcA & ~SrcB;
            4'd1:    zbb_result = SrcA | ~SrcB;
            4'd2:    zbb_result = ~(SrcA ^ SrcB);
            4'd3:    zbb_result = ($signed(SrcA)   < $signed(SrcB))   ? SrcA : SrcB; // MIN
            4'd4:    zbb_result = ($signed(SrcA)   > $signed(SrcB))   ? SrcA : SrcB; // MAX
            4'd5:    zbb_result = ($unsigned(SrcA) < $unsigned(SrcB)) ? SrcA : SrcB; // MINU
            4'd6:    zbb_result = ($unsigned(SrcA) > $unsigned(SrcB)) ? SrcA : SrcB; // MAXU
            4'd7:    zbb_result = {16'b0, SrcA[15:0]};                               // ZEXT.H
            4'd8:    zbb_result = rol_result;
            4'd9:    zbb_result = ror_result;
            4'd10:   zbb_result = {26'b0, clz_count};
            4'd11:   zbb_result = {26'b0, ctz_count};
            4'd12:   zbb_result = {26'b0, cpop_count};
            4'd13:   zbb_result = {{24{SrcA[7]}},  SrcA[7:0]};                       // SEXT.B
            4'd14:   zbb_result = {{16{SrcA[15]}}, SrcA[15:0]};                      // SEXT.H
            4'd15:   zbb_result = ZBBOrcB ? orcb_result : rev8_result;
            default: zbb_result = 32'bx;
        endcase
    end

    // Output mux
    assign ALUResult = MulOp ? mul_result :
                       ZBBOp ? zbb_result :
                                alu_result;

endmodule

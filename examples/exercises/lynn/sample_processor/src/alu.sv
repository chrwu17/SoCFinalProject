// alu.sv
// Christian Wu & Eastan Oo
// 04/10/2026
// chrwu@g.hmc.edu eoo@g.hmc.edu
 
module alu(
        input   logic           clk,
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

    logic [4:0] shiftAmount;
    assign shiftAmount = SrcB[4:0];

    // Adder / subtractor
    logic [31:0] sum_add, sum_sub;
    assign sum_add = SrcA + SrcB;
    assign sum_sub = SrcA - SrcB;

    logic alu_SubArith;
    assign alu_SubArith = SubArith | (ZBBOp && (ZBBSel >= 4'd3 && ZBBSel <= 4'd6));

    logic [31:0] Sum, SLT, SLTU;
    assign Sum = alu_SubArith ? sum_sub : sum_add;
    assign IEUAdr = Sum;

    logic is_lt, is_ltu;
    assign is_ltu = SrcA < SrcB;
    assign is_lt  = $signed(SrcA) < $signed(SrcB);

    assign SLT  = {31'b0, is_lt};
    assign SLTU = {31'b0, is_ltu};

    // Funnel Shifter
    logic [63:0] funnel_in;
    logic [4:0]  funnel_shift;

    always_comb begin
        if (ZBBOp && (ZBBSel == 4'd8 || ZBBSel == 4'd9)) begin
            // ROL or ROR
            funnel_in = {SrcA, SrcA};
        end else begin
            case (ALUSelect)
                3'b001: funnel_in = {SrcA, 32'b0};            // SLL
                3'b101: funnel_in = SubArith
                            ? {{32{SrcA[31]}}, SrcA}           // SRA
                            : {32'b0, SrcA};                   // SRL
                default: funnel_in = {32'b0, SrcA};            
            endcase
        end
    end

    always_comb begin
        if (ZBBOp && ZBBSel == 4'd8)
            funnel_shift = 5'd0 - shiftAmount;   
        else if (ALUSelect == 3'b001 && !ZBBOp)
            funnel_shift = 5'd0 - shiftAmount; 
        else
            funnel_shift = shiftAmount;           // SRL, SRA, ROR, RORI
    end

    logic [63:0] fs0, fs1, fs2, fs3, fs4;
    assign fs0 = funnel_shift[0] ? {1'b0,  funnel_in[63:1]}  : funnel_in;
    assign fs1 = funnel_shift[1] ? {2'b0,  fs0[63:2]}        : fs0;
    assign fs2 = funnel_shift[2] ? {4'b0,  fs1[63:4]}        : fs1;
    assign fs3 = funnel_shift[3] ? {8'b0,  fs2[63:8]}        : fs2;
    assign fs4 = funnel_shift[4] ? {16'b0, fs3[63:16]}       : fs3;

    logic [31:0] funnel_result;
    assign funnel_result = fs4[31:0];

    // Zmmul — pipelined multiplier (2 register stages)
    logic signed [32:0] mul_a, mul_b;
    logic signed [32:0] mul_a_reg, mul_b_reg;
    logic signed [65:0] mul_full;
    logic [31:0]        mul_result;

    always_comb begin
        mul_a = (MulSel == 2'b11) ? {1'b0, SrcA} : {SrcA[31], SrcA};
        mul_b = (MulSel == 2'b11 || MulSel == 2'b10) ? {1'b0, SrcB} : {SrcB[31], SrcB};
    end

    // Stage 1 register: capture multiply inputs
    always_ff @(posedge clk) begin
        mul_a_reg <= mul_a;
        mul_b_reg <= mul_b;
    end

    // Combinational multiply between the two register stages
    assign mul_full = mul_a_reg * mul_b_reg;

    // Stage 2 register: capture multiply output
    logic signed [65:0] mul_full_reg;
    always_ff @(posedge clk) begin
        mul_full_reg <= mul_full;
    end

    // Select which 32 bits of the registered result to use
    always_comb begin
        case (MulSel)
            2'b00: mul_result = mul_full_reg[31:0];   // MUL    (lower 32 bits)
            2'b01: mul_result = mul_full_reg[63:32];  // MULH   (upper 32 bits)
            2'b10: mul_result = mul_full_reg[63:32];  // MULHSU (upper 32 bits)
            2'b11: mul_result = mul_full_reg[63:32];  // MULHU  (upper 32 bits)
            default: mul_result = 32'bx;
        endcase
    end

    // Main ALU mux
    logic [31:0] alu_result;

    always_comb begin
        case (ALUSelect)
            3'b000: alu_result = Sum;
            3'b001: alu_result = (shiftAmount == 5'd0) ? SrcA : funnel_result;   // SLL  (was SrcA << shiftAmount)
            3'b010: alu_result = SLT;
            3'b011: alu_result = SLTU;
            3'b100: alu_result = SrcA ^ SrcB;
            3'b101: alu_result = funnel_result;   // SRL & SRA
            3'b110: alu_result = SrcA | SrcB;
            3'b111: alu_result = SrcA & SrcB;
            default: alu_result = 32'bx;
        endcase
    end

    // ZBB extension

    // CLZ: count leading zeros.
    logic [5:0] clz_count;
    logic [4:0] clz_fast;
    logic [15:0] clz_L1;
    logic [7:0]  clz_L2;
    logic [3:0]  clz_L3;
    logic [1:0]  clz_L4;

    assign clz_L1 = SrcA[31:16] ? SrcA[31:16] : SrcA[15:0];
    assign clz_fast[4] = (SrcA[31:16] == 16'b0);

    assign clz_L2 = clz_L1[15:8] ? clz_L1[15:8] : clz_L1[7:0];
    assign clz_fast[3] = (clz_L1[15:8] == 8'b0);

    assign clz_L3 = clz_L2[7:4] ? clz_L2[7:4] : clz_L2[3:0];
    assign clz_fast[2] = (clz_L2[7:4] == 4'b0);

    assign clz_L4 = clz_L3[3:2] ? clz_L3[3:2] : clz_L3[1:0];
    assign clz_fast[1] = (clz_L3[3:2] == 2'b0);

    assign clz_fast[0] = (clz_L4[1] == 1'b0);
    assign clz_count = (SrcA == 32'b0) ? 6'd32 : {1'b0, clz_fast};

 
    // CTZ: count trailing zeros.
    logic [5:0] ctz_count;
    logic [4:0] ctz_fast;
    logic [15:0] ctz_L1;
    logic [7:0]  ctz_L2;
    logic [3:0]  ctz_L3;
    logic [1:0]  ctz_L4;

    assign ctz_L1 = SrcA[15:0] ? SrcA[15:0] : SrcA[31:16];
    assign ctz_fast[4] = (SrcA[15:0] == 16'b0);

    assign ctz_L2 = ctz_L1[7:0] ? ctz_L1[7:0] : ctz_L1[15:8];
    assign ctz_fast[3] = (ctz_L1[7:0] == 8'b0);

    assign ctz_L3 = ctz_L2[3:0] ? ctz_L2[3:0] : ctz_L2[7:4];
    assign ctz_fast[2] = (ctz_L2[3:0] == 4'b0);

    assign ctz_L4 = ctz_L3[1:0] ? ctz_L3[1:0] : ctz_L3[3:2];
    assign ctz_fast[1] = (ctz_L3[1:0] == 2'b0);

    assign ctz_fast[0] = (ctz_L4[0] == 1'b0);
    assign ctz_count = (SrcA == 32'b0) ? 6'd32 : {1'b0, ctz_fast};
 

    // CPOP: population count
    logic [5:0] cpop_count;
    logic [5:0] pop_lvl1 [15:0];
    logic [5:0] pop_lvl2 [7:0];
    logic [5:0] pop_lvl3 [3:0];
    logic [5:0] pop_lvl4 [1:0];

    always_comb begin
        for (int i = 0; i < 16; i++)
            pop_lvl1[i] = {5'b0, SrcA[2*i]} + {5'b0, SrcA[2*i+1]};
        for (int i = 0; i < 8; i++)
            pop_lvl2[i] = pop_lvl1[2*i] + pop_lvl1[2*i+1];
        for (int i = 0; i < 4; i++)
            pop_lvl3[i] = pop_lvl2[2*i] + pop_lvl2[2*i+1];
        for (int i = 0; i < 2; i++)
            pop_lvl4[i] = pop_lvl3[2*i] + pop_lvl3[2*i+1];
        cpop_count = pop_lvl4[0] + pop_lvl4[1];
    end

    // ORC.B
    logic [31:0] orcb_result;
    assign orcb_result = {
        {8{|SrcA[31:24]}},
        {8{|SrcA[23:16]}},
        {8{|SrcA[15:8]}},
        {8{|SrcA[7:0]}}
    };

    // REV8
    logic [31:0] rev8_result;
    assign rev8_result = {SrcA[7:0], SrcA[15:8], SrcA[23:16], SrcA[31:24]};

    // ZBB Mux
    logic [31:0] zbb_result;
    always_comb begin
        case (ZBBSel)
            4'd0:    zbb_result = SrcA & ~SrcB;
            4'd1:    zbb_result = SrcA | ~SrcB;
            4'd2:    zbb_result = ~(SrcA ^ SrcB);
            4'd3:    zbb_result = is_lt  ? SrcA : SrcB; // MIN
            4'd4:    zbb_result = is_lt  ? SrcB : SrcA; // MAX
            4'd5:    zbb_result = is_ltu ? SrcA : SrcB; // MINU
            4'd6:    zbb_result = is_ltu ? SrcB : SrcA; // MAXU
            4'd7:    zbb_result = {16'b0, SrcA[15:0]};
            4'd8:    zbb_result = funnel_result;        // ROL
            4'd9:    zbb_result = funnel_result;        // ROR & RORI
            4'd10:   zbb_result = {26'b0, clz_count};
            4'd11:   zbb_result = {26'b0, ctz_count};
            4'd12:   zbb_result = {26'b0, cpop_count};
            4'd13:   zbb_result = {{24{SrcA[7]}},  SrcA[7:0]};   // SEXT.B
            4'd14:   zbb_result = {{16{SrcA[15]}}, SrcA[15:0]};  // SEXT.H
            4'd15:   zbb_result = ZBBOrcB ? orcb_result : rev8_result;
            default: zbb_result = 32'bx;
        endcase
    end

    // Output mux
    assign ALUResult = MulOp ? mul_result :
                       ZBBOp ? zbb_result :
                               alu_result;

endmodule
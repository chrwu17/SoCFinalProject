// controller.sv
// Christian Wu & Eastan Oo
// 04/10/2026
// chrwu@g.hmc.edu eoo@g.hmc.edu

`include "parameters.svh"

module controller (
        input  logic [6:0]  Op,
        input  logic [2:0]  Funct3,
        input  logic        Funct7b5,
        input  logic [6:0]  Funct7,
        input  logic [4:0]  Rs2,        

        output logic        ALUResultSrc,
        output logic [1:0]  ResultSrc,
        output logic [1:0]  MemRW,
        output logic        MemRead,
        output logic [1:0]  ALUSrc,
        output logic [2:0]  ImmSrc,
        output logic        RegWrite,
        output logic        W64,
        output logic [2:0]  ALUSelect,
        output logic        SubArith,
        output logic        CSREn,
        output logic        MulOp,
        output logic [1:0]  MulSel,
        output logic        Branch,
        output logic        Jump,

        output logic        ZBBOp,
        output logic [3:0]  ZBBSel,
        output logic        ZBBOrcB,

        output logic        IsAdd,          // hpm3
        output logic        IsBranch,       // hpm4
        output logic        IsLoad,         // hpm6
        output logic        IsStore,        // hpm7
        output logic        IsJump,         // hpm8
        output logic        IsCSR,          // hpm9
        output logic        IsALUImm        // hpm10
    );

    logic ALUOp;
    logic IsMul;
    assign IsMul = (Op == 7'h33) & (Funct7 == 7'h01);

    // R-type funct7 values
    localparam F7_ZBB_LOGIC  = 7'h20;
    localparam F7_ZBB_MINMAX = 7'h05;
    localparam F7_ZBB_ZEXTH  = 7'h04;
    localparam F7_ZBB_ROT    = 7'h30;

    // I-type funct7 values (bits[31:25] of the instruction word)
    localparam F7_ZBB_UNARY  = 7'h30;  // CLZ/CTZ/CPOP/SEXT.B/SEXT.H
    localparam F7_ZBB_RORI   = 7'h30;  // RORI  (same funct7, funct3=101 vs unary funct3=001)
    localparam F7_ZBB_REV8   = 7'h34;  // REV8
    localparam F7_ZBB_ORCB   = 7'h14;  // ORC.B

    logic IsZBB_Logic;
    logic IsZBB_MinMax;
    logic IsZBB_ZextH;
    logic IsZBB_Rot;

    assign IsZBB_Logic  = (Funct7 == F7_ZBB_LOGIC) &
                          (Funct3 == 3'b100 |   // XNOR
                           Funct3 == 3'b110 |   // ORN
                           Funct3 == 3'b111);   // ANDN

    assign IsZBB_MinMax = (Funct7 == F7_ZBB_MINMAX) &
                          (Funct3 == 3'b100 |   // MIN
                           Funct3 == 3'b101 |   // MINU
                           Funct3 == 3'b110 |   // MAX
                           Funct3 == 3'b111);   // MAXU

    assign IsZBB_ZextH  = (Funct7 == F7_ZBB_ZEXTH) &
                          (Funct3 == 3'b100);

    assign IsZBB_Rot    = (Funct7 == F7_ZBB_ROT) &
                          (Funct3 == 3'b001 |   // ROL
                           Funct3 == 3'b101);   // ROR

    logic IsZBB_R;
    assign IsZBB_R = (Op == 7'h33) & !IsMul &
                     (IsZBB_Logic | IsZBB_MinMax | IsZBB_ZextH | IsZBB_Rot);

    // ZBB I-type 
    logic IsZBB_Unary;
    logic IsZBB_I_Rot;
    logic IsZBB_Rev8;
    logic IsZBB_OrcB;

    assign IsZBB_Unary = (Funct3 == 3'b001) & (Funct7 == F7_ZBB_UNARY);
    assign IsZBB_I_Rot = (Funct3 == 3'b101) & (Funct7 == F7_ZBB_RORI);
    assign IsZBB_Rev8  = (Funct3 == 3'b101) & (Funct7 == F7_ZBB_REV8);
    assign IsZBB_OrcB  = (Funct3 == 3'b101) & (Funct7 == F7_ZBB_ORCB);

    logic IsZBB_I;
    assign IsZBB_I = (Op == 7'h13) &
                     (IsZBB_Unary | IsZBB_I_Rot | IsZBB_Rev8 | IsZBB_OrcB);

    // Main decoder
    always_comb begin
        // defaults
        {Branch, Jump}   = 2'b00;
        ALUSrc           = 2'b00;
        ImmSrc           = 3'b000;
        ALUOp            = 1'b0;
        ALUResultSrc     = 1'b0;
        ResultSrc        = 2'b00;
        RegWrite         = 1'b0;
        MemRW            = 2'b00;
        MemRead          = 1'b0;
        W64              = 1'b0;
        CSREn            = 1'b0;
        MulOp            = 1'b0;
        MulSel           = 2'b00;
        ZBBOp            = 1'b0;
        ZBBSel           = 4'd0;
        ZBBOrcB          = 1'b0;
        IsLoad           = 1'b0;
        IsStore          = 1'b0;
        IsJump           = 1'b0;
        IsCSR            = 1'b0;
        IsALUImm         = 1'b0;


        case (Op)
            7'h33: begin // R-type 
                RegWrite     = 1'b1;
                ALUSrc       = 2'b00;
                ALUOp        = 1'b1;
                if (IsMul) begin
                    MulOp = 1'b1;
                    MulSel = Funct3[1:0];
                end else if (IsZBB_R) begin
                    ZBBOp = 1'b1;
                    if (IsZBB_Logic) begin
                        case (Funct3)
                            3'b111:  ZBBSel = 4'd0;  // ANDN
                            3'b110:  ZBBSel = 4'd1;  // ORN
                            3'b100:  ZBBSel = 4'd2;  // XNOR
                            default: ZBBSel = 4'd0;
                        endcase
                    end else if (IsZBB_MinMax) begin
                        case (Funct3)
                            3'b100:  ZBBSel = 4'd3;  // MIN
                            3'b101:  ZBBSel = 4'd5;  // MINU
                            3'b110:  ZBBSel = 4'd4;  // MAX
                            3'b111:  ZBBSel = 4'd6;  // MAXU
                            default: ZBBSel = 4'd3;
                        endcase
                    end else if (IsZBB_ZextH) begin
                        ZBBSel = 4'd7;               // ZEXT.H
                    end else begin // IsZBB_Rot
                        case (Funct3)
                            3'b001:  ZBBSel = 4'd8;  // ROL
                            3'b101:  ZBBSel = 4'd9;  // ROR
                            default: ZBBSel = 4'd8;
                        endcase
                    end
                end
            end
            7'h13: begin // I-type ALU
                RegWrite     = 1'b1;
                ALUSrc       = 2'b01;
                ImmSrc       = 3'b000;
                ALUOp        = 1'b1;
                if (IsZBB_I) begin
                    ZBBOp = 1'b1;
                    if (IsZBB_Unary) begin
                        case (Rs2)
                            5'd0:    ZBBSel = 4'd10;  // CLZ
                            5'd1:    ZBBSel = 4'd11;  // CTZ
                            5'd2:    ZBBSel = 4'd12;  // CPOP
                            5'd4:    ZBBSel = 4'd13;  // SEXT.B
                            5'd5:    ZBBSel = 4'd14;  // SEXT.H
                            default: ZBBSel = 4'd10;
                        endcase
                    end else if (IsZBB_I_Rot) begin
                        ZBBSel  = 4'd9;               // RORI
                    end else if (IsZBB_Rev8) begin
                        ZBBSel  = 4'd15;              // REV8
                        ZBBOrcB = 1'b0;
                    end else begin // IsZBB_OrcB
                        ZBBSel  = 4'd15;              // ORC.B
                        ZBBOrcB = 1'b1;
                    end
                end else begin
                    IsALUImm = 1'b1;
                end
            end
            7'h03: begin // loads
                RegWrite     = 1'b1;
                ALUSrc       = 2'b01;
                ImmSrc       = 3'b000;
                MemRW        = 2'b10; 
                MemRead      = 1'b1;
                ResultSrc    = 2'b10;
                IsLoad       = 1'b1;
            end
            7'h23: begin // stores
                ALUSrc       = 2'b01;
                ImmSrc       = 3'b001;
                MemRW        = 2'b01;   // MemWrite
                IsStore      = 1'b1;
            end
            7'h63: begin // branches
                Branch       = 1'b1;
                ALUSrc       = 2'b11;
                ImmSrc       = 3'b010;
            end
            7'h6F: begin // jal
                Jump         = 1'b1;
                ALUSrc       = 2'b11;
                ImmSrc       = 3'b011;
                ResultSrc    = 2'b01;
                RegWrite     = 1'b1;
                IsJump       = 1'b1;
            end
            7'h67: begin // jalr
                Jump         = 1'b1;
                ALUSrc       = 2'b01;
                ImmSrc       = 3'b000;
                ResultSrc    = 2'b01;
                RegWrite     = 1'b1;
                IsJump       = 1'b1;
            end
            7'h37: begin // lui
                ALUSrc       = 2'b01;
                ImmSrc       = 3'b100;
                ALUResultSrc = 1'b1;
                RegWrite     = 1'b1;
            end
            7'h17: begin // auipc
                ALUSrc       = 2'b11;
                ImmSrc       = 3'b100;
                RegWrite     = 1'b1;
            end
            7'h73: begin // Zicsr
                if (Funct3 == 3'b010) begin
                    RegWrite  = 1'b1;
                    ResultSrc = 2'b11;
                    CSREn     = 1'b1;
                    IsCSR     = 1'b1;
                end
            end
            default: begin
                // all signals already defaulted to 0
            end
        endcase
    end

    // ALU Decoder
    logic Slt, Sltu, Sra, Sub;

    always_comb begin
        ALUSelect = 3'b000; // default: add
        SubArith  = 1'b0;

        if (ALUOp) begin
            ALUSelect = Funct3;

            Slt      = (Funct3 == 3'b010);
            Sltu     = (Funct3 == 3'b011);
            Sra      = (Funct3 == 3'b101) & Funct7b5;
            Sub      = (Funct3 == 3'b000) & Funct7b5 & Op[5];
            SubArith = Slt | Sltu | Sra | Sub;
        end else begin
            Slt   = 1'b0;
            Sltu  = 1'b0;
            Sra   = 1'b0;
            Sub   = 1'b0;
        end
    end

    assign IsAdd = (Op == 7'h33 && Funct3 == 3'b000 && !Funct7b5) || (Op == 7'h13 && Funct3 == 3'b000);
    assign IsBranch = Branch;

endmodule

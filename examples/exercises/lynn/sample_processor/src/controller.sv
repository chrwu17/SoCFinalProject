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

        output logic        IsAdd,
        output logic        IsBranch,
        output logic        IsLoad,
        output logic        IsStore,
        output logic        IsJump,
        output logic        IsCSR,
        output logic        IsALUImm
    );

    logic ALUOp;
    logic IsMul;
    assign IsMul = (Op == 7'h33) & (Funct7 == 7'h01);

    localparam F7_ZBB_LOGIC  = 7'h20;
    localparam F7_ZBB_MINMAX = 7'h05;
    localparam F7_ZBB_ZEXTH  = 7'h04;
    localparam F7_ZBB_ROT    = 7'h30;

    localparam F7_ZBB_UNARY  = 7'h60;
    localparam F7_ZBB_RORI   = 7'h30;
    localparam F7_ZBB_REV8   = 7'h34;
    localparam F7_ZBB_ORCB   = 7'h28;

    logic IsZBB_R;
    assign IsZBB_R = (Op == 7'h33) & !IsMul & (
                         (Funct7 == F7_ZBB_LOGIC)  |
                         (Funct7 == F7_ZBB_MINMAX) |
                         (Funct7 == F7_ZBB_ZEXTH)  |
                         (Funct7 == F7_ZBB_ROT)
                     );

    logic IsZBB_I;
    assign IsZBB_I = (Op == 7'h13) & (
                         ((Funct3 == 3'b001) & (Funct7 == F7_ZBB_UNARY)) |
                         ((Funct3 == 3'b101) & (Funct7 == F7_ZBB_RORI))  |
                         ((Funct3 == 3'b101) & (Funct7 == F7_ZBB_REV8))  |
                         ((Funct3 == 3'b101) & (Funct7 == F7_ZBB_ORCB))
                     );

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
        ZBBSel           = 4'b0;
        ZBBOrcB          = 1'b0;
        IsLoad           = 1'b0;
        IsStore          = 1'b0;
        IsJump           = 1'b0;
        IsCSR            = 1'b0;
        IsALUImm         = 1'b0;

        case (Op)
            7'h33: begin
                RegWrite     = 1'b1;
                ALUSrc       = 2'b00;
                ALUOp        = 1'b1;
                if (IsMul) begin
                    MulOp = 1'b1;
                    MulSel = Funct3[1:0];
                end else if (IsZBB_R) begin
                    ZBBOp = 1'b1;
                    case (Funct7)
                        F7_ZBB_LOGIC: begin
                            case (Funct3)
                                3'b111:  ZBBSel = 4'd0;
                                3'b110:  ZBBSel = 4'd1;
                                3'b100:  ZBBSel = 4'd2;
                                default: ZBBSel = 4'd0;
                            endcase
                        end
                        F7_ZBB_MINMAX: begin
                            case (Funct3)
                                3'b100:  ZBBSel = 4'd3;
                                3'b101:  ZBBSel = 4'd4;
                                3'b110:  ZBBSel = 4'd5;
                                3'b111:  ZBBSel = 4'd6;
                                default: ZBBSel = 4'd3;
                            endcase
                        end
                        F7_ZBB_ZEXTH: ZBBSel = 4'd7;
                        F7_ZBB_ROT: begin
                            case (Funct3)
                                3'b001:  ZBBSel = 4'd8;
                                3'b101:  ZBBSel = 4'd9;
                                default: ZBBSel = 4'd8;
                            endcase
                        end
                        default: ZBBSel = 4'd0;
                    endcase
                end
            end
            7'h13: begin
                RegWrite     = 1'b1;
                ALUSrc       = 2'b01;
                ImmSrc       = 3'b000;
                ALUOp        = 1'b1;
                if (IsZBB_I) begin
                    ZBBOp    = 1'b1;
                    case ({Funct7, Funct3})
                        {F7_ZBB_UNARY, 3'b001}: begin
                            case (Rs2)
                                5'd0:    ZBBSel = 4'd10;
                                5'd1:    ZBBSel = 4'd11;
                                5'd2:    ZBBSel = 4'd12;
                                5'd4:    ZBBSel = 4'd13;
                                5'd5:    ZBBSel = 4'd14;
                                default: ZBBSel = 4'd10;
                            endcase
                        end
                        {F7_ZBB_RORI, 3'b101}: ZBBSel = 4'd9;
                        {F7_ZBB_REV8, 3'b101}: begin
                            ZBBSel  = 4'd15;
                            ZBBOrcB = 1'b0;
                        end
                        {F7_ZBB_ORCB, 3'b101}: begin
                            ZBBSel  = 4'd15;
                            ZBBOrcB = 1'b1;
                        end
                        default: ZBBSel = 4'd10;
                    endcase
                end else begin
                    IsALUImm = 1'b1;
                end
            end
            7'h03: begin
                RegWrite     = 1'b1;
                ALUSrc       = 2'b01;
                ImmSrc       = 3'b000;
                MemRW        = 2'b10;
                MemRead      = 1'b1;
                ResultSrc    = 2'b10;
                IsLoad       = 1'b1;
            end
            7'h23: begin
                ALUSrc       = 2'b01;
                ImmSrc       = 3'b001;
                MemRW        = 2'b01;
                IsStore      = 1'b1;
            end
            7'h63: begin
                Branch       = 1'b1;
                ALUSrc       = 2'b11;
                ImmSrc       = 3'b010;
            end
            7'h6F: begin
                Jump         = 1'b1;
                ALUSrc       = 2'b11;
                ImmSrc       = 3'b011;
                ResultSrc    = 2'b01;
                RegWrite     = 1'b1;
                IsJump       = 1'b1;
            end
            7'h67: begin
                Jump         = 1'b1;
                ALUSrc       = 2'b01;
                ImmSrc       = 3'b000;
                ResultSrc    = 2'b01;
                RegWrite     = 1'b1;
                IsJump       = 1'b1;
            end
            7'h37: begin
                ALUSrc       = 2'b01;
                ImmSrc       = 3'b100;
                ALUResultSrc = 1'b1;
                RegWrite     = 1'b1;
            end
            7'h17: begin
                ALUSrc       = 2'b11;
                ImmSrc       = 3'b100;
                RegWrite     = 1'b1;
            end
            7'h73: begin
                if (Funct3 == 3'b010) begin
                    RegWrite  = 1'b1;
                    ResultSrc = 2'b11;
                    CSREn     = 1'b1;
                    IsCSR     = 1'b1;
                end
            end
            default: begin
            end
        endcase
    end

    logic Slt, Sltu, Sra, Sub;

    always_comb begin
        ALUSelect = 3'b000;
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

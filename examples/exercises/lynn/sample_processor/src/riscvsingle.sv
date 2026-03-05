// riscvsingle.sv
// RISC-V single-cycle processor
// David_Harris@hmc.edu 2020 kacassidy@hmc.edu 2025

`include "parameters.svh"

module riscvsingle(
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

    logic [31:0] PCPlus4, LoadResult, StoreData, ALUResult, RawWriteData;
    logic        PCSrc;
    logic [1:0]  MemRW;

    ifu ifu(.clk, .reset, .PCSrc, .PC, .PCPlus4);

    ieu ieu(
        .clk, .reset, .Instr,
        .PC, .PCPlus4,
        .PCSrc,
        .MemRW,
        .IEUAdr(ALUResult),
        .WriteData(RawWriteData),
        .LoadResult
    );

    lsu lsu(
        .ALUResult,
        .WriteData(RawWriteData),
        .ReadData,
        .Funct3(Instr[14:12]),
        .MemRW,
        .IEUAdr,
        .StoreData,
        .LoadResult,
        .WriteByteEn,
        .MemEn
    );

    assign WriteEn   = MemRW[0];
    assign WriteData = StoreData;

endmodule

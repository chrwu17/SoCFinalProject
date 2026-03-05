// riscvsingle.sv
// RISC-V single-cycle processor
// David_Harris@hmc.edu 2020 kacassidy@hmc.edu 2025

module ifu(
        input   logic           clk, reset,
        input   logic           PCSrc,
        input   logic [31:0]    IEUAdr,
        output  logic [31:0]    PC, PCPlus4
    );

    logic [31:0] PCNext;
    logic [31:0] BranchTarget;

    assign BranchTarget = IEUAdr & 32'hFFFFFFFE;

    logic [31:0] entry_addr;

    initial begin
        entry_addr = '0;

        void'($value$plusargs("ENTRY_ADDR=%h", entry_addr));

        $display("[TB] ENTRY_ADDR = 0x%h", entry_addr);
    end

    always_ff @(posedge clk) begin
        if (reset)  PC <= entry_addr;
        else        PC <= PCNext;
    end

    adder pcadd4(PC, 32'd4, PCPlus4);
    mux2 #(32) pcmux(PCPlus4, BranchTarget, PCSrc, PCNext);
endmodule

// riscvsingle.sv
// RISC-V single-cycle processor
// David_Harris@hmc.edu 2020 kacassidy@hmc.edu 2025

module ifu(
        input   logic           clk, reset,
        input   logic           PCSrcE,
        input   logic           PCTargetE,
        input   logic           StallF,
        output  logic [31:0]    PCF, PCPlus4F
    );

    logic [31:0] PCNext;
    logic [31:0] entry_addr;

    initial begin
        entry_addr = '0;
        void'($value$plusargs("ENTRY_ADDR=%h", entry_addr));
        $display("[TB] ENTRY_ADDR = 0x%h", entry_addr);
    end

    always_ff @(posedge clk) begin
        if      (reset)   PCF <= entry_addr;
        else if (~StallF) PCF <= PCNext;
    end

    adder pcadd4(PCF, 32'd4, PCPlus4F);

    mux2 #(32) pcmux(PCPlus4F, PCTargetE, PCSrcE, PCNext);
endmodule

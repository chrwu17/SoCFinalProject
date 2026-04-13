// floprc.sv
// Christian Wu & Eastan Oo
// 04/13/2026
// chrwu@g.hmc.edu eoo@g.hmc.ed

module floprc #(parameter WIDTH = 8) (
    input  logic             clk,
    input  logic             reset,
    input  logic             clear,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);

    always_ff @(posedge clk) begin
        if (reset) begin
            q <= '0;
        end else if (clear) begin
            q <= '0;
        end else begin
            q <= d;
        end
    end

endmodule
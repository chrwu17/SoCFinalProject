// flopenr.sv
// Christian Wu & Eastan Oo
// 03/30/2026
// chrwu@g.hmc.edu eoo@g.hmc.edu

module flopenr #(parameter WIDTH, parameter DEFAULT = 0) (
    input  logic             clk,
    input  logic             reset,
    input  logic             en,      
    input  logic [WIDTH-1:0] D,
    output logic [WIDTH-1:0] Q
);
    always_ff @(posedge clk)
        if      (reset) Q <= DEFAULT;
        else if (en)    Q <= D;
endmodule
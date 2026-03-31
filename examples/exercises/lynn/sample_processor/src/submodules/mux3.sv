// mux3.sv
// Christian Wu & Eastan Oo
// 03/30/2026
// chrwu@g.hmc.edu eoo@g.hmc.edu

module mux3 #(parameter WIDTH) (
    input  logic [WIDTH-1:0] A,   
    input  logic [WIDTH-1:0] B,    
    input  logic [WIDTH-1:0] C,   
    input  logic [1:0]       sel,
    output logic [WIDTH-1:0] result
);
    always_comb
        case (sel)
            2'b00:   result = A;
            2'b01:   result = B;
            2'b10:   result = C;
            default: result = 'x;
        endcase
endmodule
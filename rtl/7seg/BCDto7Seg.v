module BCDto7Seg (
    input wire [3:0] BCD,
    output reg [6:0] s7
    );

    always @(*)
        case (BCD)
            // Segments - gfedcba
            4'h0: s7 = 7'b1000000;
            4'h1: s7 = 7'b1111001;
            4'h2: s7 = 7'b0100100;
            4'h3: s7 = 7'b0110000;
            4'h4: s7 = 7'b0011001;
            4'h5: s7 = 7'b0010010;
            4'h6: s7 = 7'b0000010;
            4'h7: s7 = 7'b1111000;
            4'h8: s7 = 7'b0000000;
            4'h9: s7 = 7'b0010000;
            default: s7 = 7'b1111111;
        endcase 

endmodule

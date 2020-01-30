module sevenSeg(
	input wire  [7:0] binary,
	input wire        clk,
	output wire [6:0] seg,
	output wire [2:0] ca
);

	reg [17:0] count  = 0;
	reg [1:0] ca_count = 0;
	wire [3:0] BCD;
	wire [3:0] hundreds, tens, ones;

	always @(posedge clk) begin
		count <= count + 1;
		if (count[17]) begin
			count <= 0;
			ca_count <= (ca_count == 2) ? ca_count <= 0 :ca_count + 1;
		end
	end

	assign ca = (ca_count == 0) ? 3'b110 :
		    (ca_count == 1) ? 3'b101 : 3'b011;

	BinToBCD BtBCD1  (.number(binary), .hundreds(hundreds), .tens(tens), .ones(ones));
	BCDto7Seg BCDtS1 (.BCD(BCD), .s7(seg));
	

	assign BCD = (ca_count == 0) ? ones :
		    (ca_count == 1) ? tens : hundreds;

endmodule

module FIFO #(parameter DATA_WIDTH=16, DEPTH=64) (
    input clk,
    input rstn,
    input write,
    input read,
    input [DATA_WIDTH-1:0] i_data, 
    output [DATA_WIDTH-1:0] o_data, 
    output isEmpty
    );


    reg [$clog2(DEPTH-1):0] write_pointer = 0;
    reg [$clog2(DEPTH-1):0] read_pointer = 0;

    reg [DATA_WIDTH-1:0] memory_array [0:DEPTH-1];

    always @(posedge clk) begin
	if (!rstn) begin
		write_pointer <=  0;
		read_pointer <= 0;
	end 
	else begin
		if (write) begin
			memory_array[write_pointer] <= i_data;
			write_pointer <= write_pointer + 1;
		end
		if (read && !isEmpty) begin
			read_pointer <= read_pointer + 1;
		end
	end
    end

    assign o_data = (!isEmpty) ? memory_array[read_pointer] : 0;

    assign isEmpty = (write_pointer == read_pointer) ? 1 : 0;


endmodule

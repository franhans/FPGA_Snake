module sram #(parameter ADDR_WIDTH=9, DATA_WIDTH=1, DEPTH=384, INIT = 1) (
    input wire i_clk,
    input wire [ADDR_WIDTH-1:0] i_addr, 
    input wire i_write,
    input wire [DATA_WIDTH-1:0] i_data,
    output reg [DATA_WIDTH-1:0] o_data 
    );

    reg [DATA_WIDTH-1:0] memory_array [0:DEPTH-1]; 


    always @ (posedge i_clk)
    begin
        if(i_write) begin
            memory_array[i_addr] <= i_data;
        end
        else begin
            o_data <= memory_array[i_addr];
        end     
    end


    integer i;

  
    //-------------------------------------------
    //             RAM initialization
    //-------------------------------------------

    initial begin
    	if (INIT) begin
    	
		for (i = 0; i < 64; i = i + 1)
			memory_array[i] = 0;
		for (i = 64; i < 128; i = i + 1)
			if (i%8 <= 1 ) memory_array[i] = 1;
		for (i = 128; i < 192; i = i + 1)
			if (i%8 <= 3) memory_array[i] = 1;
		for (i = 192; i < 256; i = i + 1)
			if (i%8 <= 5) memory_array[i] = 1;
		for (i = 256; i < 320; i = i + 1)
			memory_array[i] = 1;	
		for (i = 320; i < 384; i = i + 1) begin
			if (i%8 > 1 && i%8 < 6 && (i/8)%8 > 1 && (i/8)%8 < 6)
				memory_array[i] = 1;	
		end
    	end 
        else begin
		for (i = 0; i < DEPTH; i = i + 1)
			memory_array[i] = 0;
		for (i = 80*25+20; i <= 80*25+40; i = i + 1)
			memory_array[i] = 4;
		memory_array[80*22+5] = 5;

		for (i = 0; i < 80; i = i + 1)
			memory_array[i] = 4;
		for (i = 80*59; i < 80*60; i = i + 1)
			memory_array[i] = 4;
		for (i = 0; i < 80*60; i = i + 80)
			memory_array[i] = 4;
		for (i = 79; i < 80*60; i = i + 80)
			memory_array[i] = 4;
		
        end
    end


endmodule
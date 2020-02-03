`default_nettype none   

module top (
    input wire clk,	      // 25MHz clock input
    input wire RSTN_BUTTON,   // rstn,
    input wire rx,            // Tx from the computer
    output wire [15:0] PMOD,  // Led outputs
    //segments outputs
    output wire [6:0] seg,
    output wire [2:0] ca
  );


	wire activevideo;
	wire [9:0] x_px, y_px;
	wire px_clk;
	wire [7:0] dataRX;
	wire WR_RX;

	reg RSTN1;
	reg RSTN2;
	wire rstn_button_int;

	wire HS, VS;


	//Reset button
	`ifdef __ICARUS__	
	`else
		SB_IO #(
		.PIN_TYPE(6'b 0000_01),
        	.PULLUP(1'b1)
    		) io_pin (
       		.PACKAGE_PIN(RSTN_BUTTON),
       		.D_IN_0(rstn_button_int)
 		);
   	`endif


	//Reset is sycronized using 2FF
	always @(posedge clk)
		{RSTN2, RSTN1} <= {RSTN1, rstn_button_int};
    

	//     VGA
	VgaSyncGen vga_inst( 
		.clk(clk),			//Input
		.x_px(x_px),			//Output			
		.y_px(y_px), 			//Output
		.px_clk(px_clk), 		//Output
		.activevideo(activevideo),	//Output
		.hsync(HS),			//Output
		.vsync(VS)			//Output
	);



	//     UART-RX
 	rxuart #(.baudRate(115200), .if_parity(1'b0))
		reciver (
			.i_clk(clk), 		//Input	
			.rst(RSTN2), 	    	//Input	
			.i_uart_rx(rx),		//Input
			.o_wr(WR_RX), 		//Output
			.o_data(dataRX)		//Output
		);


	//     7seg
	sevenSeg S7 (
		.clk(clk),		//Input
		.binary(dataRX),	//Input 
		.seg(seg), 		//Output
		.ca(ca)			//Output
	);


	wire [11:0] RGB;

	snake sn1 (
   		.clk(clk),			// 25MHz clock input
   		.px_clk(px_clk),		// 31MHz clock input
   		.rstn(RSTN2),				// rstn,
       		.dataRX(dataRX),		// Tx from the computer
  		.WR_RX(WR_RX),			// WR_RX is 1 when dataRX is valid, otherwise 0.
    		.x_px(x_px),			// x pixel postition
    		.y_px(y_px),			// y pixel position
    		.activevideo(activevideo),	// activevideo is 1 when x_px and y_px are in the visible zone of the screen.
  		.RGB(RGB)			// Led outputs
	);

	assign PMOD = {RGB[11:8], 2'b00, VS, HS, RGB[7:0]};


endmodule
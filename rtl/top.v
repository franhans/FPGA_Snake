`default_nettype none   
//`define __ICARUS__ 0

module top (
    input wire clk,	      // 25MHz clock input
    input wire RSTN_BUTTON,   // rstn,
    input wire rx,            // Tx from the computer
    output wire [15:0] PMOD,  // Led outputs
    //segments outputs
    output wire [6:0] seg,
    output wire [2:0] ca
  );

    

//--------------------
//Local parameters
//--------------------

    //V for Video output resolution
    localparam Vwidth=640;
    localparam Vheight=480;
    //C for Character resolution
    localparam Cwidth=16;
    localparam Cheight=16;
    //Number of columns and rows
    localparam Ncol=Vwidth/Cwidth;
    localparam Nrow=Vheight/Cheight;


    localparam right = 2'b00;
    localparam left  = 2'b01;
    localparam up    = 2'b10;
    localparam down  = 2'b11;    


    localparam maxTwists = 10;

//--------------------
//IO pins assigments
//--------------------
    //Names of the signals on digilent VGA PMOD adapter
    wire R0, R1, R2, R3;
    wire G0, G1, G2, G3;
    wire B0, B1, B2, B3;
    wire HS,VS;
    wire rstn;
    wire px_clk;
    //pmod1
    assign PMOD[0] = B0;
    assign PMOD[1] = B1;
    assign PMOD[2] = B2;
    assign PMOD[3] = B3;
    assign PMOD[4] = R0;
    assign PMOD[5] = R1;
    assign PMOD[6] = R2;
    assign PMOD[7] = R3;
    //pmod2
    assign PMOD[8] = HS;
    assign PMOD[9] = VS;
    assign PMOD[10] = 0;
    assign PMOD[11] = 0;
    assign PMOD[12] = G0;
    assign PMOD[13] = G1;
    assign PMOD[14] = G2;
    assign PMOD[15] = G3;


//--------------------
// IP internal signals
//--------------------

    //Internal registers for current pixel color
    reg [3:0] R_int = 0;
    reg [3:0] G_int = 0;
    reg [3:0] B_int = 0;


    //sync reset from button and enable pull up
    wire rstn_button_int; //internal signal after pullups
    reg bf1_rstn;
    reg bf2_rstn;
    always @(posedge px_clk) begin
        bf1_rstn <= rstn_button_int;
        bf2_rstn <= bf1_rstn;
    end
    assign  rstn = bf2_rstn;
    
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


    //signals from UART
    wire wr;
    wire [7:0] data;

    //local signals for UART
    reg  wr1 = 1;
    wire wr_f;
    reg  wr_f2 = 0;
    reg [7:0] regData = 0;
    reg [7:0] prevRegData = 0;


    //Sync signals
    wire [9:0] x_px;
    wire [9:0] y_px;
    wire activevideo;

    VgaSyncGen vga_inst( .clk(clk), .hsync(HS), .vsync(VS), .x_px(x_px), .y_px(y_px), .px_clk(px_clk), .activevideo(activevideo));

    //RGB values assigment from pixel color register
    assign R0 = activevideo ? R_int[0] :0; 
    assign R1 = activevideo ? R_int[1] :0; 
    assign R2 = activevideo ? R_int[2] :0; 
    assign R3 = activevideo ? R_int[3] :0; 
    assign G0 = activevideo ? G_int[0] :0; 
    assign G1 = activevideo ? G_int[1] :0; 
    assign G2 = activevideo ? G_int[2] :0; 
    assign G3 = activevideo ? G_int[3] :0; 
    assign B0 = activevideo ? B_int[0] :0; 
    assign B1 = activevideo ? B_int[1] :0; 
    assign B2 = activevideo ? B_int[2] :0; 
    assign B3 = activevideo ? B_int[3] :0; 


    //Element's position and directions
    reg [9:0] beginX = 500;
    reg [9:0] finalX = 100;
    reg [9:0] beginY = 200;
    reg [9:0] finalY = 200;
    reg [1:0] finalDir = 2'b00;
    reg [1:0] beginDir = 2'b00;

    wire collision;

    
    //--------------------------------------------------------------------------------------
    //    Register with positions and directions of the different segments of the snake
    //--------------------------------------------------------------------------------------
    reg [21:0] segmentsReg [0:maxTwists];  //the snake can turn 71 times.  Yposition[21:12] + Xposition[11:2] + Direction[1:0] = 22 bits.
    reg [0:70] isEmpty;
    reg [8:0]  lastValidReg; 
    
    integer i;
    integer j;
    //Register is initialized to 0
    initial begin
	for (i = 0; i <= maxTwists ; i = i + 1)
		segmentsReg[i] <= 21'b000000000000000000000;
    end
    
    //which one is the last register with a value different than 0.
    
    always @(*) begin
	for (i = 0; i <= maxTwists ; i = i + 1) begin
		isEmpty[i] <= |segmentsReg[i];
	end
	lastValidReg = 0;
	for (j = 0; j <= maxTwists ; j = j + 1) begin
		if (isEmpty[j])
			lastValidReg = lastValidReg + 1;
	end
	lastValidReg = lastValidReg - 1;
    end


    always @(posedge clk) begin
    	if (!rstn) begin
		for (i = 0; i <= maxTwists ; i = i + 1)
			segmentsReg[i] <= 21'b000000000000000000000;
		finalDir <= 2'b00;
    		beginDir <= 2'b00;
		prevRegData <= 0;
	end
	else begin 
		if (!lastValidReg[8] && finalX == segmentsReg[lastValidReg][11:2] && finalY == segmentsReg[lastValidReg][21:12]) begin
			segmentsReg[lastValidReg] <= 0;
			if (!(&lastValidReg)) begin 
					finalDir <= segmentsReg[lastValidReg][1:0];
			end
		end
		else if (wr_f2 && (regData >= 65 || regData <= 68) && (regData != prevRegData)) begin 
			prevRegData <= regData;
			case (regData) 
			  65: begin
				segmentsReg [0] <= {beginY, beginX, up};
				beginDir <= up;
			      end
			  66: begin
				segmentsReg [0] <= {beginY, beginX, down};
				beginDir <= down;
			      end
			  67: begin
				segmentsReg [0] <= {beginY, beginX, right};
				beginDir <= right;
			      end
			  68: begin
				segmentsReg [0] <= {beginY, beginX, left};
				beginDir <= left;
			      end
			endcase

			for (i = 1; i <= maxTwists; i = i + 1) 
				segmentsReg[i] <= segmentsReg[i-1];
		end 

	end
    end		


 //-----------------------------------------------------
 //    Position actualization and collision managment
 //-----------------------------------------------------
   
    reg resetCollision = 0;
    wire updateSnakePosition = resetCollision;

    always @(posedge clk) resetCollision <= (x_px == 639) & (y_px == 479);

    always @(posedge clk) begin 
	if (!rstn) begin
		beginX <= 500;
    		finalX <= 100;
    		beginY <= 200;
    		finalY <= 200;
	end 
	else begin
		if (updateSnakePosition) begin
			//añadir colisiones
			case (beginDir)
			    2'b00: beginX <= beginX + 1;
			    2'b01: beginX <= beginX - 1;
			    2'b10: beginY <= beginY - 1;
			    2'b11: beginY <= beginY + 1;
			endcase
			case (finalDir)
			    2'b00: finalX <= finalX + 1;
			    2'b01: finalX <= finalX - 1;
			    2'b10: finalY <= finalY - 1;
			    2'b11: finalY <= finalY + 1;
			endcase
		end
	end
    end
	
   
    reg [2:0] draw_collision;
    always @(*) begin
	draw_collision = 0;
	if (!lastValidReg[8]) begin
		case (finalDir)
	   	  2'b00: if (x_px > finalX - 8 && x_px < segmentsReg[lastValidReg][11:2] + 8 && y_px > finalY - 8 && y_px < finalY + 8)  draw_collision = draw_collision + 1;   
	  	  2'b01: if (x_px > segmentsReg[lastValidReg][11:2] - 8 && x_px < finalX + 8 && y_px > finalY - 8 && y_px < finalY + 8)  draw_collision = draw_collision + 1;
	  	  2'b10: if (x_px > finalX - 8 && x_px < finalX + 8 && y_px < finalY + 8 && y_px > segmentsReg[lastValidReg][21:12] - 8)  draw_collision = draw_collision + 1;
         	  2'b11: if (x_px > finalX - 8 && x_px < finalX + 8 && y_px < segmentsReg[lastValidReg][21:12] + 8 && y_px > finalY - 8)  draw_collision = draw_collision + 1;
		endcase
		for (i = maxTwists; i > 0; i = i - 1) begin
			if (isEmpty[i]) begin
				case (segmentsReg[i][1:0])
	   	  		  2'b00: if (x_px > segmentsReg[i][11:2] - 8 && x_px < segmentsReg[i-1][11:2] + 8 && y_px > segmentsReg[i-1][21:12] - 8 && y_px < segmentsReg[i-1][21:12] + 8)  draw_collision = draw_collision + 1;   
	  	  		  2'b01: if (x_px > segmentsReg[i-1][11:2] - 8 && x_px < segmentsReg[i][11:2] + 8 && y_px > segmentsReg[i-1][21:12] - 8 && y_px < segmentsReg[i-1][21:12] + 8)  draw_collision = draw_collision + 1;
	  	  		  2'b10: if (x_px > segmentsReg[i-1][11:2] - 8 && x_px < segmentsReg[i-1][11:2] + 8 && y_px < segmentsReg[i][21:12] + 8 && y_px > segmentsReg[i-1][21:12] - 8)  draw_collision = draw_collision + 1;
         	  		  2'b11: if (x_px > segmentsReg[i-1][11:2] - 8 && x_px < segmentsReg[i-1][11:2] + 8 && y_px < segmentsReg[i-1][21:12] + 8 && y_px > segmentsReg[i][21:12] - 8)  draw_collision = draw_collision + 1;
				endcase
			end
		end
		case (beginDir)
	   	  2'b00: if (x_px > segmentsReg[0][11:2] - 8 && x_px < beginX + 8 && y_px > beginY - 8 && y_px < beginY + 8)  draw_collision = draw_collision + 1;   
	  	  2'b01: if (x_px > beginX - 8 && x_px < segmentsReg[0][11:2] + 8 && y_px > beginY - 8 && y_px < beginY + 8)  draw_collision = draw_collision + 1;
	  	  2'b10: if (x_px > beginX - 8 && x_px < beginX + 8 && y_px < segmentsReg[0][21:12] + 8 && y_px > beginY - 8)  draw_collision = draw_collision + 1;
         	  2'b11: if (x_px > beginX - 8 && x_px < beginX + 8 && y_px < beginY + 8 && y_px > segmentsReg[0][21:12] - 8)  draw_collision = draw_collision + 1;
		endcase
	end
	else begin
		case (finalDir)
	   	  2'b00: if (x_px > finalX - 8 && x_px < beginX + 8 && y_px > finalY - 8 && y_px < finalY + 8)  draw_collision = draw_collision + 1;   
	  	  2'b01: if (x_px > beginX - 8 && x_px < finalX + 8 && y_px > finalY - 8 && y_px < finalY + 8)  draw_collision = draw_collision + 1;
	  	  2'b10: if (x_px > finalX - 8 && x_px < finalX + 8 && y_px < finalY + 8 && y_px > beginY - 8)  draw_collision = draw_collision + 1;
         	  2'b11: if (x_px > finalX - 8 && x_px < finalX + 8 && y_px < beginY + 8 && y_px > finalY - 8)  draw_collision = draw_collision + 1;
		endcase
	end

    end 

    reg drawFrame = 0;
    always @(*) begin
	if (x_px < 10 || x_px > 630 || y_px < 10 || y_px > 470)
		drawFrame = 1;
	else 
		drawFrame = 0;
    end

    //Update next pixel color
    always @(posedge px_clk) begin
        if (!rstn) begin 
                R_int <= 4'b0;
                G_int <= 4'b0;
                B_int <= 4'b0;
        end else
        if (activevideo) begin
		if (draw_collision > 0 && draw_collision < 5)  //Esto no deberia ser asi
			G_int <= 4'b1000;
		else 
			G_int <= 4'b0000;
		if (drawFrame == 1)
			B_int <= 4'b1000;
		else 
			B_int <= 4'b0000;
       	end
    end

    assign collision = (draw_collision > 0 && drawFrame) ?  1 : 0;



    

//---------------------------
//          UART-RX
//---------------------------
		

	
	rxuart #(.baudRate(115200), .if_parity(1'b0))
		reciver (.i_clk(clk), .rst(rstn), .o_wr(wr), .o_data(data), .i_uart_rx(rx));

	//flank detector and register for the data from the UART
	always @(posedge clk) begin
		if (!rstn) begin
			wr1 <= 1;
			wr_f2 <= 0;
			regData <= 0;
		end
		else begin
			wr1 <= wr;
			wr_f2 <= wr_f;
			if (wr_f) begin
				regData <= data; 
			end
		end
	end
	
	assign wr_f = (wr & ~wr1);



//-----------------
//     7seg
//-----------------
	sevenSeg S7 (.clk(clk), .binary(regData), .seg(seg), .ca(ca));




endmodule

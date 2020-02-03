module snake (
    input clk,	              // 25MHz clock input
    input px_clk,	      // 31MHz clock input
    input rstn,               // rstn,
    input [7:0] dataRX,       // Tx from the computer
    input WR_RX,              // WR_RX is 1 when dataRX is valid, otherwise 0.
    input [9:0] x_px,         // x pixel postition
    input [9:0] y_px,         // y pixel position
    input activevideo,        // activevideo is 1 when x_px and y_px are in the visible zone of the screen.
    output wire [11:0] RGB   // Led outputs
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


    parameter maxTwists = 20;
    parameter initialPositionBeginX = 500;
    parameter initialPositionFinalX = 100;
    parameter initialPositionBeginY = 200;
    parameter initialPositionFinalY = 200;


//--------------------
//IO pins assigments
//--------------------
    //Names of the signals on digilent VGA PMOD adapter
    wire R0, R1, R2, R3;
    wire G0, G1, G2, G3;
    wire B0, B1, B2, B3;
    wire HS,VS;
    //RGB1
    assign RGB[0] = B0;
    assign RGB[1] = B1;
    assign RGB[2] = B2;
    assign RGB[3] = B3;
    assign RGB[4] = R0;
    assign RGB[5] = R1;
    assign RGB[6] = R2;
    assign RGB[7] = R3;
    //RGB2
    //assign RGB[8] = HS;
    //assign RGB[9] = VS;
    //assign RGB[10] = 0;
    //assign RGB[11] = 0;
    assign RGB[8] = G0;
    assign RGB[9] = G1;
    assign RGB[10] = G2;
    assign RGB[11] = G3;



//--------------------
// IP internal signals
//--------------------

    //Internal registers for current pixel color
    reg [3:0] R_int = 0;
    reg [3:0] G_int = 0;
    reg [3:0] B_int = 0;

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
    reg [9:0] beginX = initialPositionBeginX;
    reg [9:0] finalX = initialPositionFinalX;
    reg [9:0] beginY = initialPositionBeginY;
    reg [9:0] finalY = initialPositionFinalY;
    reg [1:0] finalDir = right;
    reg [1:0] beginDir = right;

    
    //local signals for UART
    reg  wr1 = 1;
    wire wr_f;
    reg  wr_f2 = 0;
    reg [7:0] regDataRX = 0;
    //reg [7:0] prevRegData = 0;

    //flank detector and register for the data from the UART
    always @(posedge clk) begin
	if (!rstn) begin
		wr1 <= 1;
		wr_f2 <= 0;
		regDataRX <= 0;
	end
	else begin
		wr1 <= WR_RX;
		wr_f2 <= wr_f;
		if (wr_f) begin
			regDataRX <= dataRX; 
		end
	end
    end
	
    assign wr_f = (WR_RX & ~wr1);  // wr_f is 1 during one clock cycle only. wr_f1 it's the same but with one cycle delayed.
    

    
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
		finalDir <= right;
    		beginDir <= right;
		//prevRegData <= 0;
	end
	else begin 
		if (!lastValidReg[8] && finalX == segmentsReg[lastValidReg][11:2] && finalY == segmentsReg[lastValidReg][21:12]) begin
			segmentsReg[lastValidReg] <= 0;
			if (!(&lastValidReg)) begin 
					finalDir <= segmentsReg[lastValidReg][1:0];
			end
		end
		else if (wr_f2 && (regDataRX >= 65 || regDataRX <= 68)) begin  //&& (regDataRX != prevRegData)
			//prevRegData <= regDataRX;
			case (regDataRX) 
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


 //----------------------------
 //   Position actualization
 //----------------------------
   
    reg updateSnakePosition = 0;

    always @(posedge clk) updateSnakePosition <= (x_px == 639) & (y_px == 479);

    always @(posedge clk) begin 
	if (!rstn) begin
		beginX <= initialPositionBeginX;
    		finalX <= initialPositionFinalX;
    		beginY <= initialPositionBeginY;
    		finalY <= initialPositionFinalY;
	end 
	else begin
		if (updateSnakePosition) begin
			//añadir colisiones
			case (beginDir)
			    right: beginX <= beginX + 1;
			    left : beginX <= beginX - 1;
			    up   : beginY <= beginY - 1;
			    down : beginY <= beginY + 1;
			endcase
			case (finalDir)
			    right: finalX <= finalX + 1;
			    left : finalX <= finalX - 1;
			    up   : finalY <= finalY - 1;
			    down : finalY <= finalY + 1;
			endcase
		end
	end
    end
	

 //-------------------------------------
 //   Drawing and collition management
 //-------------------------------------
   
    reg [2:0] draw_collision;
    wire collision;  //collision is 1 if the snake collides aginst itself or against the frame

    always @(*) begin
	draw_collision = 0;
	if (!lastValidReg[8]) begin
		case (finalDir)
	   	  right: if (x_px > finalX - 8 && x_px < segmentsReg[lastValidReg][11:2] + 8 && y_px > finalY - 8 && y_px < finalY + 8)  draw_collision = draw_collision + 1;   
	  	  left : if (x_px > segmentsReg[lastValidReg][11:2] - 8 && x_px < finalX + 8 && y_px > finalY - 8 && y_px < finalY + 8)  draw_collision = draw_collision + 1;
	  	  up   : if (x_px > finalX - 8 && x_px < finalX + 8 && y_px < finalY + 8 && y_px > segmentsReg[lastValidReg][21:12] - 8)  draw_collision = draw_collision + 1;
         	  down : if (x_px > finalX - 8 && x_px < finalX + 8 && y_px < segmentsReg[lastValidReg][21:12] + 8 && y_px > finalY - 8)  draw_collision = draw_collision + 1;
		endcase
		for (i = maxTwists; i > 0; i = i - 1) begin
			if (isEmpty[i]) begin
				case (segmentsReg[i][1:0])
	   	  		  right: if (x_px > segmentsReg[i][11:2] - 8 && x_px < segmentsReg[i-1][11:2] + 8 && y_px > segmentsReg[i-1][21:12] - 8 && y_px < segmentsReg[i-1][21:12] + 8)  draw_collision = draw_collision + 1;   
	  	  		  left : if (x_px > segmentsReg[i-1][11:2] - 8 && x_px < segmentsReg[i][11:2] + 8 && y_px > segmentsReg[i-1][21:12] - 8 && y_px < segmentsReg[i-1][21:12] + 8)  draw_collision = draw_collision + 1;
	  	  		  up   : if (x_px > segmentsReg[i-1][11:2] - 8 && x_px < segmentsReg[i-1][11:2] + 8 && y_px < segmentsReg[i][21:12] + 8 && y_px > segmentsReg[i-1][21:12] - 8)  draw_collision = draw_collision + 1;
         	  		  down : if (x_px > segmentsReg[i-1][11:2] - 8 && x_px < segmentsReg[i-1][11:2] + 8 && y_px < segmentsReg[i-1][21:12] + 8 && y_px > segmentsReg[i][21:12] - 8)  draw_collision = draw_collision + 1;
				endcase
			end
		end
		case (beginDir)
	   	  right: if (x_px > segmentsReg[0][11:2] - 8 && x_px < beginX + 8 && y_px > beginY - 8 && y_px < beginY + 8)  draw_collision = draw_collision + 1;   
	  	  left : if (x_px > beginX - 8 && x_px < segmentsReg[0][11:2] + 8 && y_px > beginY - 8 && y_px < beginY + 8)  draw_collision = draw_collision + 1;
	  	  up   : if (x_px > beginX - 8 && x_px < beginX + 8 && y_px < segmentsReg[0][21:12] + 8 && y_px > beginY - 8)  draw_collision = draw_collision + 1;
         	  down : if (x_px > beginX - 8 && x_px < beginX + 8 && y_px < beginY + 8 && y_px > segmentsReg[0][21:12] - 8)  draw_collision = draw_collision + 1;
		endcase
	end
	else begin
		case (finalDir)
	   	  right: if (x_px > finalX - 8 && x_px < beginX + 8 && y_px > finalY - 8 && y_px < finalY + 8)  draw_collision = draw_collision + 1;   
	  	  left : if (x_px > beginX - 8 && x_px < finalX + 8 && y_px > finalY - 8 && y_px < finalY + 8)  draw_collision = draw_collision + 1;
	  	  up   : if (x_px > finalX - 8 && x_px < finalX + 8 && y_px < finalY + 8 && y_px > beginY - 8)  draw_collision = draw_collision + 1;
         	  down : if (x_px > finalX - 8 && x_px < finalX + 8 && y_px < beginY + 8 && y_px > finalY - 8)  draw_collision = draw_collision + 1;
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
		if (draw_collision > 0 && draw_collision < 5)  //Esto no deberia ser asi escribe dos veces en la memoria
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


endmodule

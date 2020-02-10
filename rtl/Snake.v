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


    parameter maxTwists = 10;
    parameter initialPositionBeginX = 40;
    parameter initialPositionFinalX = 20;
    parameter initialPositionBeginY = 25;
    parameter initialPositionFinalY = 25;
 

    //parameters of the sprites
    localparam SpriteSIZE = 8;
    localparam QUANTITY = 5;
    localparam bitsPerSprite = SpriteSIZE*SpriteSIZE;
    localparam totalBits = bitsPerSprite * QUANTITY;


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
    reg [1:0] beginDir = up;

    
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


    integer i; //variable for loops

    
    //--------------------------------------------------------------------------------------
    //    Register with positions and directions of the different segments of the snake
    //--------------------------------------------------------------------------------------
    reg [21:0] segmentsReg [0:maxTwists];  //the snake can turn 71 times.  Yposition[21:12] + Xposition[11:2] + Direction[1:0] = 22 bits. 
						//reducir tama�os
    reg [0:70] isEmpty;
    reg [8:0]  lastValidReg; 

    

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
	for (i = 0; i <= maxTwists ; i = i + 1) begin
		if (isEmpty[i])
			lastValidReg = lastValidReg + 1;
	end
	lastValidReg = lastValidReg - 1;
    end


    always @(posedge px_clk) begin
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
   //frame ram signals
   wire [12:0] frame_addr; 
   reg frame_write; 
   wire  [2:0] frame_data_i;
   wire [2:0] frame_data_o;

   //sprites ram signals
   wire [8:0] sprite_addr; 
   reg sprite_write = 0, sprite_data_i; 
   wire sprite_data_o;



   sram #(.ADDR_WIDTH(13), .DATA_WIDTH(3), .DEPTH(4800), .INIT(0)) 
	ramFrame (.i_clk(px_clk), .i_addr(frame_addr), .i_write(frame_write), .i_data(frame_data_i), .o_data(frame_data_o) );

   sram ramSprites(.i_clk(px_clk), .i_addr(sprite_addr), .i_write(sprite_write), .i_data(sprite_data_i), .o_data(sprite_data_o) );


   wire [2:0] SpriteIndex;
   reg [6:0] gridPositionX = 0;
   reg [6:0] gridPositionY = 0;
   reg [6:0] gridPositionXmem = 0;
   reg [6:0] gridPositionYmem = 0;

   
    reg frameEnded = 0;
    reg [7:0] framesCounter = 0;
    wire [1:0] rotation;
    reg [1:0] beginRotation = 0;
    reg [1:0] finalRotation = 0;


    //fsm to control the ram writing and the collision detection
    //states: waiting = 2'b00, write final = 2'b01, collision detection = 2'b10, write begin = 2'b11
    reg  [1:0] state = 2'b00;
    reg [1:0] n_state;

    reg updateBegin;
    wire [12:0] memory_position_write;

    reg beginSprite;
    reg finalSprite;

    reg endOfFrameCounterEN;
    always @(posedge px_clk) frameEnded <= (x_px == 639) & (y_px == 479);

    reg [7:0] writeCounter = 0;
    always @(posedge px_clk) if (!endOfFrameCounterEN) writeCounter <= 0; else writeCounter <= writeCounter + 1;
    

    always @( posedge clk) if (!rstn) state <= 0; else state <=  n_state;
    always @(*) begin
	//endOfFrameCounterEN <= 1;
	n_state <= state;
	endOfFrameCounterEN <= 0;
	case (state)
		2'b00: begin
			//endOfFrameCounterEn <= 0;
			frame_write <= 0;
			updateBegin <= 0;
			if (frameEnded) 
				n_state <= 2'b01;
			end
		2'b01: begin
			frame_write <= 0;//=1
			updateBegin <= 0;
			n_state <= 2'b10;
			end
		2'b10: begin
			frame_write <= 0;
			updateBegin <= 0;
			n_state <= 2'b11;
			end
		2'b11: begin
			endOfFrameCounterEN <= 1;
			frame_write <= 1;
			updateBegin <= 1;	
			if (writeCounter == 10)	
			n_state <= 2'b00;
			end
	endcase
	updateBegin <= 1;
	
    end
    



    //algo falla aqui

    assign memory_position_write = (updateBegin) ? beginY * 80 + beginX : finalY * 80 + finalX;
    assign frame_data_i = (updateBegin) ? beginSprite : finalSprite;

    assign rotation = (gridPositionX == beginX[6:0] && gridPositionY == beginY[6:0])  ? beginRotation : beginRotation;//finalRotation;



    

    always @(posedge px_clk) begin 
	if (!rstn) begin
		beginX <= initialPositionBeginX;
    		finalX <= initialPositionFinalX;
    		beginY <= initialPositionBeginY;
    		finalY <= initialPositionFinalY;
		beginSprite <= 0;
		finalSprite <= 0;
		framesCounter <= 0;
		beginRotation <= 0;
		//habria que reiniciar la memoria?�?�
	end 
	else begin
		if (frameEnded) begin
			framesCounter <= framesCounter + 1;
			case (framesCounter)
			  0: begin
				beginSprite <= 1;
				//finalSprite <= 3;
			     end
			  50: begin
				beginSprite <= 2;
				//finalSprite <= 2;
			     end
			  100: begin
				beginSprite <= 3;
				//finalSprite <= 1;
			     end
			  150: begin
				beginSprite <= 4;
				//finalSprite <= 0;
			     end
			endcase
			if (framesCounter == 0) begin
				case (beginDir)
			  	  right: begin 
					 beginX <= beginX + 1;
					 beginRotation <= 0;
					 end 
			  	  left : begin 
					  beginX <= beginX - 1;
					  beginRotation <= 1;
					 end 
			   	  up   : begin 
					  beginY <= beginY - 1;	
					  beginRotation <= 2;
					 end
			   	  down : begin
					  beginY <= beginY + 1;
					  beginRotation <= 3;
					 end
				endcase
				case (finalDir)
			  	  right: begin 
					 finalX <= finalX + 1;
					 finalRotation <= 0;
					 end 
			  	  left : begin 
					  finalX <= finalX - 1;
					  finalRotation <= 1;
					 end 
			   	  up   : begin 
					  finalY <= finalY - 1;	
					  finalRotation <= 2;
					 end
			   	  down : begin
					  finalY <= finalY + 1;
					  finalRotation <= 3;
					 end
				endcase
			end
		end
	end
    end
	


 //-------------------------------------
 //   Drawing and collition management
 //-------------------------------------


   wire [9:0] n_x_px, n_y_px;
   assign n_x_px = (x_px == 639) ? 0 : x_px + 1; 
   assign n_y_px = (x_px != 639) ? y_px :
                   (y_px == 479) ? 0 : y_px + 1;//creo que no es necesario

   wire [9:0] n2_x_px, n2_y_px;
   assign n2_x_px = (x_px == 638) ? 0 : 
		    (x_px == 639) ? 1 :x_px + 2; 
   assign n2_y_px = (x_px <  638) ? y_px :
                    (y_px == 479) ? 0 : y_px + 1;// creo que no es necesario

   always @(posedge px_clk) begin
	if (!rstn) begin
		gridPositionX <= 0;
		gridPositionY <= 0;
		gridPositionXmem <= 0;
		gridPositionYmem <= 0;
	end
	else begin
		if (n_x_px[2:0] == 3'b000 || n_y_px[2:0] == 3'b000) begin
			gridPositionX <= n_x_px[9:3];
			gridPositionY <= n_y_px[9:3];
		end
		if (n2_x_px[2:0] == 3'b000 || n2_y_px[2:0] == 3'b000) begin
			gridPositionXmem <= n2_x_px[9:3];
			gridPositionYmem <= n2_y_px[9:3];
		end
	end 
   end


   assign frame_addr = (!frame_write) ? Vwidth/8 * gridPositionY + gridPositionXmem : memory_position_write;
   assign SpriteIndex = frame_data_o;

   assign sprite_addr = (rotation == 0) ? SpriteIndex * bitsPerSprite + (y_px - {gridPositionY, 3'b000}) * SpriteSIZE + (x_px - {gridPositionX, 3'b000}) :        //0�
                        (rotation == 1) ? SpriteIndex * bitsPerSprite + (y_px - {gridPositionY, 3'b000}) * SpriteSIZE + (7 - (x_px - {gridPositionX, 3'b000})) :  //180�
                        (rotation == 2) ? SpriteIndex * bitsPerSprite + (x_px - {gridPositionX, 3'b000}) * SpriteSIZE + (7 - (y_px - {gridPositionY, 3'b000})) :   //90�
                         SpriteIndex * bitsPerSprite + (x_px - {gridPositionX, 3'b000}) * SpriteSIZE + (y_px - {gridPositionY, 3'b000}) ;                          //270�

   
    always @(posedge px_clk) begin
        if (!rstn) begin 
                R_int <= 4'b0;
                G_int <= 4'b0;
                B_int <= 4'b0;
        end else
        if (activevideo) begin
		G_int <= {sprite_data_o, 3'b000};
       	end
	else 
		G_int <= 4'b0000;
    end




endmodule
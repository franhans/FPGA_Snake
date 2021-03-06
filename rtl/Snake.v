module snake (
    //input clk,	              // 25MHz clock input
    input px_clk,	      // 31MHz clock input
    input rstn,               // rstn,
    input [7:0] dataRX,       // Tx from the computer
    input WR_RX,              // WR_RX is 1 when dataRX is valid, otherwise 0.
    input [9:0] x_px,         // x pixel postition
    input [9:0] y_px,         // y pixel position
    input activevideo,        // activevideo is 1 when x_px and y_px are in the visible zone of the screen.
    output [9:0] points,
    output [11:0] RGB   // Led outputs
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


    parameter maxTwists = 2^6;              //it has to be a power of 2
    parameter initialPositionBeginX = 40;
    parameter initialPositionFinalX = 19;
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
    reg [6:0] beginX = initialPositionBeginX;
    reg [6:0] finalX = initialPositionFinalX;
    reg [6:0] beginY = initialPositionBeginY;
    reg [6:0] finalY = initialPositionFinalY;
    reg [1:0] finalDir = right;
    reg [1:0] beginDir = right;
    reg [1:0] n_beginDir;
    wire [6:0] finalActualizationX;
    wire [6:0] finalActualizationY;

    
    //local signals for UART
    reg  wr1 = 1;
    reg  wr2 = 1;
    wire wr_f;
    reg  wr_f2 = 0;
    reg [7:0] regDataRX = 0;
    reg [7:0] prevRegData = 67;

    //flank detector and register for the data from the UART
    always @(posedge px_clk) begin
	if (!rstn) begin
		wr1 <= 1;
		wr2 <= 1;
		wr_f2 <= 0;
		regDataRX <= 0;
	end
	else begin
		{wr2, wr1} <= {wr1, WR_RX};
		wr_f2 <= wr_f;
		if (wr_f) begin
			regDataRX <= dataRX; 
		end
	end
    end
	
    assign wr_f = (WR_RX & ~wr2);  // wr_f is 1 during one clock cycle only. wr_f1 it's the same but with one cycle delayed.



 //-------------------------------------
 //       Food random generator
 //-------------------------------------

  //A counter is in charge of "generate" a pseudorandom position in the memory to place the food.
   
   reg [9:0] pointCounter = 0;
   reg [9:0] n_pointCounter;
   reg [12:0] foodCounter;
   wire [12:0] n_foodCounter;
   reg [12:0] countIncrement;
   always @(posedge px_clk) if (!rstn) foodCounter <= 0; else foodCounter <= n_foodCounter;
   
   assign n_foodCounter = (foodCounter > 4700) ? 81 :
			  (foodCounter[3:0] == 4'b1110) ? foodCounter + 3: foodCounter + countIncrement;

 //-------------------------------------
 //           Game Reset
 //-------------------------------------
   
   ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
   // - A second frameRam memory is instanciated with the original configuration of the screen
   // - When reset state is reached, content of the second memory will be copied into the main RAM memory.
   // - To achive this a counter is needed.
   ////////////////////////////////////////////////////////////////////////////////////////////////////////////////

   reg active_reset;
   reg [12:0] frameCopy_addr;
   wire [2:0] frameCopy_data_o;
   reg programRST = 1;

   sram #(.ADDR_WIDTH(13), .DATA_WIDTH(3), .DEPTH(4800), .INIT(0)) 
	ramFrameCopy (.i_clk(px_clk), .i_addr(frameCopy_addr), .i_write(0), .i_data(0), .o_data(frameCopy_data_o));

   reg [12:0] resetCounter;
   wire [12:0] n_resetCounter;
   always @(posedge px_clk) resetCounter <= n_resetCounter;
   
   assign n_resetCounter = (!active_reset) ? 0 : resetCounter + 1;
    
    //--------------------------------------------------------------------------------------
    //    Register with positions and directions of the different segments of the snake
    //--------------------------------------------------------------------------------------

    integer i; //variable for loops

    reg writeFIFO;
    reg readFIFO;
    wire [15:0] o_dataFIFO;
    reg [15:0] i_dataFIFO;
    reg [15:0] n_i_dataFIFO;
    wire FIFOisEmpty;
    //reg [15:0] lastPosition = -1;   //Yposition[15:9] + Xposition[8:2] + Direction[1:0] = 16 bits.

    //State machine for FIFO control varibales
    reg [1:0] Fstate = 0;
    reg [1:0] n_Fstate;

    // A FIFO register stores the swerve possitions of the Snake.   
    FIFO #(.DATA_WIDTH(16), .DEPTH(64)) 
    	FIFO1 (.clk(px_clk), .rstn(!programRST), .write(writeFIFO), .read(readFIFO), .i_data(i_dataFIFO), .o_data(o_dataFIFO), .isEmpty(FIFOisEmpty ));


    always @(posedge px_clk) begin
    	if (!rstn || programRST) begin
		finalDir <= right;
    		beginDir <= right;
		prevRegData <= 67;
		Fstate <= 0;
	end
	else begin
		Fstate <= n_Fstate;
		if (Fstate == 2'b01) begin
			finalDir <= o_dataFIFO[1:0];
		end
		if (n_Fstate == 2'b10) begin
			prevRegData <= regDataRX;
			i_dataFIFO <= n_i_dataFIFO;
			beginDir <= n_beginDir;
		end
			
	end
    end

    //A finite machine state controlls the FIFO inputs in order to store and recover positions and directions.

    wire [6:0] savedPositionX;
    wire [6:0] savedPositionY;
    assign savedPositionX = o_dataFIFO[8:2];
    assign savedPositionY = o_dataFIFO[15:9];
    always @(*) begin
	n_Fstate = Fstate;
	readFIFO = 0;
	writeFIFO = 0;
	n_beginDir = 0;
	n_i_dataFIFO = 0;
	case (Fstate)
		2'b00: begin
			if ((!FIFOisEmpty) && (finalX == savedPositionX) &&  (finalY == savedPositionY)) begin
				n_Fstate = 2'b01;
				readFIFO = 0;
			end
			else if (wr_f2 && (((prevRegData != 67 && prevRegData != 68) && (regDataRX == 67 || regDataRX == 68)) || ((prevRegData != 65 && prevRegData != 66) && (regDataRX == 66 || regDataRX == 65))) ) begin
				n_Fstate = 2'b10;
				case (regDataRX) 
			  		65: begin
					n_i_dataFIFO = {beginY, beginX, up};
					n_beginDir = up;
			      		end
			  		66: begin
					n_i_dataFIFO = {beginY, beginX, down};
					n_beginDir = down;
			     		 end
					67: begin
					n_i_dataFIFO = {beginY, beginX, right};
					n_beginDir = right;
			      		end
			  		68: begin
					n_i_dataFIFO = {beginY, beginX, left};
					n_beginDir = left;
			      		end
				endcase
			end
		       end
		2'b01: begin
			n_Fstate = 2'b00;
			readFIFO = 1;
			writeFIFO = 0;
		       end
		2'b10: begin
			n_Fstate = 2'b00;
			readFIFO = 0;
			writeFIFO = 1;
		       end
	endcase
	
    end







 //----------------------------------------------------
 //   Position actualization and collision management
 //----------------------------------------------------
   //frame ram signals
   wire [12:0] frame_addr; 
   reg [2:0] frame_write; 
   wire  [2:0] frame_data_i;
   wire [2:0] frame_data_o;

   //sprites ram signals
   wire [8:0] sprite_addr; 
   reg sprite_write = 0; 
   wire sprite_data_o;



   sram #(.ADDR_WIDTH(13), .DATA_WIDTH(3), .DEPTH(4800), .INIT(0)) 
	ramFrame (.i_clk(px_clk), .i_addr(frame_addr), .i_write(frame_write[0]), .i_data(frame_data_i), .o_data(frame_data_o));

   sram ramSprites(.i_clk(px_clk), .i_addr(sprite_addr), .i_write(1'b0), .i_data(1'b0), .o_data(sprite_data_o));


   wire [2:0] SpriteIndex;
   reg [6:0] gridPositionX = 0;
   reg [6:0] gridPositionY = 0;
   reg [6:0] gridPositionXmem = 0;
   reg [6:0] gridPositionYmem = 0;
   //reg [6:0] gridPositionYmem = 0;

   
    reg frameEnded = 0;
    reg [2:0] framesCounter = 0;
    wire [1:0] rotation;
    wire [1:0] beginRotation;
    wire [1:0] finalRotation;


    //Frame memory sate machine controller.
    reg  [2:0] Wstate = 3'b000;
    reg [2:0] n_Wstate;

    reg [2:0] updateBegin;
    wire [12:0] memory_position_write;

    wire [12:0] collision_position;
    reg activeFoodCollision;
    reg foodCollision;

    reg [2:0] beginSprite;
    reg [2:0] finalSprite;

    reg collision, n_collision;

    always @(posedge px_clk) begin
	if (!rstn || programRST) begin
		collision <= 0;
		frameEnded <= 0;
		pointCounter <= 0;
	end
	else begin
		frameEnded <= (x_px == 639) & (y_px == 479);
		collision <= n_collision;
		pointCounter <= n_pointCounter;
	end
    end

    assign points = pointCounter;
    

    always @( posedge px_clk) if (!rstn) Wstate <= 0; else Wstate <=  n_Wstate;
    always @(*) begin
	n_Wstate = Wstate;
	n_pointCounter = pointCounter;
	n_collision = 0;
	frame_write = 0;
	updateBegin = 0;
        activeFoodCollision = 0;
	countIncrement = 1;
	frameCopy_addr = 0;
        programRST = 0;
	case (Wstate)
		3'b000: begin                           //detects that the frame is over
			 frame_write = 3'b000;
			 updateBegin = 0;
			 if (frameEnded) 
				n_Wstate = 3'b001;
			 if (active_reset)
				n_Wstate = 3'b111;
			end
		3'b001: begin				//looks for a collision with the food
			 frame_write = 3'b010;
			 updateBegin = 1;
			 n_Wstate = 3'b010;
			end
		3'b010: begin				//write the position of the final of the snake
			 if (SpriteIndex != 5) begin //&& framesCounter == 0
				frame_write = 3'b001;
				updateBegin = 0;
				n_Wstate = 3'b101;

			 end 
			 else if (SpriteIndex == 5 && framesCounter == 7) begin

				n_Wstate = 3'b011;
				activeFoodCollision = 1;
			 end else 
			 begin
				updateBegin = 2'b11;
				frame_write = 3'b001;
				n_Wstate = 3'b101;
			end
		       end
		3'b011: begin				//Read the memory of the spot to place the food, if it is already bussy, it changes the position.
			 frame_write = 3'b100;
			 updateBegin = 2'b00;
			 n_Wstate = 3'b100;
			 countIncrement = 0;
			end
		3'b100: begin				//Draw a new food and increase puntuation
			 if (SpriteIndex == 0) begin
			 	frame_write = 3'b011;
			 	updateBegin = 2'b10;
			 	n_Wstate = 3'b101;
				n_pointCounter = pointCounter +1;
			 end 
			 else begin
				countIncrement = 1000;
				n_Wstate = 3'b011;
			 end
			end
		3'b101: begin				//looks for a collision with the snake itself or the border
			 frame_write = 3'b010;
			 updateBegin = 2'b01;
			 n_Wstate = 3'b110;
			end
		3'b110: begin				//write the position of the begining of the snake and triggers the flow state machine if there is a collision
			 if (SpriteIndex == 4 && framesCounter == 7) begin
				n_collision = 1;
				n_Wstate = 3'b111;
			 end
			 frame_write = 1;
			 updateBegin = 1;		
			 n_Wstate = 3'b00;
			end
		3'b111: begin				//Handels the reset of the ram
			 if (resetCounter == 1)
				frameCopy_addr = 0;
			 else if (resetCounter <= 4800) begin
				frameCopy_addr = resetCounter - 1;
				frame_write = 3'b001;
				updateBegin = 4;
			 end 
			 else if (resetCounter <= 4820)
				programRST = 1;
			 else
				n_Wstate = 3'b000;
			end
	endcase
	
    end
    
   
    //  Memory_postion_write is a multiplexed signal which is itself multiplexed as well. Different processes during the game
    //  will change the variable updateBegin and frame_write to control the input signals for ramFrame block. (More about this later).
    assign memory_position_write = (updateBegin == 1) ? beginY * 80 + beginX : 
				   (updateBegin == 4) ? resetCounter -2: finalY * 80 + finalX;
    assign frame_data_i = (updateBegin == 1) ? beginSprite : 
			  (updateBegin == 0) ? finalSprite :  
			  (updateBegin == 2) ? 5 :
			  (updateBegin == 3) ? 4 : frameCopy_data_o;

    assign rotation = (gridPositionX == beginX[6:0] && gridPositionY == beginY[6:0])  ? beginRotation : finalRotation;

    assign collision_position = (beginDir == right) ? beginY * 80 + beginX + 1:
				(beginDir == left ) ? beginY * 80 + beginX - 1:
				(beginDir == up   ) ? (beginY - 1) * 80 + beginX : (beginY + 1) * 80 + beginX; 


    
    //every 2 frames, sprite is upload, every 8 frames, position is upload. (make snake go faster?)

    always @(posedge px_clk) begin 
	if (!rstn || programRST) begin
		beginX <= initialPositionBeginX;
    		finalX <= initialPositionFinalX;
    		beginY <= initialPositionBeginY;
    		finalY <= initialPositionFinalY;
		beginSprite <= 0;
		finalSprite <= 0;
		framesCounter <= 0;	
	end 
	else begin
		if (frameEnded) begin
			framesCounter <= framesCounter + 1;
			case (framesCounter)
			  0: begin
				beginSprite <= 1;
				finalSprite <= 3;
			     end
			  2: begin
				beginSprite <= 2;
				finalSprite <= 2;
			     end
			  4: begin
				beginSprite <= 3;
				finalSprite <= 1;
			     end
			  6: begin
				beginSprite <= 4;
				finalSprite <= 0;
			     end
			endcase
			if (framesCounter == 0) begin
				case (beginDir)
			  	  right: begin 
					 beginX <= beginX + 1;
					 end 
			  	  left : begin 
					  beginX <= beginX - 1;
					 end 
			   	  up   : begin 
					  beginY <= beginY - 1;	
					 end
			   	  down : begin
					  beginY <= beginY + 1;
					 end
				endcase

				finalX <= finalX + finalActualizationX;
				finalY <= finalY + finalActualizationY;
			end
		end
	end
    end
	
    // head and tail may not have the same rotation, so rotattion must be different for both of them, and these signals
    // are multiplexed using the signal rotation
    assign beginRotation = (beginDir == right) ? 0:
                           (beginDir == left ) ? 1:
                           (beginDir == up   ) ? 2: 3;

    assign finalRotation = (finalDir == right) ? 1:
                           (finalDir == left ) ? 0:
                           (finalDir == up   ) ? 3: 2;


    // The position of the tail is changed every 4 frames, however, this change is different when the snake eat one piece of food.
    assign finalActualizationX = (finalDir == right && !foodCollision) ?  1 :
				 (finalDir == left  && !foodCollision) ? -1 :
				 (finalDir == right && foodCollision ) ? -1 :
				 (finalDir == left  && foodCollision ) ?  1 : 0;

    assign finalActualizationY = (finalDir == up   && !foodCollision) ? -1 :
				 (finalDir == down && !foodCollision) ?  1 :
				 (finalDir == up   && foodCollision ) ?  1 :
				 (finalDir == down && foodCollision ) ? -1 : 0;
 


 //--------------
 //   Drawing 
 //--------------
   reg [1:0] flowState, n_flowState;
   reg [9:0] keepRow;

   wire [9:0] n_x_px, n_y_px;
   assign n_x_px = (x_px != 639) ? x_px + 1 : 0;

   assign n_y_px = (x_px == 0) ? keepRow + 1 : y_px;


   wire [9:0] n2_x_px;
   assign n2_x_px = (x_px >= 638) ? 0 :x_px + 2; 

   /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   // - y_px and x_px are registered in a register when the grid is change.
   // - Since it takes one cycle to store x_px and y_px in gridPosition, the next x_px is stored instead (n_px)
   // - Since updating the output of the memory frame_data_o takes one additional cycle, gridPositionXmem is updated
   //   using n2_x_px which is x_px two cycles ahead in time (x_px + 2)
   // - When screen line has finished x_px > 639, x_px and y_px are equal to 0, so y_px must be stored in a register
   //   in order to not to lose that information.
   ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

   always @(posedge px_clk) begin
	if (!rstn  || programRST) begin
		gridPositionX <= 0;
		gridPositionY <= 0;
		gridPositionXmem <= 0;
		gridPositionYmem <= 0;
		keepRow <= 0;
	end
	else begin 
		if (x_px == 639)
			keepRow <= y_px;
		if (n_x_px[2:0] == 3'b000 || n_y_px[2:0] == 3'b000) begin
			gridPositionX <= n_x_px[9:3];
			gridPositionY <= n_y_px[9:3];
		end
		if (n2_x_px[2:0] == 3'b000 || y_px[2:0] == 3'b000) begin
			gridPositionXmem <= n2_x_px[9:3];
		end
	end 
   end

   //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   // - The input of the memory which stores the frame must be multiplexed because depending on the state of the game
   //   different approaches are used. For example, in reset all memory possitions are overwrited while most of the time
   //   the memory is being read to print the screen. At the end of every frame the position of the head and the position
   //   of the tail are overwrite.   
   // - Besides, the last bit of frame_write controlls frame memory write.
   // - memory_position_write it is also multiplexed
   //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
   
   assign frame_addr = (frame_write == 3'b000) ? Vwidth/8 * gridPositionY + gridPositionXmem : 
			(frame_write == 3'b001) ? memory_position_write : 
                        (frame_write == 3'b010) ? collision_position : foodCounter;

   assign SpriteIndex = frame_data_o;

   assign sprite_addr = (rotation == 0) ? SpriteIndex * bitsPerSprite + (y_px - {gridPositionY, 3'b000}) * SpriteSIZE + (x_px - {gridPositionX, 3'b000}) :         //0�
                        (rotation == 1) ? SpriteIndex * bitsPerSprite + (y_px - {gridPositionY, 3'b000}) * SpriteSIZE + (7 - (x_px - {gridPositionX, 3'b000})) :   //180�
                        (rotation == 2) ? SpriteIndex * bitsPerSprite + (x_px - {gridPositionX, 3'b000}) * SpriteSIZE + (7 - (y_px - {gridPositionY, 3'b000})) :   //90�
                         SpriteIndex * bitsPerSprite + (x_px - {gridPositionX, 3'b000}) * SpriteSIZE + (y_px - {gridPositionY, 3'b000}) ;                          //270�*/

   
    always @(posedge px_clk) begin
        if (!rstn) begin 
                R_int <= 4'b0;
                G_int <= 4'b0;
                B_int <= 4'b0;
        end else
        if (activevideo & !active_reset) begin
		G_int <= {sprite_data_o, 3'b000};
       	end
	else 
		G_int <= 4'b0000;
    end









 //-------------------------------------
 //           Game Flow
 //-------------------------------------



    always @( posedge px_clk) if (!rstn) flowState <= 0; else flowState <=  n_flowState;
    always @(*) begin
	n_flowState = flowState;
	active_reset = 0;
	foodCollision = 0;
	case (flowState)
		2'b00: begin
			if (activeFoodCollision)
				n_flowState = 2'b11;
			else if (collision) 
				n_flowState = 2'b01;

			end
		2'b01: begin
			if (frameEnded)
				n_flowState = 2'b10;
			end
		2'b10: begin
			active_reset = 1;
			if (resetCounter == 4821)
				n_flowState = 2'b00;
			end
		2'b11: begin
			foodCollision = 1;
			if (framesCounter == 1)
				n_flowState = 02'b00;
		      end 
	endcase
	
    end






endmodule

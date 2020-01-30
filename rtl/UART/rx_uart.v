module rxuart(
	input	wire		i_clk,
	input	wire		i_uart_rx,
	input   wire            rst,
	output	reg		o_wr,
    	output	wire	[7:0]	o_data
);


localparam clk_frequency = 25e6; //25 MHz
parameter baudRate = 9600;
parameter if_parity = 0; // 0 no parity, 1 parity even
localparam [15:0] clocksPerBaud = clk_frequency/baudRate;

//STATES
localparam [2:0] IDLE   = 3'b000;
localparam [2:0] START  = 3'b001;
localparam [2:0] DATA   = 3'b010;
localparam [2:0] PARITY = 3'b011;
localparam [2:0] STOP   = 3'b100;



reg  [2:0]  state = IDLE;
reg  [2:0]  next_state;
reg  [15:0] baudSync = 0;
wire [15:0] next_baudSync;
reg  [2:0]  dataCounter = 0;
reg  [7:0]  data = 0;
reg  [7:0]  next_data;



// 2FF synchronizer
reg rx  = 1; 
reg rx1 = 1;

always @(posedge i_clk) begin
	if (!rst) begin
		rx <= 0;
		rx1 <= 0;
	end
	else
		{rx, rx1} <= {rx1, i_uart_rx};
end


// Baud counter, Data counter and states
assign next_baudSync = (state == IDLE) ? 0 : 
		       (baudSync == clocksPerBaud-1) ? 0 : baudSync + 1;

always @(posedge i_clk) begin
	if (!rst)  begin
		baudSync <= 0;
		dataCounter <= 0;
		state <= IDLE;
		data <= 0;
	end
	else begin
		state <= next_state;
		baudSync <= next_baudSync;
		data <= next_data;
		if (baudSync == clocksPerBaud-1 && state == DATA) 
			dataCounter <= dataCounter + 1'b1;
	end				
end



//State machine
always @(state or baudSync or dataCounter or rx or data) begin
	o_wr <= 0;
	next_state <= state;
	next_data <= data;
	case (state)
		IDLE: begin
			if (!rx) 
				next_state <= START;
			end
		START: begin
			if (baudSync == clocksPerBaud-1)
				next_state <= DATA;
			end
		DATA: begin
			if (baudSync == clocksPerBaud/2-1)
				next_data <= {rx, data[7:1]};
			if (dataCounter == 7 && baudSync == clocksPerBaud-1)
				if (if_parity)
					next_state <= PARITY;
				else 
					next_state <= STOP;
			end
		PARITY: begin
				next_state <= STOP;
			end
		STOP: begin
			o_wr <= 1;
			if (baudSync == clocksPerBaud/2-1)
				next_state <= IDLE;
			end
	endcase
end


assign o_data = data;


endmodule




// S0: simple bitwise logic (unchanged)
module S0_module #(
  parameter N = 8
)(
  input  logic [N-1:0] a, b, c,
  output logic [N-1:0] out
);
  always_comb begin
    // “mask a with b, then inject c”
    out = (a & b) | c;
  end
endmodule


// S1: "mix" by XOR then add
module S1_module #(
  parameter N = 8
)(
  input  logic [N-1:0] a, b, c,
  output logic [N-1:0] out
);
  always_comb begin
    // cheap “scramble”: XOR then add c
    out = (a ^ b) + c;
  end
endmodule


// S2: absolute difference of a and b, then XOR with c
module S2_module #(
  parameter N = 8
)(
  input  logic [N-1:0] a, b, c,
  output logic [N-1:0] out
);
  logic [N-1:0] diff;
  always_comb begin
    if (a >= b)
      diff = a - b;
    else
      diff = b - a;

    out = diff ^ c;
  end
endmodule


// S3: min(a,b) blended with c
module S3_module #(
  parameter N = 8
)(
  input  logic [N-1:0] a, b, c,
  output logic [N-1:0] out
);
  logic [N-1:0] min_ab;
  always_comb begin
    min_ab = (a <= b) ? a : b;
    // keep low bits from min, high bits from c
    out   = { c[N-1:N/2], min_ab[N/2-1:0] };
  end
endmodule


// S4: max(a,b) plus a small shift of c
module S4_module #(
  parameter N = 8
)(
  input  logic [N-1:0] a, b, c,
  output logic [N-1:0] out
);
  logic [N-1:0] max_ab;
  always_comb begin
    max_ab = (a >= b) ? a : b;
    // cheap “boost” of c: left shift by 1, no variable shift
    out    = max_ab + (c << 1);
  end
endmodule


// S5: saturating add of a and b, then AND with c
module S5_module #(
  parameter N = 8
)(
  input  logic [N-1:0] a, b, c,
  output logic [N-1:0] out
);
  logic [N:0] sum_ext;     // one extra bit for overflow
  logic [N-1:0] sat_sum;

  always_comb begin
    sum_ext = a + b;       // N+1 bits
    // If the top carry (sum_ext[N]) is 1, clamp to all 1s
    sat_sum = sum_ext[N] ? {N{1'b1}} : sum_ext[N-1:0];
    out     = sat_sum & c;
  end
endmodule


// S6: average of a and b, then OR with c
module S6_module #(
  parameter N = 8
)(
  input  logic [N-1:0] a, b, c,
  output logic [N-1:0] out
);
  logic [N-1:0] avg_ab;
  always_comb begin
    // average using bit trick: (a & b) + ((a ^ b) >> 1)
    avg_ab = (a & b) + ((a ^ b) >> 1);
    out    = avg_ab | c;
  end
endmodule


// S7: simple rotate-left of a by 1, then XOR with b and c
module S7_module #(
  parameter N = 8
)(
  input  logic [N-1:0] a, b, c,
  output logic [N-1:0] out
);
  logic [N-1:0] rotl1;
  always_comb begin
    // rotate-left by 1: {a[N-2:0], a[N-1]}
    rotl1 = { a[N-2:0], a[N-1] };
    out   = rotl1 ^ b ^ c;
  end
endmodule


// Step 0a - Create a module with input / output variable
module fsm_design #(
			// Step 1a - Define parameters, if necessary
		     parameter N = 64,
		     parameter N_width = 4	
		     )
			( // Step 1b - Define all inputs and output
				input logic 		   clk, rst, start, input_enable, 
				input logic [N_width-1:0]  a, b,
				input logic [1:0] 	   op_val,
				output logic [3:0] 	   state_res,
			    output logic               output_valid,
				output logic [N_width-1:0] out
			);
   
   // step 2 - Create the State Machine Information
   
   // Step 2a - Create the enum for all the states
   // Note: It is industry convention to put IDLE first, but I put S0 ... S7 first 
   // So that the output waveforms are easier to read for students (S0 being state 0, and so on)
   typedef enum logic [3:0] {
  	 S0, S1, S2, S3, S4, S5, S6, S7, IDLE, INPUT, OUTPUT      
   } state_t;
   
   // Step 2b - Create the state variables for the current and next states
   state_t state, next_state;    
   
   // Step 3 - Set up pipeline logics (to represent registers)
   // Step 3a - Set logic to hold nputs that are the full length
   // Note: I am calling the "reg" out of years of habit of Verilog coding 
   // and this makes it easier for me to think of sequential elements   
   logic [N-1:0] 				   a_input_reg;
   logic [N-1:0] 				   b_input_reg;   
   logic [2:0] 					   op_val_reg;
    

  // Step 3b - Set logic to hold results 
   logic [N-1:0] 				   result_reg;
   logic [N-1:0]	               output_valid_reg;
 

   // Step 4 - Get the intermediate result wires for the outputs for each state
   // as well as the out_driver_wire to drive the result_reg
   logic [N-1:0] 				   S0_res_wire;
   logic [N-1:0] 				   S1_res_wire;
   logic [N-1:0] 				   S2_res_wire;
   logic [N-1:0] 				   S3_res_wire;
   logic [N-1:0] 				   S4_res_wire;
   logic [N-1:0] 				   S5_res_wire;
   logic [N-1:0] 				   S6_res_wire;
   logic [N-1:0] 				   S7_res_wire;
   logic [N-1:0] 				   out_driver_wire;   
   
   
   // Step 5 - Create the combinational operations
   // result_reg is the previous result 
   S0_module #(.N(N)) S0_inst(a_input_reg, b_input_reg, result_reg, S0_res_wire);
   S1_module #(.N(N)) S1_inst(a_input_reg, b_input_reg, result_reg, S1_res_wire);
   S2_module #(.N(N)) S2_inst(a_input_reg, b_input_reg, result_reg, S2_res_wire);
   S3_module #(.N(N)) S3_inst(a_input_reg, b_input_reg, result_reg, S3_res_wire);
   S4_module #(.N(N)) S4_inst(a_input_reg, b_input_reg, result_reg, S4_res_wire);
   S5_module #(.N(N)) S5_inst(a_input_reg, b_input_reg, result_reg, S5_res_wire);
   S6_module #(.N(N)) S6_inst(a_input_reg, b_input_reg, result_reg, S6_res_wire);
   S7_module #(.N(N)) S7_inst(a_input_reg, b_input_reg, result_reg, S7_res_wire);
   
   
   // Step 6 - Set up the count for the read-in and read-out
   // Step 6a - Logic for the Byte Count for the loop
   localparam int count_width = $clog2(N) -  $clog2(N_width);
   localparam int count_max = ( 1 << count_width ) - 1;
   
   // Step 6b - Create the counter storage result itself
   logic [count_width-1:0] 			   byte_count;  
   
   
   // Step 7 - Set up the State Function
   always_ff @(posedge clk or negedge rst) begin
      
      // Step 7a - Asynchronous rst Case
      if(!rst) begin
	 
         // Step 7b - Set the state to IDLE
         state <= IDLE;
	 
      end
      
      // Step 7c - Set the state to the next state
      else begin
         state <= next_state;   
      end
      
   end
   
   
   // Step 8 - Set up the Combinational Operations
  always_comb begin
      
      // Step 8a - Set the next state to state
      next_state = state;
      
      // Step 8b - Implement the Finite State Machine 
      case (state)
        IDLE:
          if (start) begin
             next_state = INPUT;
          end
	
        INPUT:
          if (byte_count == count_max) begin
				next_state = S0;
             end
        
        S0: begin
           if (op_val == 0 || op_val == 1) begin
              next_state = S0;
           end
           
           else if ( op_val == 2 ) begin
              next_state = S4;
           end
           
           else begin
              next_state = S1;
           end
           
    	end
	
        S1: begin
           if( op_val == 0 )begin
              next_state = S0;
           end
           
           else if ( op_val == 1 )begin
              next_state = S1;
           end
           
           else if ( op_val == 2 )begin
              next_state = S5;
           end    
           
           else begin
              next_state = S2;
           end
           
        end
	
        S2: begin
           if( op_val == 0 )begin
              next_state = S1;
           end
           
           else if ( op_val == 1 )begin
              next_state = S2;
           end
           
           else if ( op_val == 2 )begin
              next_state = S6;
           end    
           
           else begin
              next_state = S3;
           end      
        end
        
        S3: begin
           if( op_val == 0 )begin
              next_state = S2;
           end
           
           else if ( op_val == 1 || op_val == 3 ) begin
              next_state = S3;
           end
           
           else if ( op_val == 2 )begin
              next_state = S7;
           end    
        end   
        
        S4: begin
           if( op_val == 0 || op_val == 2 ) begin
              next_state = S4;
           end
           
           else if ( op_val == 1 )begin
              next_state = OUTPUT;
           end
           
           else begin
              next_state = S5;
           end      
        end   
        
        S5: begin
           if( op_val == 0 )begin
              next_state = S4;
          end
           
           else if ( op_val == 1 )begin
              next_state = S1;
           end
           
           else if ( op_val == 2 )begin
              next_state = S5;
           end    
           
           else begin
              next_state = S6;
           end         
        end  
        
        S6: begin
           if( op_val == 0 )begin
              next_state = S5;
           end
           
           else if ( op_val == 1 )begin
              next_state = S2;
           end
           
           else if ( op_val == 2 )begin
              next_state = S6;
           end    
           
           else begin
              next_state = S7;
           end      
        end
        
        S7: begin
           if( op_val == 0 )begin
              next_state = S6;
           end
           
           else if ( op_val == 1 )begin
              next_state = S3;
           end          
           
           else if ( op_val == 2 || op_val == 3 )begin
              next_state = S7;
           end
           
        end
        
        OUTPUT: begin
           if (byte_count == count_max) begin
              next_state = IDLE;
           end          
           
        end        
        
      endcase     
      
   end
   
   
  always_ff @(posedge clk or negedge rst) begin
    
    if (!rst) begin
      byte_count <= '0;           // start clean at 0
    end
    
    else if (state == IDLE) begin
      byte_count <= '0;           // whenever we return to IDLE, reset to 0
    end
    
    else if ((state == INPUT && input_enable) || state == OUTPUT) begin
      // count up, but don't wrap unless you really want to
        byte_count <= byte_count + 1;
    end
    
    else begin
      byte_count <= byte_count;   // hold in other states
    end
    
  end


  always_ff @(posedge clk or negedge rst) begin
    if (!rst) begin
      a_input_reg = '0;
      b_input_reg = '0;
    end
    else if (state == IDLE) begin
      a_input_reg = '0;
      b_input_reg = '0;
    end
    else if (state == INPUT && input_enable) begin
      // Use *current* byte_count as index
      a_input_reg[byte_count*N_width +: N_width] = a;
      b_input_reg[byte_count*N_width +: N_width] = b;
    end
  end



   // Step 11 - Set up printing out the output value
   always_comb begin
      
      // Step 11a - For the negative edge rst, rst all pipeline registers
      if( !rst ) begin
         out = 0;
      end
 
      else if( state != OUTPUT ) begin
         out = 0;
      end
 
      // Step 11b - Otherwise, if in output, set the values to the output
      else if (state == OUTPUT) begin
         out = result_reg[byte_count*N_width +: N_width];	 
      end 
      
   end       
   
     
   // Step 12 - storing values in an intermediate result register
   always_comb begin
      
      // Step 10a - For the negative edge rst, rst all pipeline registers
      if( !rst ) begin
         out_driver_wire = 0;
      end 
      
      else begin    
  
         case(state)       
           S0: out_driver_wire = S0_res_wire;
           S1: out_driver_wire = S1_res_wire;
           S2: out_driver_wire = S2_res_wire;
           S3: out_driver_wire = S3_res_wire;
           S4: out_driver_wire = S4_res_wire;
           S5: out_driver_wire = S5_res_wire;
           S6: out_driver_wire = S6_res_wire;
           S7: out_driver_wire = S7_res_wire;       
         endcase
         
      end
      
   end
     
    // Step 13 - Set up printing the output valid value
   always_comb begin

      if( !rst ) begin
		output_valid_reg = 0;
      end

     else if ( state == OUTPUT ) begin
		output_valid_reg = 1;
      end

      else begin
		output_valid_reg = 0;
      end
            
   end  
  
	always_ff @(posedge clk or negedge rst) begin
	  if (!rst) begin
		result_reg <= '0;
	  end 
		else if (state == IDLE || state == INPUT || state == OUTPUT) begin
		// capture the stage result once per cycle
		result_reg <= result_reg;
	  end else begin
		// IDLE / INPUT / OUTPUT: either hold or clear, your choice
		
		  result_reg <= out_driver_wire;
		// or: result_reg <= '0;
	  end
	end
  
  

   // Step 14 - Set up printing out the output value
   assign state_res = state;
   // assign result_reg = out_driver_wire;
   assign output_valid = output_valid_reg;
   
  
   // Step 0b - Close the module    
endmodule


module tt_um_mmorri22_cse_30342 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  fsm_design #(.N(64), .N_width(4)) design_example(
    .clk(clk),
    .rst(rst_n),
    .start(uio_in[0]),
    .input_enable(uio_in[1]),
    .a(ui_in[3:0]),
    .b(ui_in[7:4]),
	  .op_val(uio_in[3:2]),  
	.output_valid(uio_out[4]),
    .out(uo_out[3:0]),
    .state_res(uo_out[7:4]),
    );

  // avoid linter warning about unused pins:
  wire _unused_pins = ena;   
  
  // Assign enable paths 
  assign uio_oe[0] = 1'b0;
  assign uio_oe[1] = 1'b0;
  assign uio_oe[2] = 1'b0;
  assign uio_oe[3] = 1'b0;
  assign uio_oe[4] = 1'b1;
  assign uio_oe[5] = _unused_pins;
  assign uio_oe[6] = _unused_pins;
  assign uio_oe[7] = _unused_pins;  

  // Set AND with the unused input signals
  // Reference - https://verilator.org/guide/latest/warnings.html#cmdoption-arg-UNUSEDSIGNAL
  wire _unused_ok_4 = 1'b0 & uio_in[4];
  wire _unused_ok_5 = 1'b0 & uio_in[5];
  wire _unused_ok_6 = 1'b0 & uio_in[6];
  wire _unused_ok_7 = 1'b0 & uio_in[7];
  
  // Assign usused pin to the unused uio_out  
  assign uio_out[0] = _unused_pins;
  assign uio_out[1] = _unused_pins;
	assign uio_out[2] = _unused_pins;
	assign uio_out[3] = _unused_pins;
  assign uio_out[5] = _unused_pins;
  assign uio_out[6] = _unused_pins;
  assign uio_out[7] = _unused_pins;  
  
endmodule

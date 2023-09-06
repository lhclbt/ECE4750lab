//========================================================================
// Integer Multiplier Fixed-Latency Implementation
//========================================================================


`ifndef LAB1_IMUL_INT_MUL_BASE_V
`define LAB1_IMUL_INT_MUL_BASE_V

`include "vc/trace.v"
`include "vc/regs.v"
`include "vc/muxes.v"
`include "vc/arithmetic.v"
`include "vc/counters.v"

localparam  INPUT_SIZE = 64;
localparam OUTPUT_SIZE = 32;

// ''' LAB TASK ''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
// Define datapath and control unit here.
// '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

//datapath
module datapath_top
(
  input logic clk,
  input logic reset,
  input logic [INPUT_SIZE - 1:0] istream_msg,

  input logic b_mux_sel,
  output logic b_lsb,

  input logic a_mux_sel,

  input logic result_mux_sel,
  input logic result_en,
  input logic add_mux_sel,

  input istream_rdy,
  input ostream_val,
  output logic [OUTPUT_SIZE - 1:0] ostream_msg 
);

  logic [INPUT_SIZE/2-1:0] a;
  logic [INPUT_SIZE/2-1:0] b;
  assign a = istream_msg[INPUT_SIZE-1:INPUT_SIZE/2];
  assign b = istream_msg[INPUT_SIZE/2-1:0];

  logic [INPUT_SIZE/2-1:0] a_val;

  datapath_b b_block(
    .clk(clk),
    .reset(reset),
    .b(b),
    .b_mux_sel(b_mux_sel),
    .b_lsb(b_lsb)
  );

  datapath_a a_block(
    .clk(clk),
    .reset(reset),
    .a(a),
    .a_mux_sel(a_mux_sel),
    .a_val(a_val)
  );

  datapath_result result_block(
    .clk(clk),
    .reset(reset),
    .a_val(a_val),
    .result_mux_sel(result_mux_sel),
    .result_en(result_en),
    .add_mux_sel(add_mux_sel),
    .istream_rdy(istream_rdy),
    .ostream_val(ostream_val),
    .ostream_msg(ostream_msg)
  );



endmodule

module datapath_b(
  input logic clk,
  input logic reset,
  input logic [31:0] b,

  input logic b_mux_sel,
  output logic b_lsb
);

  logic [INPUT_SIZE/2-1:0] b_reg_before;
  logic [INPUT_SIZE/2-1:0] b_reg_after;
  logic b_lsb_next;
  logic [INPUT_SIZE/2-1:0] next_b;

  //reserve b_value via register
  vc_ResetReg #(
    .p_nbits(INPUT_SIZE/2)
  )b_reg (
      .clk(clk),
      .reset(reset),
      .q(b_reg_after),
      .d(b_reg_before)
    );

  //extract the least significant bit
  //separate read-modify-write, use a temporary wire in combinational block first
  //finish read&modify in combinational block, write in sequential block
  //"modify" means some arithmetic operations or process of reading some value to temp
  /*always_comb
    b_lsb_next = b_reg_after[0];

  //assign temp to port signal in sequential block
  always_ff@(posedge clk) begin
    b_lsb <= b_lsb_next;
  end*/

  //which one is better?(Compared to snippet above )
  assign b_lsb = b_reg_after[0];

  //rule 17. cannot assign an initial value to a logic variable
  logic shifter_bit;   
  always_ff@(posedge clk)
    if (reset) shifter_bit <= 1'b1;

  //one-bit right shifter
  //in this occasion(discarding the overflow), arithmetic right shifter functions the same as logical right shifter for negative number
  logic[INPUT_SIZE/2-1:0] b_shifter;
  logic[INPUT_SIZE/2-1:0] next_b_shifter;

  vc_RightLogicalShifter #(
    .p_nbits(INPUT_SIZE/2)
  ) b_logicshifter (
    .in(b_reg_after),
    .shamt(shifter_bit),
    .out(next_b)
  );
  //managing shift one bit every cycle (synchronized)
  //always_ff@(posedge clk)
   // if (reset) b_shifter <= 0;
    //else  b_shifter <= next_b_shifter;


  //b_mux
  vc_Mux2 #(
    .p_nbits(INPUT_SIZE/2)
  ) b_mux (
    .in0(b),
    .in1(next_b),
    .sel(b_mux_sel),
    .out(b_reg_before)
  );
endmodule

module datapath_a(
  input logic clk,
  input logic reset,
  input logic [INPUT_SIZE/2-1:0] a,
  input logic a_mux_sel,
  output logic [INPUT_SIZE/2-1:0] a_val
);

  logic [INPUT_SIZE/2-1:0] a_reg_before;
  logic [INPUT_SIZE/2-1:0] a_reg_after;
  logic [INPUT_SIZE/2-1:0] next_a;
  logic shifter_bit;   
  always_ff@(posedge clk)
    if (reset) shifter_bit <= 1'b1;


  vc_ResetReg #(
    .p_nbits(INPUT_SIZE/2)
  )a_reg (
      .clk(clk),
      .reset(reset),
      .q(a_reg_after),
      .d(a_reg_before)
    );

  //logic [INPUT_SIZE/2-1:0] a_shifter;
  //logic [INPUT_SIZE/2-1:0] next_a_shifter;
  vc_LeftLogicalShifter #(
    .p_nbits(INPUT_SIZE/2)
  ) a_logicshifter (
    .in(a_reg_after),
    .shamt(shifter_bit),
    .out(next_a)
  );

  //always_ff@(posedge clk)
    //if(reset) a_shifter <= 0;
    //else a_shifter <= next_a_shifter;

  //a_mux
  vc_Mux2 #(
    .p_nbits(INPUT_SIZE/2)
  ) a_mux (
    .in0(a),
    .in1(next_a),
    .sel(a_mux_sel),
    .out(a_reg_before)
  );

  //output a
  //why the snippet cannot be covered?
  //always_comb 
    //a_val = a_reg_after;
  assign  a_val = a_reg_after;  
endmodule

module datapath_result(
  input logic clk,
  input logic reset,
  input [INPUT_SIZE/2-1:0] a_val,
  input result_mux_sel,
  input result_en,
  input add_mux_sel,
  input istream_rdy,
  input ostream_val,
  output [INPUT_SIZE/2-1:0] ostream_msg
);

  logic [INPUT_SIZE/2-1:0] result_reg_before;
  logic [INPUT_SIZE/2-1:0] result_reg_after;
  logic [INPUT_SIZE/2-1:0] result_adder;
  logic [INPUT_SIZE/2-1:0] next_result;
  logic [INPUT_SIZE/2-1:0] result_initial;   
  always_ff@(posedge clk)
    if (reset) result_initial <= 0;

  //result_en is for delaying 
  vc_EnResetReg #(
    .p_nbits(INPUT_SIZE/2)
  ) result_reg (
    .clk(clk),
    .reset(reset),
    .en(result_en),
    .d(result_reg_before),
    .q(result_reg_after)
  );

  vc_Mux2 #(
    .p_nbits(INPUT_SIZE/2)
  ) result_mux (
    .in0(result_initial),
    .in1(next_result),
    .sel(result_mux_sel),
    .out(result_reg_before)
  );

  //no need to use vc_Adder, don't care cin&cout
  //no need to use always_ff to delay one cycle, just use combiantional logic to get result immediately
  vc_SimpleAdder #(
    .p_nbits(INPUT_SIZE/2)
  ) Adders (
    .in0(a_val),
    .in1(result_reg_after),
    .out(result_adder)
  );

  vc_Mux2 #(
    .p_nbits(INPUT_SIZE/2)
  ) add_mux (
    .in0(result_reg_after),
    .in1(result_adder),
    .sel(add_mux_sel),
    .out(next_result)
  );

  assign ostream_msg = result_reg_after;


endmodule


//control unit
module control_unit
(
  input clk,
  input reset,
  input  logic        istream_val,
  output logic        istream_rdy,
  input  logic [INPUT_SIZE-1:0] istream_msg,

  output logic        ostream_val,
  input  logic        ostream_rdy,
  //output logic [OUTPUT_SIZE-1:0] ostream_msg,

  //communication signals
  output logic b_mux_sel,
  output logic a_mux_sel,
  output logic result_mux_sel,
  output logic add_mux_sel,
  //to ensure that the result calculated last time won't be override immedicately, enable more time to sent out the output result of last time
  output logic result_en,
  input logic b_lsb,

  output [1:0] current_state       
);

  //cannot be modified
  localparam IDLE = 2'b00;
  localparam CALC = 2'b01;
  localparam DONE = 2'b10;

  logic [1:0] state;
  logic [1:0] next_state;
  logic clear;
  logic increment_mode;
  logic decrement_mode;
  logic count_end;
  logic [5:0] count;
  logic next_istream_rdy;
  logic next_ostream_val;
  assign increment_mode = 1'b1;
  assign decrement_mode = 1'b0;

  assign current_state = state;
  // state element
  always_ff@(posedge clk)
    if(reset) 
      state <= IDLE;
    else 
      state <= next_state;

  logic delay;
  logic next_delay;
  always_ff@(posedge clk)
    delay <= next_delay;

  // state transition
  always_comb 
    case(state)
      IDLE:
          next_state = istream_val ? CALC : IDLE;//just wait one cycle to load input operands is enough?
          //what if the result transfer fails?
      CALC: 
      //coverage issue
          next_state = count_end ? DONE : CALC;
      DONE:
          next_state = ostream_rdy && delay ? IDLE: DONE;//just wait one cycle to send out result is enough?
      default:
          $stop;
    endcase

    //logic refresh;
    //logic next_refresh;
    //always_ff@(posedge clk)
      //refresh <= next_refresh;
    //assign next_refresh = refresh + 1;

    // state output
    always_comb
      case(state)
        IDLE: begin
        //load inputs first
          b_mux_sel = 1'b0;
          a_mux_sel = 1'b0;
          //reset result = 0 every multiply process
          // Any other way to delay result_mux_sel for one cycle?
          //result_mux_sel = refresh? 1'b0 : result_mux_sel;
          result_mux_sel = 1'b0;
          result_en = 1'b1;//stick to 1'b1, function of result_en?
          //reset counter
          clear = 1'b1;
          istream_rdy = 1'b0;
          ostream_val = 1'b1;
          next_delay = 1'b0;
        end
        CALC: begin
          //next_ostream_val = count_end ? 1'b1: 1'b0;//result is being calucated 
          //next_istream_rdy = 1'b0;
          //activate counter
          clear = 1'b0;
          b_mux_sel = 1'b1;
          a_mux_sel = 1'b1;
          result_mux_sel = 1'b1;
          result_en = 1'b1;
          add_mux_sel = b_lsb;
        end
        DONE: begin
          istream_rdy = 1'b1;
          ostream_val = 1'b0;//calculation is done
          //result_mux_sel = 1'b0;
          next_delay = 1'b1;
        end
        default: $stop;
      endcase

    
    // no need to delay one cycle, which might cause potential squential logic chaos
    // that is to say, carefully use one-cycle delay block(next_), which could involve some incorrespondence with other signals
    //always_ff@(posedge clk)begin
      //if (reset) begin
        //istream_rdy <= 1'b1;
        //ostream_val <= 1'b0;
      //end
      //istream_rdy <= next_istream_rdy;
      //ostream_val <= next_ostream_val;
    //end

    logic next_count_end;
    vc_BasicCounter #(
      .p_count_nbits(6),
      .p_count_clear_value(1),
      .p_count_max_value(32)
    ) counter (
      .clk(clk),
      .reset(reset),
      .clear(clear),
      .count(count),
      .increment(increment_mode),
      .decrement(decrement_mode),
      .count_is_max(count_end),
      .count_is_zero()
    );
    // to realizes that the counter reaches 32, indicates the calculation has been finished completely 
    //always_ff@(posedge clk)
      //count_end <= next_count_end;




endmodule



//========================================================================
// Integer Multiplier Fixed-Latency Implementation
//========================================================================

module lab1_imul_IntMulBase
(
  input  logic        clk,
  input  logic        reset,

  input  logic        istream_val,
  output logic        istream_rdy,
  input  logic [63:0] istream_msg,

  output logic        ostream_val,
  input  logic        ostream_rdy,
  output logic [31:0] ostream_msg
);

  // ''' LAB TASK ''''''''''''''''''''''''''''''''''''''''''''''''''''''''
  // Instantiate datapath and control models here and then connect them
  // together.
  // '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

  //communication signals
  logic b_mux_sel;
  logic b_lsb;
  logic a_mux_sel;
  logic result_mux_sel;
  logic result_en;
  logic add_mux_sel;
  logic [1:0] state;
  logic [5*8-1:0] state_sym;

  logic [INPUT_SIZE/2-1:0] a;
  logic [INPUT_SIZE/2-1:0] b;
  assign a = $signed(istream_msg[INPUT_SIZE-1:INPUT_SIZE/2]);
  assign b = $signed(istream_msg[INPUT_SIZE/2-1:0]);
  

  datapath_top D0
  (
    .clk(clk),
    .reset(reset),
    .istream_msg(istream_msg),
    .b_mux_sel(b_mux_sel),
    .a_mux_sel(a_mux_sel),
    .b_lsb(b_lsb),
    .result_mux_sel(result_mux_sel),
    .result_en(result_en),
    .add_mux_sel(add_mux_sel),
    .istream_rdy(istream_rdy),
    .ostream_val(ostream_val),
    .ostream_msg(ostream_msg)
  );

  control_unit C0
  (
    .clk(clk),
    .reset(reset),
    .istream_val(istream_val),
    .istream_rdy(istream_rdy),
    .istream_msg(istream_msg),
    .ostream_val(ostream_val),
    .ostream_rdy(ostream_rdy),
    .b_mux_sel(b_mux_sel),
    .a_mux_sel(a_mux_sel),
    .b_lsb(b_lsb),
    .result_mux_sel(result_mux_sel),
    .result_en(result_en),
    .add_mux_sel(add_mux_sel),
    .current_state(state)
  );

  always_comb
    case(state)
      2'b00: state_sym = " IDLE";
      2'b01: state_sym = " CALC";
      2'b10: state_sym = " DONE";
      default: $stop;
    endcase

  //----------------------------------------------------------------------
  // Line Tracing
  //----------------------------------------------------------------------

  `ifndef SYNTHESIS

  logic [`VC_TRACE_NBITS-1:0] str;
  `VC_TRACE_BEGIN
  begin

    $sformat( str, "%x", istream_msg );
    vc_trace.append_val_rdy_str( trace_str, istream_val, istream_rdy, str );

    vc_trace.append_str( trace_str, "(" );

    // ''' LAB TASK ''''''''''''''''''''''''''''''''''''''''''''''''''''''
    // Add additional line tracing using the helper tasks for
    // internal state including the current FSM state.
    // '''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

    
    $sformat( str, "%x", a );
    vc_trace.append_str( trace_str, str );

    vc_trace.append_str( trace_str, " * " );

    $sformat( str, "%x", b );
    vc_trace.append_str( trace_str, str );

    vc_trace.append_str( trace_str, " = " );

    $sformat( str, "%x", ostream_msg );
    vc_trace.append_str( trace_str, str );

    $sformat( str, "%s", state_sym);
    vc_trace.append_str( trace_str, str );
   

    vc_trace.append_str( trace_str, ")" );

    $sformat( str, "%x", ostream_msg );
    vc_trace.append_val_rdy_str( trace_str, ostream_val, ostream_rdy, str );

  end
  `VC_TRACE_END

  `endif /* SYNTHESIS */

endmodule

`endif /* LAB1_IMUL_INT_MUL_BASE_V */

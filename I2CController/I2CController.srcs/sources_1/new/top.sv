`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/25/2026 10:46:47 AM
// Design Name: 
// Module Name: top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top(
input logic clk,
input logic nrst,
 inout tri sda,
output tri scl,
output logic[7:0] sseg_data,
output logic[7:0] sseg_ctrl,
input logic btn,
input logic btn_write,
output logic led[6]
    
    );
    
  logic sda_in;
 logic scl_in;
 assign sda_in = sda; // This is what the FPGA actually "sees" on the bus
   assign scl_in = scl;
    
    
      logic synced_rst;
    reset_synchronizer rst_synchronizer(.nrst(nrst),.clk(clk),.sync_nrst(synced_rst));
    
        logic btn_debounced;
debouncer btn_debouncer(.d(btn),.q(btn_debounced),.clk(clk),.nrst(synced_rst));
    
    logic btn_delayed;
     delay_signal btn_delay(.clk(clk),.nrst(nrst),.d(btn_debounced),.q(btn_delayed));
     
     
             logic btn_write_debounced;
debouncer btn_write_debouncer(.d(btn_write),.q(btn_write_debounced),.clk(clk),.nrst(synced_rst));
    
    logic btn_write_delayed;
     delay_signal btn_write_delay(.clk(clk),.nrst(nrst),.d(btn_write_debounced),.q(btn_write_delayed));
     
     
     common::I2C_COMMAND r_command,next_command;
     logic[7:0] dout;
     logic[7:0] din;
     logic master_ready;
     logic master_finished;
    logic slave_ack;
     logic [7:0] reg_addr;
     assign reg_addr=8'h0A;
     i2c_master master(
     .clk(clk),
    .nrst(synced_rst),
    .sda(sda),
    .scl(scl),
    .dout(dout),
    .command(r_command),
    .ready(master_ready),
    .finished(master_finished),
    .slave_ack(slave_ack),
    .reg_addr(reg_addr),
    .din(din)
     );

    
    
    



logic[3:0] hard_sseg_ctrl=4'b1111;
assign sseg_ctrl[7:4]=hard_sseg_ctrl;
assign start_signal=master_finished;
 logic finished_signal;

sseg_mux seven_mux(.number( {8'b0,dout} ),
.ctrl(sseg_ctrl[3:0]),
.data(sseg_data),
.start_signal(start_signal),
.finished_signal(finished_signal),
.clk(clk),
.nRst(synced_rst));


    

    typedef enum logic [1:0] {IDLE=2'd0,START=2'd1,WAIT_FOR_FINISHED=2'd2} state;
    state r_state,next_state;

    always_ff @(posedge clk,negedge synced_rst)
        begin
            if(!synced_rst)
                begin
                    r_command<=common::COMMAND_IDLE;
                    r_state<=IDLE;
                end
             else
                begin
                    r_command<=next_command;
                    r_state<=next_state;
                end
        end
        
        always_comb
            begin
                next_command=r_command;
                next_state=r_state;
                case (r_state)
                    IDLE:
                        begin
                            if(btn_delayed)
                                begin
                                    next_state=START;
                                end
                        end
                    START:
                        begin
                            next_command=common::COMMAND_READ;
                            next_state=WAIT_FOR_FINISHED;
                        end
                    WAIT_FOR_FINISHED:
                        begin
                            next_command<=common::COMMAND_IDLE;
                            if(master_finished)
                                next_state=IDLE;
                                
                        end
                endcase
            end 
        
    assign led[0]  = !slave_ack;  
    assign led[1]  = r_state==IDLE;  
    assign led[2]  = btn_delayed;  
    
    
endmodule

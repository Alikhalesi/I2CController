`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/22/2026 04:58:47 PM
// Design Name: 
// Module Name: i2c_master
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


module i2c_master(
    input logic clk,
    input logic nrst,
    input common::I2C_COMMAND command
    );
    
    typedef enum logic[3:0] {IDLE=4'd0,START=4'd1,D1=4'd2,D2=4'd3,D3=4'd4,D4=4'd5,STOP=4'd6} state;
    
    state r_state,next_state;
    
    always_ff @(posedge clk,negedge nrst)
    begin
        if(!nrst)
            begin
                r_state<=IDLE;
            end
         else
            begin
                r_state<=next_state;    
            end
    end
    
    
    always_comb
    begin
        next_state=r_state;
        case (r_state)
            IDLE:
                begin
                    if(command==common::READ)
                        begin
                        end
                    else if (command==common::WRITE)
                        begin
                        end
                end
            START:
                begin
                end
            D1:
                begin
                end
            D2:
                begin
                end
            D3:
                begin
                end
            D4:
                begin
                end
            STOP:
                begin
                end
        endcase
    end
    
    
endmodule

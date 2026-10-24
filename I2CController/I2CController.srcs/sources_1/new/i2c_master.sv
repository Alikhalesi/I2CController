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


module i2c_master #(localparam int SCL_FREQ=100_000,localparam int DVSR=(100_000_00/(SCL_FREQ*4)),localparam logic[7:0] DEVICE_ADDR_WR=8'b10101010
,localparam logic[7:0] DEVICE_ADDR_R=8'b10101010,localparam logic[7:0] REG_ADDRESS=8'b10101010)
(
    input logic clk,
    input logic nrst,
    inout tri sda,
    output tri scl,
    input logic[7:0] din,
    output logic[7:0] dout,
    input common::I2C_COMMAND command,
    output logic ready,
    output logic finished
    );
    
    typedef enum logic[3:0] {IDLE=4'd0,START=4'd1,D1=4'd2,D2=4'd3,D3=4'd4,D4=4'd5,DEV_ACK=4'd6,STOP=4'd7,MASTER_ACK=4'd8,RESTART=4'd9} state;
    typedef enum logic[1:0] {ADDR=2'd00,REG_ADDR=2'b01,DATA=2'b10,ADDR2=2'b11} phase;
    
    state r_state,next_state;
    common::I2C_COMMAND r_command,next_command;
    logic r_ready,next_ready;
    logic r_sda,r_scl,next_sda,next_scl;
    logic[31:0] r_dvsr,next_dvsr;
     logic[4:0] r_bit_count,next_bit_count;
     logic[7:0] r_din,next_din;
     logic[7:0] r_dout,next_dout;
    phase r_phase,next_phase;
    logic r_slave_ack,next_slave_ack;
    logic r_finished,next_finished;
    logic r_restarted,next_restarted;
    
    always_ff @(posedge clk,negedge nrst)
    begin
        if(!nrst)
            begin
                r_state<=IDLE;
                r_command<=common::COMMAND_IDLE;
                r_ready<=0;
                r_sda<=1'b1;
                r_scl<=1'b1;
                r_dvsr<=0;
                r_bit_count<=7;
                r_phase<=ADDR;
                r_din<=0;
                r_slave_ack<=0;
                r_dout<=0;
                r_finished<=0;
                r_restarted<=0;
            end
         else
            begin
                r_state<=next_state;
                r_command<=next_command;
                r_ready<=next_ready;
                r_sda<=next_sda;
                r_scl<=next_scl;
                r_dvsr<=next_dvsr;    
                r_bit_count<=next_bit_count;
                r_phase<=next_phase;
                r_din<=next_din;
                r_slave_ack<=next_slave_ack;
                r_dout<=next_dout;
                r_finished<=next_finished;
                r_restarted<=next_restarted;
            end
    end
    
    always_comb
    begin
        next_state=r_state;
        next_ready=0;
        next_command=r_command;
        next_sda=r_sda;
        next_scl=r_scl;
        next_dvsr=r_dvsr;
        next_bit_count=r_bit_count;
        next_din=r_din;
        next_phase=r_phase;
        next_slave_ack=r_slave_ack;
        next_dout<=r_dout;
        next_finished=0;
        next_restarted<=r_restarted;
        case (r_state)
            IDLE:
                begin
                    next_ready=1;
                    if(command!=common::COMMAND_IDLE)
                        begin
                            next_command=command;
                            next_state=START;
                            next_dvsr=0;
                            next_din=din;
                            next_phase=ADDR;
                            next_scl=1;
                            next_sda=1;
                            next_bit_count=7;
                        end
                end
            START:
                begin
                    next_sda=0;
                    if(r_dvsr==DVSR)
                        begin
                            next_state=D1;
                            next_dvsr=0;
                            next_scl=0;
                        end
                    else
                        next_dvsr=r_dvsr+1;
                    
                end
            D1:
                begin
                 if(r_dvsr==DVSR)
                        begin
                            next_state=D2;
                            next_dvsr=0;
                            if(r_command==common::COMMAND_READ)
                                begin
                                    if(r_phase==ADDR || r_phase==ADDR2)
                                        begin
                                            next_sda=DEVICE_ADDR_R[r_bit_count];
                                        end
                                    else if (r_phase==REG_ADDR)
                                        begin
                                            next_sda=REG_ADDRESS[r_bit_count];
                                        end    
                                    else if(r_phase==DATA)
                                        begin
                                             next_sda=r_dout[r_bit_count];
                                        end
                                end
                            else
                                begin
                                end
                        
                        end
                    else
                        next_dvsr=r_dvsr+1;
                end
            D2:
                begin
                    if(r_dvsr==DVSR)
                        begin
                            next_state=D3;
                            next_dvsr=0;
                            next_scl=1'b1;
                        end
                    else
                        next_dvsr=r_dvsr+1;
                end
            D3:
                begin
                     if(r_dvsr==DVSR)
                        begin
                            next_state=D4;
                            next_dvsr=0;
                            next_scl=1'b0;
                        end
                    else
                        next_dvsr=r_dvsr+1;
                end
            D4:
                begin
                     if(r_dvsr==DVSR)
                        begin
                            next_dvsr=0;
                            if(r_bit_count==0)
                                if (r_phase==ADDR || r_phase==REG_ADDR || r_phase==ADDR2)
                                    begin
                                        next_state=DEV_ACK;
                                        next_sda=1;// make the pin az Z 
                                    end
                                 else
                                    begin
                                        next_state=MASTER_ACK;
                                    end
                            else
                                begin
                                    next_state=D1;
                                    next_bit_count=r_bit_count-1;
                                end
                        end
                    else
                        next_dvsr=r_dvsr+1;
                end
            DEV_ACK:
                begin
                    if(r_dvsr==2*DVSR)
                        begin
                            next_scl=1;
                            next_slave_ack=sda;
                              next_dvsr=r_dvsr+1;   
                           
                        end
                     else if(r_dvsr==3*DVSR)
                        begin
                            next_scl=0;
                              next_dvsr=r_dvsr+1;   
                        end
                      else
                           next_dvsr=r_dvsr+1;   
                        
                        
                        
                    if(r_dvsr==4*DVSR)
                                begin
                                if(r_phase==ADDR)
                                    begin
                                        if(r_restarted)
                                            begin
                                             next_phase=DATA;
                                              next_state=D1;
                                               next_dvsr=0;
                                              next_bit_count=7;
                                            end
                                        else
                                            begin
                                              next_phase=REG_ADDR;
                                              next_state=D1;
                                               next_dvsr=0;
                                              next_bit_count=7;
                                            end
                                  
                                    end
                                 else if (r_phase==REG_ADDR)
                                    begin
                                    next_phase=ADDR2;
                                    next_state=RESTART;
                                    next_dvsr=0;
                                    next_bit_count=7;
                                    end 
                                else if (r_phase==ADDR2)
                                    begin
                                    next_phase=DATA;
                                    next_state=START;
                                    next_dvsr=0;
                                    next_bit_count=7;
                                    end 
                                end
                         
                                    
                end
             RESTART:
                begin
                         if(r_dvsr==DVSR)
                        begin
                            next_sda=1;
                            next_dvsr=r_dvsr+1;
                        end
                        else if(r_dvsr==2*DVSR)
                            begin
                                next_scl=1;
                                next_dvsr=r_dvsr+1;
                            end
                          else if(r_dvsr==3*DVSR)
                            begin
                                next_scl=0;
                                 next_dvsr=r_dvsr+1;
                            end
                            else if(r_dvsr==4*DVSR)
                            begin
                                next_dvsr=0;
                                  next_state=D1;
                                next_phase=ADDR;
                                next_restarted=1;
                            end
                         else
                               next_dvsr=r_dvsr+1;
                    
                  
                end   
                
                
            MASTER_ACK:
            begin
                next_state=STOP;
            end
            STOP:
                begin
                   next_sda=0;
                 
                    if(r_dvsr==DVSR)
                        begin
                           next_scl=1;
                           next_dvsr=r_dvsr+1; 
                        end
                      else if(r_dvsr==2*DVSR)
                        begin
                           next_sda=1;
                           next_state=IDLE;
                           next_finished=1;
                        end
                      else
                            next_dvsr=r_dvsr+1;  
                end
        endcase
    end
    
    
    assign dout=r_dout;
    assign scl=r_scl==1?1'bZ:0;
    assign sda=(r_sda==1 || r_state==DEV_ACK)?1'bZ:1'b0;
    assign finished=r_finished;
    assign ready=r_ready;
endmodule

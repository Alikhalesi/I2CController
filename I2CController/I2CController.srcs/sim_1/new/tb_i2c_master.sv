`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/23/2026 04:43:44 PM
// Design Name: 
// Module Name: tb_i2c_master
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


module tb_i2c_master(

    );
    
   // Clock and Reset Signals
    logic clk;
    logic nrst;

    // Bi-directional I2C Lines
    tri sda;
    tri scl;

    // Master Interface Signals
    logic [7:0] din;
    logic [7:0] dout;
    common::I2C_COMMAND command;
    logic ready;
    logic finished;

    // Pull-up resistors for the I2C Open-Drain Bus
   // pullup(sda);
   // pullup(scl);

    // Slave Emulation Signals (To drive sda during Read/ACK phases)
    logic sda_out;
    logic sda_oe;
    assign sda = sda_oe ? sda_out : 1'bz;

    // Instantiate the Unit Under Test (UUT)
    i2c_master  uut (
        .clk(clk),
        .nrst(nrst),
        .sda(sda),
        .scl(scl),
        .din(din),
        .dout(dout),
        .command(command),
        .ready(ready),
        .finished(finished)
    );

    // 100MHz Clock Generation (10ns period)
    always #5 clk = ~clk;

    // Helper task to emulate the slave behavior for 1 byte (ACK or Data transmission)
    task automatic emulate_slave_rx_ack();
        // Wait for falling edge of SCL where Master expects ACK
        @(negedge scl);
        sda_out = 1'b0; // Drive ACK (Low)
        sda_oe  = 1'b1;
        @(negedge scl);
        sda_oe  = 1'b0; // Release bus
    endtask

    task automatic emulate_slave_tx_byte(input logic [7:0] data_to_send);
        sda_oe = 1'b1;
        for (int i = 7; i >= 0; i--) begin
            @(negedge scl);
            sda_out = data_to_send[i];
        end
        // Wait for Master ACK phase, release the line
        @(negedge scl);
        sda_oe = 1'b0;
    endtask

    // Main Test Sequence
    initial begin
        // Initialize Signals
        clk = 0;
        nrst = 1;
        din = 8'h00;
        command = common::COMMAND_IDLE; 
        sda_out = 1'b1;
        sda_oe = 1'b0;

        // Reset Sequence
        #100;
        nrst = 0;
        #40;
        nrst = 1;
        #40;
        // Ensure master is ready
        wait(ready == 1'b1);
        @(posedge clk);

//        // ==========================================================
//        // STEP 1: Write the Register Address (e.g., 0x3A)
//        // ==========================================================
//        $display("[TB] Starting Register Read Sequence...");
        
//        din = 8'h3A; 
//        command = common::COMMAND_WRITE; 
//        @(posedge clk);
        
//        // Wait for master to start processing
//        wait(ready == 1'b0); 
        
//        // Emulate Slave ACKs for (Device Address + W) and then the (Register Address)
//        emulate_slave_rx_ack(); // ACK for Device Write Address
//        emulate_slave_rx_ack(); // ACK for Register Address Data
        
//        // Wait for Write Phase to finish
//        wait(finished == 1'b1);
//        command = common::COMMAND_IDLE;
//        @(posedge clk);

        // ==========================================================
        // STEP 2: Repeated START + Read Data Phase
        // ==========================================================
        // Trigger Read Command (Should initiate Repeated Start + Device Address + R)
        command = common::COMMAND_READ; 
        @(posedge clk);
        wait(ready == 1'b0);

        // Emulate Slave ACK for (Device Address + R)
      //  emulate_slave_rx_ack();

        // Emulate Slave sending the requested register data (e.g., 0xA5)
        $display("[TB] Slave driving data byte 0xA5 onto the bus...");
        //emulate_slave_tx_byte(8'hA5);

        // Master should now issue a NACK followed by a STOP condition.
        wait(finished == 1'b1);
        command = common::COMMAND_IDLE;
        
        // Verify Data Latch
        if (dout === 8'hA5) begin
            $display("[TB] SUCCESS: Read data matched expected value 0xA5!");
        end else begin
            $display("[TB] ERROR: Read data mismatch! Expected: 0xA5, Got: %h", dout);
        end

        #500;
        $finish;
    end

    
endmodule

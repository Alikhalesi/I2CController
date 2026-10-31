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
// Description: Testbench for unified I2C Master read sequence with exact
//              START / Repeated START SCL edge synchronization.
// 
// Dependencies: 
// 
// Revision:
// Revision 0.03 - Added edge tracking for SCL drop after START conditions
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_i2c_master();
    
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
    pullup(sda);
    pullup(scl);

    // Slave Emulation Signals (To drive sda during Read/ACK phases)
    logic sda_out;
    logic sda_oe;
    assign sda = sda_oe ? sda_out : 1'bz;
    logic slave_ack;
    logic [7:0] reg_addr;
    // Instantiate the Unit Under Test (UUT)
    i2c_master uut (
        .clk(clk),
        .nrst(nrst),
        .sda(sda),
        .scl(scl),
        .slave_ack(slave_ack),
        .dout(dout),
        .din(din),
        .command(command),
        .ready(ready),
        .finished(finished),
        .reg_addr(reg_addr)
    );

    // 100MHz Clock Generation (10ns period)
    always #5 clk = ~clk;

    // Helper task to emulate the slave behavior for 1 byte (ACK transmission)
    // Expects to be called right at the falling edge of the 8th data bit
    task automatic emulate_slave_rx_ack();
        sda_out = 1'b0; // Drive ACK (Low)
        sda_oe  = 1'b1;
        // Hold through the 9th clock cycle, release on the subsequent falling edge
        @(negedge scl);
        sda_oe  = 1'b0; // Release bus back to High-Z
    endtask

    // Helper task to emulate the slave transmitting a data byte to the master
    // Expects to be called right at the falling edge of the preceding 9th clock pulse
    task automatic emulate_slave_tx_byte(input logic [7:0] data_to_send);
        for (int i = 7; i >= 0; i--) begin
            sda_out = data_to_send[i];
            sda_oe = 1'b1;
            @(negedge scl); // Wait for the current data bit to be sampled
        end
        // Master ACK/NACK phase: release the line right at the 8th bit's falling edge
        sda_oe = 1'b0;
    endtask

    // Main Test Sequence
    initial begin
    bit run_write = 1; bit run_read = 0;
        // Initialize Signals
        clk = 0;
        nrst = 1;
        din = 8'h2F; // The ADT7430 target register address (Device ID Pointer)
        command = common::COMMAND_IDLE; 
        sda_out = 1'b1;
        sda_oe = 1'b0;

        // Reset Sequence
        #100;
        nrst = 0;
        #40;
        nrst = 1;
        #40;
        
        // Ensure master is ready before starting
        wait(ready == 1'b1);
        @(posedge clk);

        // ==========================================================
        // SINGLE COMMAND TRANSACTION: Combined Write-then-Read Sequence
        // ==========================================================
                 if (run_read) begin
        $display("[TB] Sending single COMMAND_READ to trigger complete sequence...");
     
        command = common::COMMAND_READ; 
        @(posedge clk);
        wait(ready == 1'b0);
       //  @(negedge sda);              // Wait for master to claim the bus
        command = common::COMMAND_IDLE; // Clear command tracking immediately
        
        // --- 1st ACK: Device Address + W ---
    //    @(negedge sda);                 // 1. Catch the initial START condition (SDA drops while SCL is high)
        @(negedge scl);                 // 2. Consume the SCL falling edge caused by the START routine
        repeat(8) @(negedge scl);       // 3. Count exactly 8 data bits
        emulate_slave_rx_ack();         // 4. Drive ACK on the 9th clock pulse

        // --- 2nd ACK: Register Address Data ---
        // Alignment is already matched since the previous task ended on a falling SCL edge
        repeat(8) @(negedge scl);       // Count 8 bits of the register location pointer
        emulate_slave_rx_ack();         // Drive ACK on the 9th clock pulse

        // --- 3rd ACK: Device Address + R (After Repeated Start) ---
        @(negedge sda);                 // 1. Catch the Repeated START condition signature on the bus
        @(negedge scl);                 // 2. Consume the SCL falling edge terminating the Repeated START phase
        repeat(8) @(negedge scl);       // 3. Count 8 bits of the re-addressing read packet
        emulate_slave_rx_ack();         // 4. Drive ACK on the 9th clock pulse

        // --- Data Phase: Slave Transmits Requested Register Value to Master ---
        $display("[TB] Slave driving data byte 0xA5 onto the bus...");
        emulate_slave_tx_byte(8'hA5);   // Slave drives data, master will sample and issue NACK

        // --- End of Transaction ---
        wait(finished == 1'b1);         // Wait for master to issue NACK + STOP and flag completion
        
        // Verify Data Latch
        if (dout === 8'hA5) begin
            $display("[TB] SUCCESS: Read data matched expected value 0xA5!");
        end else begin
            $display("[TB] ERROR: Read data mismatch! Expected: 0xA5, Got: %h", dout);
        end

 #200;
end
if (run_write) begin
        // ==========================================================
        // TRANSACTION 2: Write Sequence
        // ==========================================================
        wait(ready == 1'b1);
        @(posedge clk);
        $display("[TB] Sending COMMAND_WRITE to trigger write sequence...");
        
        reg_addr = 8'h3A;               // Register address to be written
        din = 8'h55;                    // Data payload to write into the register
        command = common::COMMAND_WRITE;
        @(posedge clk);
        wait(ready == 1'b0);
        command = common::COMMAND_IDLE; 

        // --- 1st ACK: Device Address + W ---
      //  @(negedge sda);                 // Catch START condition
        @(negedge scl);                 // Consume first SCL drop
        repeat(8) @(negedge scl);       // Count 8 bits (Device Addr + W)
        emulate_slave_rx_ack();         // Slave ACKs

        // --- 2nd ACK: Register Address ---
        repeat(8) @(negedge scl);       // Count 8 bits (Register Address)
        emulate_slave_rx_ack();         // Slave ACKs

        // --- 3rd ACK: Data Payload (Master writing to Slave) ---
        $display("[TB] Monitoring Master writing data payload...");
        repeat(8) @(negedge scl);       // Count 8 bits (Data driven by Master)
        emulate_slave_rx_ack();         // Slave ACKs the written data

        // --- End of Transaction ---
        wait(finished == 1'b1);         // Wait for master to generate STOP condition
        $display("[TB] SUCCESS: Write sequence completed.");

end





        #500;
        $finish;
    end

endmodule

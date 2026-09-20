module wb_uart #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer BAUD_RATE   = 115200
) (
    input wire clk,
    input wire rst,
    input wire [31:0] wb_addr,
    input wire [31:0] wb_dat_m2s,
    input wire wb_cyc, 
    input wire wb_stb,
    input wire wb_we,
    input wire [3:0] wb_sel,

    output wire [31:0] wb_dat_s2m,
    output wire wb_ack,

    output reg uart_tx,
    input wire uart_rx

);

    // Cycles per bit. At 50 MHz / 115200 this is 434, which no longer fits in
    // the 8-bit counters the 27 MHz version used (divisor 234).
    localparam integer BAUD_DIV  = CLK_FREQ_HZ / BAUD_RATE;
    localparam integer BAUD_HALF = BAUD_DIV / 2;
    localparam integer BAUD_W    = $clog2(BAUD_DIV + 1);

    reg [7:0] tx_reg;
    reg tx_busy;
    reg [BAUD_W-1:0] baud_counter;
    reg [9:0] tx_shift;
    reg [9:0] bit_count;


    always @(posedge clk) begin
        if (rst) begin
            tx_reg <= 0;
            tx_busy <= 0;
            baud_counter <= 0;
            tx_shift <= 0;
            bit_count <= 0;
            uart_tx <= 1;
        end else if(wb_cyc && wb_stb && wb_we && (wb_addr[3:2] == 2'b00)) begin
            tx_reg <= wb_dat_m2s[7:0];
            tx_shift <= {1'b1,wb_dat_m2s[7:0], 1'b0};
            tx_busy <= 1;
            bit_count <= 10'b0000000000;
        end else if(tx_busy) begin
            baud_counter <= baud_counter + 1;
            if(baud_counter == (BAUD_DIV - 1)) begin
                baud_counter <= 0;
                uart_tx <= tx_shift[0];
                tx_shift <= tx_shift >> 1;
                bit_count <= bit_count + 1;
                if(bit_count == 9) begin
                    tx_busy <= 0;
                    end
            end
        end
    end

    reg rx_active;
    reg [BAUD_W-1:0] rx_baud_counter;
    reg [9:0] rx_bit_count;
    reg [7:0] rx_shift;
    reg [7:0] rx_data;
    reg rx_ready;

    always @(posedge clk) begin
        if(rst) begin
            rx_active <= 0;
            rx_baud_counter <= 0;
            rx_bit_count <= 0;
            rx_shift <= 0;
            rx_data <= 0;
            rx_ready <= 0;
        end else if(rx_active) begin
            if(rx_baud_counter == (BAUD_DIV - 1)) begin
                rx_baud_counter <= 0;
                rx_shift <= {uart_rx, rx_shift[7:1]};
                rx_bit_count <= rx_bit_count + 1;
                if(rx_bit_count == 8) begin
                    rx_data <= {uart_rx, rx_shift[7:1]};
                    rx_ready <= 1;
                    rx_active <= 0;
                end


            end else begin
                rx_baud_counter <= rx_baud_counter + 1;
            end

        end else begin
            if(uart_rx == 0) begin
                rx_active <= 1;
                // Start half a bit in so later bits are sampled mid-cell.
                rx_baud_counter <= BAUD_HALF;
                rx_bit_count <= 0;

            end
        end
    end


    assign wb_dat_s2m = (wb_addr[3:2] == 2'b00) ? {24'b0, tx_reg} :
                (wb_addr[3:2] == 2'b01) ? {31'b0, tx_busy} :
                (wb_addr[3:2] == 2'b10) ? {24'b0, rx_data} :
                (wb_addr[3:2] == 2'b11) ? {31'b0, rx_ready} :
                32'h0;

    
    assign wb_ack = wb_stb && wb_cyc;

endmodule

`timescale 1ns/10ps
//`define ENAB_GPIO_INT
//`define ENAB_UART_16550_inst
module testbench_top;

// =======================================
//
//		SIGNAL / PARAMETER DEFINITIONS
//
// =======================================

parameter       ADDRWIDTH                   = 32            ;
parameter       DATAWIDTH                   = 32            ;

parameter       APERWIDTH                   = 17            ;
parameter       APERSIZE                    =  9            ;

parameter       FPGA_REG_BASE_ADDRESS	        = 32'h40020000; // Assumes 128K Byte Aperture
parameter       UART_BASE_ADDRESS    			= 32'h40021000; // Assumes 128K Byte Aperture
parameter       BASE_AHB_ADDRESS_DMA_REG    	= 32'h40030000;
parameter       BASE_AHB_ADDRESS_DMA_DPORT0REG  = 32'h40031000;
parameter       QL_RESERVED_BASE_ADDRESS    	= 32'h40032000;

parameter       AL4S3B_DEVICE_ID              = 32'h00055ADC;   
parameter       AL4S3B_REV_LEVEL              = 32'h00000211;

parameter       ID_REG_ADR          	       =  10'h0         ;
parameter       REV_REG_ADR          	   	   =  10'h1         ;
parameter       FIFO_RST_REG_ADR          	   =  10'h2         ;
parameter       SENS_EN_REG          	       =  10'h3         ;
parameter       SENS_1_REG          	       =  10'h4         ;
parameter       SENS_2_REG          	       =  10'h5         ;
parameter       SENS_3_REG          	       =  10'h6         ;
parameter       SENS_4_REG          	       =  10'h7         ;
parameter       TIMER_REG          	           =  10'h8         ;
parameter       TIMER_EN          	           =  10'h9         ;

parameter       DMA_EN_REG_ADR                =  10'h0         ;
parameter       DMA_STS_REG_ADR               =  10'h1         ;
parameter       DMA_INTR_EN_REG_ADR           =  10'h2         ;
parameter       RESERVED_3                    =  10'hB         ;
parameter       DMA_DEF_REG_VALUE             =  32'hDAD_DEF_AC ; 
parameter       DMA_CH0_DATA_REG_ADR          =  10'h0;

parameter       AL4S3B_DEF_REG_VALUE        = 32'hFAB_DEF_AC; // Distinguish access to undefined area

parameter       DEFAULT_READ_VALUE          = 32'hBAD_FAB_AC;
parameter       DEFAULT_CNTR_WIDTH          =  3            ;
parameter       DEFAULT_CNTR_TIMEOUT        =  7            ;

parameter       STD_CLK_DLY                 =  2            ;

parameter       TEST_MSG_ARRAY_SIZE         = (64 * 8)      ;     // 64 ASCII character array size

reg 			rst_spi_slave;

reg         	conv;
reg         	MOSI;
wire        	RDbar;
wire        	BUSYbar ;

//	Define the reset signal
//
reg             sys_rst_N   ;


reg      [DATAWIDTH-1:0]  read_data;
reg	     [DATAWIDTH-1:0]  expected_data;

reg	     [ADDRWIDTH-1:0]  target_address;
reg	     [DATAWIDTH-1:0]  target_data;
reg	     [DATAWIDTH-1:0]  target_data_int;

reg                [7:0]  write_data_1;
reg                [7:0]  write_data_2;

reg                [2:0]  ahb_xfr_size;
reg                [9:0]  transfer_size;

reg      [DATAWIDTH-1:0]  target_read_data;
reg      [DATAWIDTH-1:0]  target_ref_data;

integer 				 d_buff_index;

integer        i, j,k,int_loop_shift;
integer        ram1_data_index,ram2_data_index,ram3_data_index;

integer        			adr_index,loop_idx;
integer        			dma_idx;
integer        			top_dma_idx;

reg 					  disable_read_chk;
reg 					  read_only_test;

integer			fail_count;				// Count the number of failing tests
integer			pass_count;				// Count the number of passing tests

`ifdef ENAB_UART_16550_inst	
reg             SIN         ;
wire            SOUT        ;
wire            Null_Modem_Tx_to_Rx;
wire            Null_Modem_Rx_to_Tx;
`endif

//  Application Specific signals
//
// 	Note:   These signals may be controlled by an external pull-up/down,
//          switches, jumpers, or GPIO port of a controller.
//
//          These should be controlled via reg to allow emulation of this
//          control.
//

// =======================================
//
//		INITIALIZE INTERFACE SIGNALS
//
// =======================================
//
//	Note:   These are signals that are normally controlled via a pull-up/down,
//          switches, jumpers, or GPIO of a controller.
//
//          The following always blocks sets the initial state of the signal.
//

initial
begin

    // Initialize the Serial UART Bus monitor

    sys_rst_N        <=  1'b0;    // Start the simulation with the device reset
	#100;
    sys_rst_N        <=  1'b1;    // Start the simulation with the device reset

end


// =======================================
//
//		MODULE INSTANTIATIONS
//
// =======================================
// Fabric top level
//
// Note: This represents the board level connection to the fabric IP.
//
top      u_AL4S3B_Fabric_Top 
	                           (
`ifdef ENAB_GPIO_INT							   
    .GPIO_PIN                  	( GPIO_PIN ),
`endif	
`ifdef ENAB_UART_16550_inst	
	.SIN_i                     	( Null_Modem_Tx_to_Rx ),
	.SOUT_o                    	( Null_Modem_Rx_to_Tx ),
`endif
    .SDATA_i					(	MISO		), 
    .SCLK_o						(	SCK			), 
 	.CSn_o        			    (	RDbar		)
	);
	
SPI_s_LTC1857 u_SPI_s_LTC1857 
   (.rst_i			(rst_spi_slave),
	.sck_i			(SCK),
	.mosi_i			(MOSI),
	.miso_o			(MISO),
	.conv_i         (conv),
	.RDbar_i        (RDbar),
	.BUSYbar_o      (BUSYbar)
);	

//`define Modelsim

// Save waveforms for analysis
//
/*
initial
begin
    $timeformat(-9,1,"ns",20);
//    $dumpfile("AL4S3B_Fabric_sim.vcd");
//    $dumpvars;

`ifdef Modelsim
	$wlfdumpvars;
`endif

end
*/
`ifdef ENAB_UART_16550_inst	
// Intantiate the Tx BFM
//
Serial_Tx_gen_bfm             #(

    .ENABLE_REG_WR_DEBUG_MSG   ( 1'b0                                    ),
    .ENABLE_REG_RD_DEBUG_MSG   ( 1'b0                                    ),

    .SERIAL_DATA_5_BITS        ( SERIAL_DATA_5_BITS                      ),
    .SERIAL_DATA_6_BITS        ( SERIAL_DATA_6_BITS                      ),
    .SERIAL_DATA_7_BITS        ( SERIAL_DATA_7_BITS                      ),
    .SERIAL_DATA_8_BITS        ( SERIAL_DATA_8_BITS                      ),

    .SERIAL_PARITY_NONE        ( SERIAL_PARITY_NONE                      ),
    .SERIAL_PARITY_ODD         ( SERIAL_PARITY_ODD                       ),
    .SERIAL_PARITY_EVEN        ( SERIAL_PARITY_EVEN                      ),
    .SERIAL_PARITY_FORCE_1     ( SERIAL_PARITY_FORCE_1                   ),
    .SERIAL_PARITY_FORCE_0     ( SERIAL_PARITY_FORCE_0                   ),

    .SERIAL_STOP_1_BIT         ( SERIAL_STOP_1_BIT                       ),
    .SERIAL_STOP_1P5_BIT       ( SERIAL_STOP_1P5_BIT                     ),
    .SERIAL_STOP_2_BIT         ( SERIAL_STOP_2_BIT                       ),

    .SERIAL_BAUD_RATE_110      ( SERIAL_BAUD_RATE_110                    ),
    .SERIAL_BAUD_RATE_300      ( SERIAL_BAUD_RATE_300                    ),
    .SERIAL_BAUD_RATE_600      ( SERIAL_BAUD_RATE_600                    ),
    .SERIAL_BAUD_RATE_1200     ( SERIAL_BAUD_RATE_1200                   ),
    .SERIAL_BAUD_RATE_2400     ( SERIAL_BAUD_RATE_2400                   ),
    .SERIAL_BAUD_RATE_4800     ( SERIAL_BAUD_RATE_4800                   ),
    .SERIAL_BAUD_RATE_9600     ( SERIAL_BAUD_RATE_9600                   ),
    .SERIAL_BAUD_RATE_14400    ( SERIAL_BAUD_RATE_14400                  ),
    .SERIAL_BAUD_RATE_19200    ( SERIAL_BAUD_RATE_19200                  ),
    .SERIAL_BAUD_RATE_38400    ( SERIAL_BAUD_RATE_38400                  ),
    .SERIAL_BAUD_RATE_57600    ( SERIAL_BAUD_RATE_57600                  ),
    .SERIAL_BAUD_RATE_115200   ( SERIAL_BAUD_RATE_115200                 ),
    .SERIAL_BAUD_RATE_230400   ( SERIAL_BAUD_RATE_230400                 ),
    .SERIAL_BAUD_RATE_921600   ( SERIAL_BAUD_RATE_921600                 )

    )

    u_Serial_Tx_gen_bfm        (

    .Tx                        ( Null_Modem_Tx_to_Rx                     ),
    .RTSn                      (                                         ),
    .CTSn                      (                                         )

    );
			
// Intantiate the Rx BFM
//
Serial_Rx_monitor             #(

    .ENABLE_DEBUG_MSGS         ( 1'b1                                    ),
    .ENABLE_DEBUG_ERROR_MSGS   ( 1'b1                                    ),

    .SERIAL_DATA_5_BITS        ( SERIAL_DATA_5_BITS                      ),
    .SERIAL_DATA_6_BITS        ( SERIAL_DATA_6_BITS                      ),
    .SERIAL_DATA_7_BITS        ( SERIAL_DATA_7_BITS                      ),
    .SERIAL_DATA_8_BITS        ( SERIAL_DATA_8_BITS                      ),

    .SERIAL_PARITY_NONE        ( SERIAL_PARITY_NONE                      ),
    .SERIAL_PARITY_ODD         ( SERIAL_PARITY_ODD                       ),
    .SERIAL_PARITY_EVEN        ( SERIAL_PARITY_EVEN                      ),
    .SERIAL_PARITY_FORCE_1     ( SERIAL_PARITY_FORCE_1                   ),
    .SERIAL_PARITY_FORCE_0     ( SERIAL_PARITY_FORCE_0                   ),

    .SERIAL_STOP_1_BIT         ( SERIAL_STOP_1_BIT                       ),
    .SERIAL_STOP_1P5_BIT       ( SERIAL_STOP_1P5_BIT                     ),
    .SERIAL_STOP_2_BIT         ( SERIAL_STOP_2_BIT                       ),

    .SERIAL_BAUD_RATE_110      ( SERIAL_BAUD_RATE_110                    ),
    .SERIAL_BAUD_RATE_300      ( SERIAL_BAUD_RATE_300                    ),
    .SERIAL_BAUD_RATE_600      ( SERIAL_BAUD_RATE_600                    ),
    .SERIAL_BAUD_RATE_1200     ( SERIAL_BAUD_RATE_1200                   ),
    .SERIAL_BAUD_RATE_2400     ( SERIAL_BAUD_RATE_2400                   ),
    .SERIAL_BAUD_RATE_4800     ( SERIAL_BAUD_RATE_4800                   ),
    .SERIAL_BAUD_RATE_9600     ( SERIAL_BAUD_RATE_9600                   ),
    .SERIAL_BAUD_RATE_14400    ( SERIAL_BAUD_RATE_14400                  ),
    .SERIAL_BAUD_RATE_19200    ( SERIAL_BAUD_RATE_19200                  ),
    .SERIAL_BAUD_RATE_38400    ( SERIAL_BAUD_RATE_38400                  ),
    .SERIAL_BAUD_RATE_57600    ( SERIAL_BAUD_RATE_57600                  ),
    .SERIAL_BAUD_RATE_115200   ( SERIAL_BAUD_RATE_115200                 ),
    .SERIAL_BAUD_RATE_230400   ( SERIAL_BAUD_RATE_230400                 ),
    .SERIAL_BAUD_RATE_921600   ( SERIAL_BAUD_RATE_921600                 )

    )

    u_Serial_Rx_monitor                (

    .Rx                                ( Null_Modem_Rx_to_Tx               ),
    .RTSn                              (                                   ),
    .CTSn                              (                                   ),

    .Serial_Baud_Rate_parameter        ( Serial_Baud_Rate_parameter        ),
    .Serial_Data_Bits_parameter        ( Serial_Data_Bits_parameter        ),
    .Serial_Parity_Bit_parameter       ( Serial_Parity_Bit_parameter       ),
    .Serial_Stop_Bit_parameter         ( Serial_Stop_Bit_parameter         ),

    .Rx_Baud_16x_Clk                   ( Rx_Baud_16x_Clk                   ),
    .Rx_Capture_Trigger                ( Rx_Capture_Trigger                ),

    .Rx_Holding_Reg_Stop_Bit           ( Rx_Holding_Reg_Stop_Bit           ),
    .Rx_Holding_Reg_Parity_Bit         ( Rx_Holding_Reg_Parity_Bit         ),
    .Rx_Holding_Reg_Data_Bit           ( Rx_Holding_Reg_Data_Bit           ),
    .Rx_Holding_Reg_Start_Bit          ( Rx_Holding_Reg_Start_Bit          ),
    .Rx_Holding_Reg_Parity_Error_Flag  ( Rx_Holding_Reg_Parity_Error_Flag  ),
    .Rx_Holding_Reg_Framing_Error_Flag ( Rx_Holding_Reg_Framing_Error_Flag ),
    .Rx_Holding_Reg_Break_Flag         ( Rx_Holding_Reg_Break_Flag         ),
    .Rx_Holding_Reg_False_Start_Flag   ( Rx_Holding_Reg_False_Start_Flag   )

    );
`endif

initial
begin
	 MOSI = 0;
	 conv = 0;
	 pass_count	= 0;
     fail_count = 0;
     rst_spi_slave = 0;
	 #10;
	 rst_spi_slave = 1;
	 #100;
	 rst_spi_slave = 0;

end

initial
begin
	ahb_xfr_size = 3'h2;
	target_data = 32'h55ADC;
    expected_data = target_data;
	disable_read_chk   = 0;	
	
	for (i = 0; i < 14; i = i + 1)
		@(posedge testbench_top.u_AL4S3B_Fabric_Top.WB_CLK) #STD_CLK_DLY;
		
	target_address = 0;	
    testbench_top.u_AL4S3B_Fabric_Top.u_qlal4s3b_cell_macro.u_ASSP_bfm_inst.u_ahb_gen_bfm.ahb_read_word_al4s3b_fabric((FPGA_REG_BASE_ADDRESS + target_address[7:0]), read_data);
	
	if (~disable_read_chk)
	begin
		for (i = 0; i < 14; i = i + 1)
		@(posedge testbench_top.u_AL4S3B_Fabric_Top.WB_CLK);            
			
			if (read_data !== expected_data)
            begin
                $display("[Error] FPGA_Reg_Test_1: ID REG Register Address=0x%x , read=0x%x , expected=0x%x at time %0t", 
                                                                                                     (FPGA_REG_BASE_ADDRESS + target_address[7:0]), 
						                                                                                                            read_data, 
                                                                                                                                expected_data, 
                                                                                                                                    $realtime);
                fail_count = fail_count + 1;
	            $stop();
            end	
            else
            begin
                $display("[Pass]  FPGA_Reg_Test_1: ID REG  Register Address=0x%x , read=0x%x , expected=0x%x at time %0t",  
                                                                                                     (FPGA_REG_BASE_ADDRESS + target_address[7:0]),
                                                                                                                                    read_data,
                                                                                                                                expected_data,
                                                                                                                                    $realtime);
                pass_count = pass_count + 1;
	        end
			
	end
	else
	begin
            $display("FPGA_Reg_Test_1: ID REG  Register Address=0x%x , read=0x%x at time %0t", 
                                                                                                     (FPGA_REG_BASE_ADDRESS + target_address[7:0]), 
						                                                                                                            read_data, 
                                                                                                                                    $realtime);
	end
	
	target_address = target_address + 4;
	for (i = 0; i < 14; i = i + 1)
	@(posedge testbench_top.u_AL4S3B_Fabric_Top.WB_CLK) #STD_CLK_DLY;
			
    testbench_top.u_AL4S3B_Fabric_Top.u_qlal4s3b_cell_macro.u_ASSP_bfm_inst.u_ahb_gen_bfm.ahb_read_word_al4s3b_fabric((FPGA_REG_BASE_ADDRESS + target_address[7:0]), read_data);
	
	
	target_data = 32'h1;	
	expected_data = 32'h0;
    disable_read_chk   = 0;	
	target_address = target_address + 4;
	testbench_top.u_AL4S3B_Fabric_Top.u_qlal4s3b_cell_macro.u_ASSP_bfm_inst.u_ahb_gen_bfm.ahb_write_word_al4s3b_fabric((FPGA_REG_BASE_ADDRESS + target_address[7:0]), target_data);
	
	testbench_top.u_AL4S3B_Fabric_Top.u_qlal4s3b_cell_macro.u_ASSP_bfm_inst.u_ahb_gen_bfm.ahb_read_word_al4s3b_fabric((FPGA_REG_BASE_ADDRESS + target_address[7:0]), read_data);
	if (~disable_read_chk)
	begin
		for (i = 0; i < 14; i = i + 1)
		@(posedge testbench_top.u_AL4S3B_Fabric_Top.WB_CLK);            
			
			if (read_data !== expected_data)
            begin
                $display("[Error] FPGA_Reg_Test_1: ID REG Register Address=0x%x , read=0x%x , expected=0x%x at time %0t", 
                                                                                                     (FPGA_REG_BASE_ADDRESS + target_address[7:0]), 
						                                                                                                            read_data, 
                                                                                                                                expected_data, 
                                                                                                                                    $realtime);
                fail_count = fail_count + 1;
	            $stop();
            end	
            else
            begin
                $display("[Pass]  FPGA_Reg_Test_1: ID REG  Register Address=0x%x , read=0x%x , expected=0x%x at time %0t",  
                                                                                                     (FPGA_REG_BASE_ADDRESS + target_address[7:0]),
                                                                                                                                    read_data,
                                                                                                                                expected_data,
                                                                                                                                    $realtime);
                pass_count = pass_count + 1;
	        end
			
	end
	else
	begin
            $display("FPGA_Reg_Test_1: ID REG  Register Address=0x%x , read=0x%x at time %0t", 
                                                                                                     (FPGA_REG_BASE_ADDRESS + target_address[7:0]), 
						                                                                                                            read_data, 
                                                                                                                                    $realtime);
	end
	
	
	#5000
	$finish;

end

endmodule // testbench_top

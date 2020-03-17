-- IO DECODER for SCOMP
-- This eliminates the need for a lot of NAND decoders or Comparators 
--    that would otherwise be spread around the TOP_SCOMP BDF

LIBRARY IEEE;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY IO_DECODER IS

  PORT
  (
    IO_ADDR       : IN STD_LOGIC_VECTOR(7 downto 0);
    IO_CYCLE      : IN STD_LOGIC;
    SWITCH_EN     : OUT STD_LOGIC;
    LED_EN        : OUT STD_LOGIC;
    TIMER_EN      : OUT STD_LOGIC;
    DIG_IN_EN     : OUT STD_LOGIC;
    HEX1_EN       : OUT STD_LOGIC;
    HEX2_EN       : OUT STD_LOGIC;
    LCD_EN        : OUT STD_LOGIC;
    LED2_EN       : OUT STD_LOGIC;
    BEEP_EN       : OUT STD_LOGIC;
    CT_EN         : OUT STD_LOGIC;
    L_POS_EN      : OUT STD_LOGIC;
    L_VEL_EN      : OUT STD_LOGIC;
    L_VELCTRL_EN  : OUT STD_LOGIC;
    R_POS_EN      : OUT STD_LOGIC;
    R_VEL_EN      : OUT STD_LOGIC;
    R_VELCTRL_EN  : OUT STD_LOGIC;
    SONAR_EN      : OUT STD_LOGIC;
    I2C_CMD_EN    : OUT STD_LOGIC;
    I2C_DATA_EN   : OUT STD_LOGIC;
    I2C_RDY_EN    : OUT STD_LOGIC;
    UART_D_EN     : OUT STD_LOGIC;
    UART_S_EN     : OUT STD_LOGIC;
    XPOS_EN       : OUT STD_LOGIC;
    YPOS_EN       : OUT STD_LOGIC;
    TPOS_EN       : OUT STD_LOGIC;
    POS_RSTN      : OUT STD_LOGIC;
    RIN_EN        : OUT STD_LOGIC;
    LIN_EN        : OUT STD_LOGIC;
    IRHI_EN		  : OUT STD_LOGIC;
    IRLO_EN       : OUT STD_LOGIC;
    SRAM_IO_WRITE : OUT STD_LOGIC;
    SRAM_CRTL_WE  : OUT STD_LOGIC;
    SRAM_CTRL_OE  : OUT STD_LOGIC;
    SRAM_ADHI     : OUT STD_LOGIC_VECTOR(1 downto 0);
    SRAM_CLOCK	  : OUT STD_LOGIC
  );

END ENTITY;

ARCHITECTURE a OF IO_DECODER IS

  SIGNAL  IO_INT  : INTEGER RANGE 0 TO 511;
  
BEGIN

  IO_INT <= TO_INTEGER(UNSIGNED(IO_CYCLE & IO_ADDR));
  -- note that this results in a three-digit hex number whose 
  --  upper digit is 1 if IO_CYCLE is asserted, and whose
  --  lower two digits are the I/O address being presented
  -- The lines below decode each valid I/O address ...
        
  SWITCH_EN <= '1'    WHEN IO_INT = 16#100# ELSE '0'; -- (IO_CYCLE = '1' && IO_ADDR = "00")
  LED_EN <= '1'       WHEN IO_INT = 16#101# ELSE '0';
  TIMER_EN <= '1'     WHEN IO_INT = 16#102# ELSE '0';
  DIG_IN_EN <= '1'    WHEN IO_INT = 16#103# ELSE '0';
  HEX1_EN <= '1'      WHEN IO_INT = 16#104# ELSE '0';
  HEX2_EN <= '1'      WHEN IO_INT = 16#105# ELSE '0';
  LCD_EN <= '1'       WHEN IO_INT = 16#106# ELSE '0';
  LED2_EN <= '1'      WHEN IO_INT = 16#107# ELSE '0';
  BEEP_EN <= '1'      WHEN IO_INT = 16#10A# ELSE '0';
  CT_EN <= '1'        WHEN IO_INT = 16#10C# ELSE '0';
  L_POS_EN <= '1'     WHEN IO_INT = 16#180# ELSE '0';
  L_VEL_EN <= '1'     WHEN IO_INT = 16#182# ELSE '0';
  L_VELCTRL_EN <= '1' WHEN IO_INT = 16#183# ELSE '0';
  R_POS_EN <= '1'     WHEN IO_INT = 16#188# ELSE '0';
  R_VEL_EN <= '1'     WHEN IO_INT = 16#18A# ELSE '0';
  R_VELCTRL_EN <= '1' WHEN IO_INT = 16#18B# ELSE '0';
  I2C_CMD_EN <= '1'   WHEN IO_INT = 16#190# ELSE '0';
  I2C_DATA_EN <= '1'  WHEN IO_INT = 16#191# ELSE '0';
  I2C_RDY_EN <= '1'   WHEN IO_INT = 16#192# ELSE '0';
  UART_D_EN <= '1'    WHEN IO_INT = 16#198# ELSE '0';
  UART_S_EN <= '1'    WHEN IO_INT = 16#199# ELSE '0';
  SONAR_EN <= '1'     WHEN ((IO_INT >= 16#1A0#) AND (IO_INT < 16#1B7#) ) ELSE '0';
  XPOS_EN <= '1'      WHEN IO_INT = 16#1C0# ELSE '0';
  YPOS_EN <= '1'      WHEN IO_INT = 16#1C1# ELSE '0';
  TPOS_EN <= '1'      WHEN IO_INT = 16#1C2# ELSE '0';
  POS_RSTN <= '0'     WHEN IO_INT = 16#1C3# ELSE '1';
  RIN_EN <= '1'       WHEN IO_INT = 16#1C8# ELSE '0';
  LIN_EN <= '1'       WHEN IO_INT = 16#1C9# ELSE '0';
  IRHI_EN <= '1'      WHEN IO_INT = 16#1D0# ELSE '0';
  IRLO_EN <= '1'      WHEN IO_INT = 16#1D1# ELSE '0';
			 
  -- IO_ADDR from 0x10 thru 0x1F are for SRAM
  -- R00 thru R11 have ADDR 0x10 thru 0x13
			     
-- SRAM: 0b0001 0000 thru 0b0001 1111
-- SRAM read: 0b0001 0000 thru 0b 0001 0011
			     
IF (IO_INT > 16#109#) THEN
      -- SRAM 
 	IF (IO_INT < 16#114#) THEN
	    SRAM_CTRL_WE <= '0';
	    SRAM_CTRL_OE <= '1';
	    SRAM_ADHI <= IO_ADDR(1 DOWNTO 0);
	ELSIF (????) THEN
	    -- write stuff
	ELSE
	    -- illegal
	END IF;
ELSE
	       -- non-SRAM addresses
	       SRAM_CTRL_WE <= '0';
	       SRAM_CTRL_OE <= '0';
	       SRAM_ADHI <= "00"; -- this doesn't really matter. SRAM_CONTROLLER should never read inputs during such states
END IF;
			   
 -- SRAM_CRTL_WE <= '1' WHEN IO_INT = 16#111# ELSE '0';
  --SRAM_CTRL_OE <= '1' WHEN IO_INT = 16#112# ELSE '0';
  --SRAM_ADHI <= '1'	WHEN IO_INT = 16#113# ELSE '0';
  --SRAM_CLOCK <= '1'  WHEN IO_INT = 16#114# ELSE '0'; --Clock state needs to be checked
      
  --WHEN (IO_INT=1XX) => --IO_CYCLE=1, XX = Address being presented
	--SRAM_CTRL_WE <= '1';
	--SRAM_CTRL_OE = '1'; 
	--SRAM_ADHI <= "01";
	
	
	
END a;

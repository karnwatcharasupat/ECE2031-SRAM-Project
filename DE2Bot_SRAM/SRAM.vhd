LIBRARY IEEE;
LIBRARY ALTERA_MF;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE ALTERA_MF.ALTERA_MF_COMPONENTS.ALL;
USE LPM.LPM_COMPONENTS.ALL;

ENTITY SRAM_CONTROLLER IS
	PORT (
		IO_WRITE		:	IN STD_LOGIC;
		CTRL_WE			:	IN STD_LOGIC;
		CTRL_OE			:	IN STD_LOGIC;
		ADHI			:	IN STD_LOGIC_VECTOR(1 DOWNTO 0);
		CLOCK			:	IN STD_LOGIC;
		
		SRAM_CE_N		:	OUT STD_LOGIC;
		SRAM_WE_N		:	OUT STD_LOGIC; --WE USE THIS
		SRAM_OE_N		:	OUT STD_LOGIC; -- WE USE THIS
		SRAM_UB_N		:	OUT STD_LOGIC;
		SRAM_LB_N		:	OUT STD_LOGIC;
		SRAM_ADLO		:	OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- WE USE THIS
		SRAM_ADHI		:	OUT STD_LOGIC_VECTOR(1 DOWNTO 0); -- WE USE THIS
		
		SRAM_DQ			:	INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		IO_DATA			:	INOUT STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
END SRAM_CONTROLLER;

-- Declare SRAM_CONTROLLER architecture v0
ARCHITECTURE v0 OF SRAM_CONTROLLER IS
	TYPE STATE_TYPE IS (
		IDLE,
		WARM_UP,
		READ_PREP,	
		READ_DONE,
		WRITE_PREP, 	-- placeholder for write states
		WRITE_DONE
	);
	
	-- Declare internal signals
	SIGNAL STATE 	:	STATE_TYPE;						-- SRAM states
	SIGNAL ADDR		:	STD_LOGIC_VECTOR(17 DOWNTO 0);	-- Address
	SIGNAL DATA		:	STD_LOGIC_VECTOR(15 DOWNTO 0);	-- Data
	SIGNAL WE		:	STD_LOGIC;
	SIGNAL OE		:	STD_LOGIC;
	SIGNAL CE		:	STD_LOGIC;
	SIGNAL UB		:	STD_LOGIC;
	SIGNAL LB		:	STD_LOGIC;
    SIGNAL READ_SIG :   STD_LOGIC_VECTOR(2 DOWNTO 0);  -- READ SIGNAL FOR SRAM 
	
BEGIN
	-- Mirror unused internal signals to ports
	CE			<= '1';
	UB			<= '1';
	LB			<= '1';
	SRAM_CE_N	<=	NOT CE;
	SRAM_UB_N	<= 	NOT UB;
	SRAM_LB_N	<=	NOT LB;
	
	-- Use LPM function to drive I/O bus
	IO_BUS: LPM_BUSTRI
	GENERIC MAP (
		lpm_width => 16
	)
	PORT MAP (
		data     => SRAM_DQ,
		enabledt => OE, -- if HIGH, enable data onto tridata (READ cycle)
		enabletr => WE,	-- if HIGH, enable tridata onto data (WRITE cycle)
		tridata  => IO_DATA
	);
	
    --Concatenated Signals for Read Operation of SRAM
    READ_SIG	<=	CTRL_OE & ADHI; 
        
	PROCESS (CLOCK)
	BEGIN
		IF (RISING_EDGE(CLOCK)) THEN
			CASE STATE IS
				WHEN IDLE =>
					IF (IO_WRITE = '1') THEN
						STATE <= FETCH;
					ELSE
						STATE <= IDLE;
					END IF;
					
				WHEN WARM_UP =>
					ADDR	<= 	ADHI & IO_DATA;	-- As IO_DATA only contains the address related stuff During WarmUp
					-- ADLO is contained in IO_DATA
					-- concat ADHI and IO_DATA to get 18-bit address	
				
					----------- [[ KARN'S COMMENT STARTS]] ----------
					-- * remove these two lines
					SRAM_ADHI	<=	ADDR(17 DOWNTO 16);
					SRAM_ADLO	<=	ADDR(15 DOWNTO 0); -- Have the Address Fired
		
					-- * WARM_UP is shared between read and write
					--	the address should not be fired prematurely esp. for write
					--	since this will cause data corruption
					------------ [[ KARN'S COMMENT ENDS]] -----------
				        
					
					IF (CTRL_WE = '1')	THEN
						STATE <= WRITE_PREP;
					ELSIF (CTRL_OE = '1' AND CTRL_WE = '0' AND ADHI = "01") THEN
						----------- [[ KARN'S COMMENT STARTS]] ----------
						-- * ADHI should NOT be in this logic. R01 is used as an example only
						--	READ_PREP should be triggered regardless of address
						--	i.e. for all ADHI = 00, 01, 10, 11
						------------ [[ KARN'S COMMENT ENDS]] -----------
						STATE <= READ_PREP;
					ELSE
						STATE <= IDLE;
					END IF;
				
				WHEN READ_PREP =>
					--Current State Handling...
					SRAM_ADHI	<=	ADDR(17 DOWNTO 16);
					SRAM_ADLO	<=	ADDR(15 DOWNTO 0); -- Keep the Address Fired
					----------- [[ KARN'S COMMENT STARTS]] ----------
					SRAM_OE         <=      '0';
					SRAM_WE         <=      '1';

					-- * (minor) SRAM_OE and SRAM_WE don't exist
					-- 	the two output signals defined are SRAM_OE_N and SRAM_WE_N
					--	(see PORT declaration above)
					------------ [[ KARN'S COMMENT ENDS]] -----------

					----------- [[ KARN'S COMMENT STARTS]] ----------
					SRAM_DQ         <=      IO_DATA;  

					-- * If we were not using LPM_BUSTRI (see below)
					--	this should be IO_DATA <= SRAM_DQ since we are reading from SRAM into FPGA
					-- **BUT**
					-- * Both SRAM_DQ and IO_DATA are tristate bus which are handled by LPM_BUSTRI
					--	when OE is set to high, the LPM_BUSTRI automatically let SRAM_DQ flows INTO IO_DATA
					-- * Point for discussion:
					--	** should we define a new signal to enable the direction of data flow in the tristate bus
					--		instead of the current OE (SRAM_DQ -> IO_DATA) and WE (IO_DATA -> SRAM_DQ)?
					--	** OE and WE are internal signals that we have been a little loose with wrt to timing
					--		It might be better to define a new signal 
					--		to control LPM_BUSTRI's enabledtr and enableddt to make things more precise
					--	** For reference, see http://www.pldworld.com/_altera/html/_sw/q2help/source/mega/mega_file_lpm_bustri.htm
					------------ [[ KARN'S COMMENT ENDS]] -----------

					--Next State Logic Set Up!
					IF (CTRL_OE = '0') THEN
						STATE <= READ_DONE;
					ELSE 
						STATE <= READ_PREP;
					
				WHEN WRITE_PREP =>
					--Current State Handling...
					SRAM_ADHI	<=	ADDR(17 DOWNTO 16);
					SRAM_ADLO	<=	ADDR(15 DOWNTO 0); -- Keep the Address Fired

					----------- [[ KARN'S COMMENT STARTS]] ----------
					-- * (minor) SRAM_OE and SRAM_WE don't exist
					-- 	the two output signals defined are SRAM_OE_N and SRAM_WE_N
					--	(see PORT declaration above)
					------------ [[ KARN'S COMMENT ENDS]] -----------
					SRAM_OE         <=      '1';
					SRAM_WE         <=      '0';
					----------- [[ KARN'S COMMENT STARTS]] ----------
					-- * Write cycle timing is also a little different. 
					--	SRAM_WE_N should not be written LOW before address stabilizes.
					--	After SRAM_OE_N is forced HIGH and the address is driven,
					--	we should wait 10 ns (a clock cycle) before setting SRAM_WE_N to LOW
					--	in order to avoid data corruption.
					-- * Anyway, we will have to discuss this in the next meeting so don't worry about this for now
					------------ [[ KARN'S COMMENT ENDS]] -----------
					
					----------- [[ KARN'S COMMENT STARTS]] ----------
					SRAM_DQ         <=      IO_DATA;  --That's for the SCOMP To get connected to the GPIO that goes to the SRAM.
	                                -- * Both SRAM_DQ and IO_DATA are tristate bus which are handled by LPM_BUSTRI
					--	when WE is set to high, the LPM_BUSTRI automatically let IO_DATA flows INTO SRAM_DQ
					-- * Will have to fix this enabling later coz it breaks timing requirement.
					-- * Point for discussion:
					--	** should we define a new signal to enable the direction of data flow in the tristate bus
					--		instead of the current OE (SRAM_DQ -> IO_DATA) and WE (IO_DATA -> SRAM_DQ)?
					--	** OE and WE are internal signals that we have been a little loose with wrt to timing
					--		It might be better to define a new signal 
					--		to control LPM_BUSTRI's enabledtr and enableddt to make things more precise
					--	** For reference, see http://www.pldworld.com/_altera/html/_sw/q2help/source/mega/mega_file_lpm_bustri.htm
					------------ [[ KARN'S COMMENT ENDS]] -----------


					--Next State Logic Set Up!
					IF (CTRL_WE = '0') THEN
						STATE <= WRITE_DONE;
					ELSE 
						STATE <= WRITE_PREP;

				WHEN READ_DONE => 
					----------- [[ KARN'S COMMENT STARTS]] ----------
		                        SRAM_OE <= '1';
					-- * (minor) SRAM_OE and SRAM_WE don't exist
					-- 	the two output signals defined are SRAM_OE_N and SRAM_WE_N
					--	(see PORT declaration above)
					------------ [[ KARN'S COMMENT ENDS]] -----------
				        STATE <= IDLE;

				WHEN WRITE_DONE =>
					----------- [[ KARN'S COMMENT STARTS]] ----------
					SRAM_WE <= '1';
					-- * (minor) SRAM_OE and SRAM_WE don't exist
					-- 	the two output signals defined are SRAM_OE_N and SRAM_WE_N
					--	(see PORT declaration above)
					------------ [[ KARN'S COMMENT ENDS]] -----------
					STATE <= IDLE;
					
				WHEN OTHERS =>
					STATE <= IDLE;
					
			END CASE;
		END IF;
	END PROCESS;

END v0;
	

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
		IO_WRITE		:	IN STD_LOGIC;				-- from SCOMP
		CTRL_WE			:	IN STD_LOGIC;				-- from IO_DECODER
		CTRL_OE			:	IN STD_LOGIC;				-- from IO_DECODER
		ADHI			:	IN STD_LOGIC_VECTOR(1 DOWNTO 0);	-- from IO_DECODER
		CLOCK			:	IN STD_LOGIC;				-- from external (could be SCOMP)
		
		SRAM_CE_N		:	OUT STD_LOGIC;
		SRAM_WE_N		:	OUT STD_LOGIC; 						
		SRAM_OE_N		:	OUT STD_LOGIC; 						-
		SRAM_UB_N		:	OUT STD_LOGIC;
		SRAM_LB_N		:	OUT STD_LOGIC;
		
		-- ##Karn's comment##
		-- in the new project SRAM_ADLO and SRAM_ADHI are combined into SRAM_ADDR
		SRAM_ADLO		:	OUT STD_LOGIC_VECTOR(15 DOWNTO 0); 	
		SRAM_ADHI		:	OUT STD_LOGIC_VECTOR(1 DOWNTO 0); 	
		
		SRAM_DQ			:	INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);	-- to/from SRAM hardware
		IO_DATA			:	INOUT STD_LOGIC_VECTOR(15 DOWNTO 0)	-- to/from SCOMP
	);
END SRAM_CONTROLLER;

-- Declare SRAM_CONTROLLER architecture v0
ARCHITECTURE v0 OF SRAM_CONTROLLER IS
	TYPE STATE_TYPE IS (
		IDLE,
		WARM_UP,
		READ_PREP,	
		READ_DONE,
		WRITE_ADDR_PREP, 	-- placeholder for write states
		WRITE_WE_ASSERT,
		WRITE_WAIT,	        -- Wait for signal  
		WRITE_LOCK          -- Clean Up!
	);
	
	-- Declare internal signals
	SIGNAL STATE 		:	STATE_TYPE;						-- SRAM states
	SIGNAL ADDR		:	STD_LOGIC_VECTOR(17 DOWNTO 0);	-- Address
	SIGNAL DATA		:	STD_LOGIC_VECTOR(15 DOWNTO 0);	-- Data
	SIGNAL WE		:	STD_LOGIC;
	SIGNAL OE		:	STD_LOGIC;
	SIGNAL CE		:	STD_LOGIC;
	SIGNAL UB		:	STD_LOGIC;
	SIGNAL LB		:	STD_LOGIC;
	SIGNAL DT_ENABLE	:	STD_LOGIC;
	SIGNAL TR_ENABLE	:	STD_LOGIC;
	
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
		enabledt => DT_ENABLE, -- if HIGH, enable data onto tridata (READ cycle)
		enabletr => TR_ENABLE,	-- if HIGH, enable tridata onto result (WRITE cycle)
		tridata  => IO_DATA,
		result => DATA
	);
	
	PROCESS (CLOCK)
	BEGIN
		IF (RISING_EDGE(CLOCK)) THEN
			CASE STATE IS
				WHEN IDLE =>
					-- ## Karn's edit ##
					SRAM_OE_N <= '1';
					SRAM_WE_N <= '1';
					-- disable everything to be safe
					-- ##
				
					DT_ENABLE <= '0';
					TR_ENABLE <= '0';
				
					IF (IO_WRITE = '1') THEN
						STATE <= WARM_UP;
					ELSE
						STATE <= IDLE;
					END IF;
					
				WHEN WARM_UP =>
					ADDR	<= 	ADHI & IO_DATA;	-- As IO_DATA only contains the address related stuff During WarmUp
					-- ADLO is contained in IO_DATA
					-- concat ADHI and IO_DATA to get 18-bit address.
				        
					-- ## Karn's comment ##
					-- I think this is redundant since WARM_UP is only reachable via IDLE
					--	and IDLE alr has these two lines
					DT_ENABLE <= '0';
					TR_ENABLE <= '0';		
					-- ##
					
					IF (CTRL_WE = '1')	THEN
						-- write cycle
						WE <= '1';
						-- ## Karn's edit ##
						OE <= '0';
						SRAM_OE_N <= NOT(OE);
						-- help make sure that we don't need to worry about additional timing requirement
						-- ##
						STATE <= WRITE_ADDR_PREP;
					ELSIF (CTRL_OE = '1' AND CTRL_WE = '0') THEN
						-- read cycle
						STATE <= READ_PREP;
					ELSE
						-- catch error
						STATE <= IDLE;
					END IF;
				
				WHEN READ_PREP =>
					SRAM_ADHI	<=	ADDR(17 DOWNTO 16);
					SRAM_ADLO	<=	ADDR(15 DOWNTO 0); -- Keep the Address Fired!
					SRAM_OE_N       <=      '0';
					SRAM_WE_N	<=      '1';
					
					DT_ENABLE <= '1';
					-- equiv: IO_DATA         <=      SRAM_DQ;  
					
					--Next State Logic Setup
					IF (CTRL_OE = '0') THEN
						STATE <= READ_DONE;
					ELSE 
						STATE <= READ_PREP;
					END IF;
						
				WHEN READ_DONE =>
					SRAM_OE_N <= '1';
				    	STATE <= IDLE;
					
				WHEN WRITE_ADDR_PREP =>
					-- output address to hardware
					SRAM_ADHI	<=	ADDR(17 DOWNTO 16);
					SRAM_ADLO	<=	ADDR(15 DOWNTO 0); 
					-- let the address be stable first, before enabling write

					-- ## Karn's edit ##
					-- Removed these two
					-- If SRAM addresses are not stable yet this will cause memory corruption
					--
					-- SRAM_OE_N         <=      '1';
					-- SRAM_WE_N         <=      '0';
					-- ##

					-- then wait a cycle
                   	STATE <= WRITE_WE_ASSERT;
			    
				WHEN WRITE_WE_ASSERT =>
				    -- enable write on the hardware
				    SRAM_WE_N <= NOT(WE); -- let garbage goes into the memory we want to write
				    -- and wait for SRAM to not drive the data line
				    STATE <= WRITE_WAIT;
				
				WHEN WRITE_WAIT =>
					TR_ENABLE <= '1'; -- let data from SCOMP goes into internal ctrl latch
					-- equiv: DATA <= IO_DATA
					-- let the data from SCOMP flow into the DATA latch

					SRAM_DQ <= DATA;
					-- then write that data to the hardware
				
					IF (CTRL_OE = '1') THEN
						STATE <= WRITE_LOCK;
				    ELSE
						STATE <= WRITE_WAIT;
				    END IF;
						
				WHEN WRITE_LOCK =>
					-- ## Karn's edit
					TR_ENABLE <= '0';
					-- just for safety (doesn't actually matter)
					-- ##
					
					-- disable any data flow
					WE <= '0';
					SRAM_WE_N <= NOT(WE);
					STATE <= IDLE;
				
				WHEN OTHERS =>
					STATE <= IDLE;
					
			END CASE;
		END IF;
	END PROCESS;

END v0;

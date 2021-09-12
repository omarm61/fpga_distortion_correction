library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unimacro;
use unimacro.VCOMPONENTS.all;

entity calc_pixel_position is
    generic (
        C_INIT_THETA_FILE : string := "NONE"
    );
    port (
        -- Clock/Reset
        i_aclk    : in std_logic;
        i_aresetn : in std_logic;
        -- Configuration
        i_center_x : in std_logic_vector (10 downto 0);
        i_center_y : in std_logic_vector (10 downto 0);
        -- LUT Theta Configure
        i_lut_theta_wdata   : in  std_logic_vector (15 downto 0);
        o_lut_theta_rdata   : out std_logic_vector (15 downto 0);
        i_lut_theta_addr    : in  std_logic_vector (10 downto 0);
        i_lut_theta_enable  : in  std_logic;
        i_lut_theta_wren    : in  std_logic;
        -- Destination Positon -- Pixel location in corrected image
        s_axis_tdata     : in  std_logic_vector (21 downto 0);
        s_axis_tvalid    : in  std_logic;
        s_axis_tready    : out std_logic;
        s_axis_tuser_sof : in  std_logic;
        s_axis_tlast     : in  std_logic;
        -- Source Position -- Pixel Location in raw image
        m_axis_tdata     : out std_logic_vector (21 downto 0);
        m_axis_tvalid    : out std_logic;
        m_axis_tready    : in  std_logic;
        m_axis_tuser_sof : out std_logic;
        m_axis_tlast     : out std_logic
    );
end calc_pixel_position;

architecture rtl of calc_pixel_position is

    -- Resets
    signal w_dsp_reset : std_logic;
    signal w_lut_reset : std_logic;
    --
    constant C_AXIS_LATENCY : integer := 6; -- 5cc
    signal rs_axis_tvalid_shift    : std_logic_vector(C_AXIS_LATENCY-1 downto 0);
    signal rs_axis_tuser_sof_shift : std_logic_vector(C_AXIS_LATENCY-1 downto 0);
    signal rs_axis_tlast_shift     : std_logic_vector(C_AXIS_LATENCY-1 downto 0);

    --Input position
    signal w_lut_b_theta_addr   : std_logic_vector(10 downto 0);
    signal w_lut_b_theta_data   : std_logic_vector(15 downto 0);
    signal w_lut_b_theta_valid  : std_logic;

    signal r_pos_x_sign       : std_logic;
    signal r_pos_y_sign       : std_logic;
    signal r_pos_x_sign_shift : std_logic_vector (3 downto 0);
    signal r_pos_y_sign_shift : std_logic_vector (3 downto 0);

    -- DSP48 Stage 1
    signal r_dsp_s1_ab : std_logic_vector (47 downto 0);
    alias  w_dsp_s1_a  : std_logic_vector (29 downto 0) is r_dsp_s1_ab (47 downto 18);
    alias  w_dsp_s1_b  : std_logic_vector (17 downto 0) is r_dsp_s1_ab (17 downto 0);
    ----
    signal r_dsp_s1_c  : std_logic_vector (47 downto 0);
    ----
    signal w_dsp_s1_p      : std_logic_vector (47 downto 0);
    alias  w_dsp_s1_p_newx : std_logic_vector (23 downto 0) is w_dsp_s1_p(23 downto 0);
    alias  w_dsp_s1_p_newy : std_logic_vector (23 downto 0) is w_dsp_s1_p(47 downto 24);
    ----
    --signal w_dsp_s1_carryout : std_logic_vector (3 downto 0);

	-- Stage 2 - calculate newX^2
	signal w_dsp_s2_x_a : std_logic_vector (29 downto 0); -- In
	signal w_dsp_s2_x_b : std_logic_vector (17 downto 0); -- In
	signal w_dsp_s2_x_c : std_logic_vector (47 downto 0); -- In
	--
	signal w_dsp_s2_x_p : std_logic_vector (47 downto 0); -- Out

	-- Stage 2 - calculate newY^2
	signal w_dsp_s2_y_a : std_logic_vector (29 downto 0); -- In
	signal w_dsp_s2_y_b : std_logic_vector (17 downto 0); -- In
	signal w_dsp_s2_y_c : std_logic_vector (47 downto 0); -- In
	--
	signal w_dsp_s2_y_p : std_logic_vector (47 downto 0); -- Out


    ---- DSP48 Stage 3
    signal w_dsp_s3_ab : std_logic_vector (47 downto 0);
    alias  w_dsp_s3_a  : std_logic_vector (29 downto 0) is w_dsp_s3_ab (47 downto 18);
    alias  w_dsp_s3_b  : std_logic_vector (17 downto 0) is w_dsp_s3_ab (17 downto 0);
    ----
    signal w_dsp_s3_c  : std_logic_vector (47 downto 0);
    ----
    signal w_dsp_s3_p  : std_logic_vector (47 downto 0); -- ru

	-- Stage 4 - Mutliplication and subtraction - P = C + (B*A)
	signal w_dsp_s4_x_a : std_logic_vector (29 downto 0); -- In
	signal w_dsp_s4_x_b : std_logic_vector (17 downto 0); -- In
	signal w_dsp_s4_x_c : std_logic_vector (47 downto 0); -- In
	--
	signal w_dsp_s4_x_p : std_logic_vector (47 downto 0); -- Out
    --
    signal w_dsp_s4_x_alumode : std_logic_vector (3 downto 0);
    signal w_dsp_s4_x_carryin : std_logic;

	-- Stage 4 - Mutliplication and subtraction - P = C + (B*A)
	signal w_dsp_s4_y_a : std_logic_vector (29 downto 0); -- In
	signal w_dsp_s4_y_b : std_logic_vector (17 downto 0); -- In
	signal w_dsp_s4_y_c : std_logic_vector (47 downto 0); -- In
	--
	signal w_dsp_s4_y_p : std_logic_vector (47 downto 0); -- Out
    --
    signal w_dsp_s4_y_alumode : std_logic_vector (3 downto 0);
    signal w_dsp_s4_y_carryin : std_logic;
    --
    signal w_calc_pos_x : std_logic_vector (10 downto 0);
    signal w_calc_pos_y : std_logic_vector (10 downto 0);

	--
    signal r_dsp_s1_p_newx_d   : std_logic_vector (23 downto 0);
    signal r_dsp_s1_p_newx_dd  : std_logic_vector (23 downto 0);
    signal r_dsp_s1_p_newx_ddd : std_logic_vector (23 downto 0);
	--
    signal r_dsp_s1_p_newy_d   : std_logic_vector (23 downto 0);
    signal r_dsp_s1_p_newy_dd  : std_logic_vector (23 downto 0);
    signal r_dsp_s1_p_newy_ddd : std_logic_vector (23 downto 0);

	-- BRAM LUT
    component BRAM_TDP_MACRO is
        generic (
            BRAM_SIZE : string := "18Kb";
            DEVICE : string := "VIRTEX5";
            INIT_FILE : string := "NONE";
            READ_WIDTH_A : integer := 1;
            READ_WIDTH_B : integer := 1;
            WRITE_WIDTH_A : integer := 1;
            WRITE_WIDTH_B : integer := 1

        );
        port (

            DOA : out std_logic_vector(READ_WIDTH_A-1 downto 0);
            DOB : out std_logic_vector(READ_WIDTH_B-1 downto 0);

            ADDRA : in std_logic_vector;
            ADDRB : in std_logic_vector;
            CLKA : in std_ulogic;
            CLKB : in std_ulogic;
            DIA : in std_logic_vector(WRITE_WIDTH_A-1 downto 0);
            DIB : in std_logic_vector(WRITE_WIDTH_B-1 downto 0);
            ENA : in std_ulogic;
            ENB : in std_ulogic;
            REGCEA : in std_ulogic;
            REGCEB : in std_ulogic;
            RSTA : in std_ulogic;
            RSTB : in std_ulogic;
            WEA : in std_logic_vector;
            WEB : in std_logic_vector

        );
    end component;

begin


    w_lut_reset <= not i_aresetn;
    w_dsp_reset <= not i_aresetn;

    --
    s_axis_tready   <= m_axis_tready;
    --
    w_calc_pos_x <= "000" & x"00" when w_dsp_s4_x_p(37) = '1' else w_dsp_s4_x_p(25 downto 15);
    w_calc_pos_y <= "000" & x"00" when w_dsp_s4_y_p(37) = '1' else w_dsp_s4_y_p(25 downto 15);
    m_axis_tdata     <= w_calc_pos_y & w_calc_pos_x;
    m_axis_tvalid    <= rs_axis_tvalid_shift(C_AXIS_LATENCY-1);
    m_axis_tuser_sof <= rs_axis_tuser_sof_shift(C_AXIS_LATENCY-1);
    m_axis_tlast     <= rs_axis_tlast_shift(C_AXIS_LATENCY-1);

    -- Delay AXI-Stream control signals to account for module latency
    delay_axis_proc: process(i_aclk, i_aresetn)
    begin
        if (i_aresetn = '0') then
            rs_axis_tvalid_shift    <= (others => '0');
            rs_axis_tuser_sof_shift <= (others => '0');
            rs_axis_tlast_shift     <= (others => '0');
        elsif (i_aclk'event and (i_aclk = '1')) then
            -- shift control signals in
            rs_axis_tvalid_shift    <= rs_axis_tvalid_shift(C_AXIS_LATENCY-2 downto 0) & s_axis_tvalid;
            rs_axis_tuser_sof_shift <= rs_axis_tuser_sof_shift(C_AXIS_LATENCY-2 downto 0) & s_axis_tuser_sof;
            rs_axis_tlast_shift     <= rs_axis_tlast_shift(C_AXIS_LATENCY-2 downto 0) & s_axis_tlast;
        end if;
    end process;

    dsp_s1_sign_proc : process (i_aclk, i_aresetn)
    begin
        if (i_aresetn ='0') then
            r_dsp_s1_ab <= (others => '0');
            r_dsp_s1_c  <= (others => '0');
            r_pos_x_sign <= '0';
            r_pos_y_sign <= '0';
            r_pos_x_sign_shift <= (others => '0');
            r_pos_y_sign_shift <= (others => '0');
        elsif (i_aclk'event and (i_aclk = '1')) then
            -- Shift the measurement sign for stage 3 of the calculation
            r_pos_x_sign_shift <= r_pos_x_sign_shift(2 downto 0) & r_pos_x_sign;
            r_pos_y_sign_shift <= r_pos_y_sign_shift(2 downto 0) & r_pos_y_sign;
            -- Subtract larger number from smaller number to ensure a positive  output
            if (s_axis_tvalid = '1') then
                -- newX
                if (s_axis_tdata(10 downto 0) > i_center_x) then
                    r_pos_x_sign <= '0'; -- Positive position
                    r_dsp_s1_ab(23 downto 0) <= '0' & x"000" & s_axis_tdata(10 downto 0);
                    r_dsp_s1_c(23 downto 0)  <= '0' & x"000" & i_center_x;
                else
                    r_pos_x_sign <= '1'; -- Negative output
                    r_dsp_s1_ab(23 downto 0) <= '0' & x"000" & i_center_x;
                    r_dsp_s1_c(23 downto 0)  <= '0' & x"000" & s_axis_tdata(10 downto 0);
                end if;
                -- newY
                if (s_axis_tdata(21 downto 11) > i_center_y) then
                    r_pos_y_sign <= '0'; -- Positive position
                    r_dsp_s1_ab(47 downto 24) <= '0' & x"000" & s_axis_tdata(21 downto 11);
                    r_dsp_s1_c(47 downto 24)  <= '0' & x"000" & i_center_y;
                else
                    r_pos_y_sign <= '1'; -- Negative position
                    r_dsp_s1_ab(47 downto 24) <= '0' & x"000" & i_center_y;
                    r_dsp_s1_c(47 downto 24)  <= '0' & x"000" & s_axis_tdata(21 downto 11);
                end if;
            end if;
        end if;
    end process;

    -- delay the calculated newX and newY by two clock cycles
    newxy_delay_proc: process(i_aclk, i_aresetn)
    begin
        if(i_aresetn = '0') then
            r_dsp_s1_p_newx_d   <= (others => '0');
            r_dsp_s1_p_newx_dd  <= (others => '0');
            r_dsp_s1_p_newx_ddd <= (others => '0');
            r_dsp_s1_p_newy_d   <= (others => '0');
            r_dsp_s1_p_newy_dd  <= (others => '0');
            r_dsp_s1_p_newy_ddd <= (others => '0');
        elsif (i_aclk'event and (i_aclk = '1')) then
            -- Check for overflow X
            if (w_dsp_s1_p_newx(23) = '0') then
                r_dsp_s1_p_newx_d  <= w_dsp_s1_p_newx;
            else
                r_dsp_s1_p_newx_d  <= (others => '0');
            end if;
            r_dsp_s1_p_newx_dd  <= r_dsp_s1_p_newx_d;
            r_dsp_s1_p_newx_ddd <= r_dsp_s1_p_newx_dd;
            --
            --
            -- Check for overflow Y
            if (w_dsp_s1_p_newy(23) = '0') then
                r_dsp_s1_p_newy_d  <= w_dsp_s1_p_newy;
            else
                r_dsp_s1_p_newy_d  <= (others => '0');
            end if;
            r_dsp_s1_p_newy_dd <= r_dsp_s1_p_newy_d;
            r_dsp_s1_p_newy_ddd <= r_dsp_s1_p_newy_dd;
        end if;
    end process;

    -- newX = i - pPoint.x
    -- newY = j - pPoint.y
    -- P = A:B - C
    -- Stage one - Addition
    DSP48E1_stage1_inst : entity work.dsp48_wrap
    generic map (
        PREG => 1,			    -- Pipeline stages for P (0 or 1)
        USE_SIMD => "TWO24" )	-- SIMD selection ("ONE48", "TWO24", "FOUR12")
    port map (
        CLK     => i_aclk,         -- 1-bit input: Clock input
        A       => w_dsp_s1_a,	   -- S1_0, S1_2[5:0]
        B       => w_dsp_s1_b,	   -- S1_2[11:6]
        C       => r_dsp_s1_c,	   -- S1_1, S1_3
        ALUMODE => "0001",		   -- 4-bit input: ALU control input
        OPMODE  => "0110011",	   -- 7-bit input: Operation mode input
        CEP     => rs_axis_tvalid_shift(0),	   -- 1-bit input: CE input for PREG
        -- Reset Signals
        RSTA          => w_dsp_reset,
        RSTB          => w_dsp_reset,
        RSTC          => w_dsp_reset,
        RSTD          => w_dsp_reset,
        RSTM          => w_dsp_reset,
        RSTP          => w_dsp_reset,
        RSTINMODE     => w_dsp_reset,
        RSTALUMODE    => w_dsp_reset,
        RSTCTRL       => w_dsp_reset,
        --
        P => w_dsp_s1_p,    -- 48-bit output: Primary data output
        CARRYOUT => open );	-- 4-bit carry output

    -- newX^2 = newX * newX
    w_dsp_s2_x_a <= "000000" & w_dsp_s1_p_newx;
    w_dsp_s2_x_b <= w_dsp_s1_p_newx(17 downto 0);
    w_dsp_s2_x_c <= x"000000000000";

    DSP48E1_stage2_x_inst : entity work.dsp48_wrap
	generic map (
	    PREG => 1,				        -- Pipeline stages for P (0 or 1)
	    USE_MULT => "MULTIPLY",
	    USE_DPORT => TRUE,
	    MASK => x"000000000000",		    -- 48-bit mask value for pattern detect
	    SEL_PATTERN => "PATTERN",			-- Select pattern value ("PATTERN" or "C")
	    USE_PATTERN_DETECT => "NO_PATDET",	-- ("PATDET" or "NO_PATDET")
	    USE_SIMD => "ONE48" )		        -- SIMD selection ("ONE48", "TWO24", "FOUR12")
	port map (
	    CLK       => i_aclk,            -- 1-bit input: Clock input
	    A         => w_dsp_s2_x_a,        -- newX
	    B         => w_dsp_s2_x_b,        -- newX
	    C         => w_dsp_s2_x_c,        -- 0
	    INMODE    => "00000",
	    OPMODE    => "0110101",          -- 7-bit input: Operation mode input
	    ALUMODE   => "0000", -- 7-bit input: Operation mode input
	    CARRYIN   => '0', -- 1-bit input: Carry input signal
	    CEC       => rs_axis_tvalid_shift(1),
	    CECARRYIN => rs_axis_tvalid_shift(1),
	    CECTRL    => rs_axis_tvalid_shift(1),
		CEM		  => rs_axis_tvalid_shift(1),  -- 1-bit input: CE input for Multiplier
	    CEP       => rs_axis_tvalid_shift(1),  -- 1-bit input: CE input for PREG
	    CEA1      => rs_axis_tvalid_shift(1),
	    -- Reset Signals
		RSTA          => w_dsp_reset,
		RSTB          => w_dsp_reset,
		RSTC          => w_dsp_reset,
		RSTD          => w_dsp_reset,
		RSTM          => w_dsp_reset,
		RSTP          => w_dsp_reset,
		RSTINMODE     => w_dsp_reset,
		RSTALUMODE    => w_dsp_reset,
		RSTCTRL       => w_dsp_reset,
		RSTALLCARRYIN => w_dsp_reset,
	    --
	    PATTERNDETECT => open,		  -- Match indicator P[47:0] with pattern
	    P             => w_dsp_s2_x_p); -- 48-bit output: Primary data output

    -- newY^2 = newY * newY
    w_dsp_s2_y_a <= "000000" & w_dsp_s1_p_newy;
    w_dsp_s2_y_b <= w_dsp_s1_p_newy(17 downto 0);
    w_dsp_s2_y_c <= x"000000000000";

    DSP48E1_stage2_y_inst : entity work.dsp48_wrap
	generic map (
	    PREG => 1,				        -- Pipeline stages for P (0 or 1)
	    USE_MULT => "MULTIPLY",
	    USE_DPORT => TRUE,
	    MASK => x"000000000000",		    -- 48-bit mask value for pattern detect
	    SEL_PATTERN => "PATTERN",			-- Select pattern value ("PATTERN" or "C")
	    USE_PATTERN_DETECT => "NO_PATDET",	-- ("PATDET" or "NO_PATDET")
	    USE_SIMD => "ONE48" )		        -- SIMD selection ("ONE48", "TWO24", "FOUR12")
	port map (
	    CLK       => i_aclk,            -- 1-bit input: Clock input
	    A         => w_dsp_s2_y_a,        -- newY
	    B         => w_dsp_s2_y_b,        -- newY
	    C         => w_dsp_s2_y_c,        -- 0
	    INMODE    => "00000",
	    OPMODE    => "0110101",          -- 7-bit input: Operation mode input
	    ALUMODE   => "0000", -- 7-bit input: Operation mode input
	    CARRYIN   => '0', -- 1-bit input: Carry input signal
	    CEC       => rs_axis_tvalid_shift(1),
	    CECARRYIN => rs_axis_tvalid_shift(1),
	    CECTRL    => rs_axis_tvalid_shift(1),
		CEM		  => rs_axis_tvalid_shift(1),  -- 1-bit input: CE input for Multiplier
	    CEP       => rs_axis_tvalid_shift(1),  -- 1-bit input: CE input for PREG
	    CEA1      => rs_axis_tvalid_shift(1),
	    -- Reset Signals
		RSTA          => w_dsp_reset,
		RSTB          => w_dsp_reset,
		RSTC          => w_dsp_reset,
		RSTD          => w_dsp_reset,
		RSTM          => w_dsp_reset,
		RSTP          => w_dsp_reset,
		RSTINMODE     => w_dsp_reset,
		RSTALUMODE    => w_dsp_reset,
		RSTCTRL       => w_dsp_reset,
		RSTALLCARRYIN => w_dsp_reset,
	    --
	    PATTERNDETECT => open,		  -- Match indicator P[47:0] with pattern
	    P             => w_dsp_s2_y_p); -- 48-bit output: Primary data output


    -- P = A:B + C
    -- P[47:0] = sum = newX + newY
    -- Stage three wires
    w_dsp_s3_ab <= x"000000" & w_dsp_s2_x_p(23 downto 0);
    w_dsp_s3_c  <= x"000000" & w_dsp_s2_y_p(23 downto 0);

    -- Stage three - Addition
    DSP48E1_stage3_inst : entity work.dsp48_wrap
    generic map (
        PREG => 1,				-- Pipeline stages for P (0 or 1)
        MASK => x"000000000000",		-- 48-bit mask value for pattern detect
        SEL_PATTERN => "C",			-- Select pattern value ("PATTERN" or "C")
        USE_PATTERN_DETECT => "PATDET",	-- ("PATDET" or "NO_PATDET")
        USE_SIMD => "ONE48" )		-- SIMD selection ("ONE48", "TWO24", "FOUR12")
    port map (
        CLK     => i_aclk,		      -- 1-bit input: Clock input
        A       => w_dsp_s3_a,		  -- newX
        B       => w_dsp_s3_b,	  	  -- 0
        C       => w_dsp_s3_c,		  -- newY
        OPMODE  => "0110011",			  -- 7-bit input: Operation mode input
        ALUMODE => "0000",	      -- 7-bit input: Operation mode input
        CARRYIN => '0',			      -- 1-bit input: Carry input signal
        CEP     => rs_axis_tvalid_shift(2),	      -- 1-bit input: CE input for PREG
        -- Reset Signals
        RSTA          => w_dsp_reset,
        RSTB          => w_dsp_reset,
        RSTC          => w_dsp_reset,
        RSTD          => w_dsp_reset,
        RSTM          => w_dsp_reset,
        RSTP          => w_dsp_reset,
        RSTINMODE     => w_dsp_reset,
        RSTALUMODE    => w_dsp_reset,
        RSTCTRL       => w_dsp_reset,
        --
        P => w_dsp_s3_p );			-- 48-bit output: Primary data output

-- LUT Theta
-- ru = (ru')^-2
-- rNorm = ru / i_src_radius
-- LUT: theta = atan(rNorm) / rNorm
    BRAM_LUT_THETA_inst : BRAM_TDP_MACRO
    generic map (
        BRAM_SIZE     => "36Kb",
        DEVICE        => "7SERIES",
        INIT_FILE     => C_INIT_THETA_FILE,
        READ_WIDTH_A  => 16,
        READ_WIDTH_B  => 16,
        WRITE_WIDTH_A => 16,
        WRITE_WIDTH_B => 16
    ) port map (
        -- Clock/Reset
        CLKA => i_aclk,
        RSTA => w_lut_reset,
        CLKB => i_aclk,
        RSTB => w_lut_reset,
        -- A port - Configuration
        DIA    => i_lut_theta_wdata,
        DOA    => o_lut_theta_rdata,
        ADDRA  => i_lut_theta_addr,
        REGCEA => '0',
        ENA    => i_lut_theta_enable,
        WEA    => "00",
        -- B port - Video In/Out
        DIB    => x"0000",
        DOB    => w_lut_b_theta_data,
        ADDRB  => w_dsp_s3_p(15 downto 5),
        REGCEB => '0',
        ENB    => rs_axis_tvalid_shift(3),
        WEB    => "00"
    );


    -- center_x + theta*newX
	-- Stage four - Multiplication, Subtraction = (Gain * Center pixel) - neighbouring pixels
    -- P[47:0] = center_x + (theta * newX)
	w_dsp_s4_x_a <= x"0" & "00" & r_dsp_s1_p_newx_ddd;
	w_dsp_s4_x_b <= "00" & w_lut_b_theta_data;
	--w_dsp_s3_x_b <= "00" & x"8000";
	w_dsp_s4_x_c <= x"00000" & "00" & i_center_x & x"000" & "000"; -- Two's compliment, sum of neighbouring pixels

    w_dsp_s4_x_alumode <= "0011" when r_pos_x_sign_shift(3) = '1' else "0000";
    w_dsp_s4_x_carryin <=    '1' when r_pos_x_sign_shift(3) = '1' else '0';

    DSP48E1_stage4_x_inst : entity work.dsp48_wrap
	generic map (
	    PREG => 1,				        -- Pipeline stages for P (0 or 1)
	    USE_MULT => "MULTIPLY",
	    USE_DPORT => TRUE,
	    MASK => x"000000000000",		    -- 48-bit mask value for pattern detect
	    SEL_PATTERN => "PATTERN",			-- Select pattern value ("PATTERN" or "C")
	    USE_PATTERN_DETECT => "NO_PATDET",	-- ("PATDET" or "NO_PATDET")
	    USE_SIMD => "ONE48" )		        -- SIMD selection ("ONE48", "TWO24", "FOUR12")
	port map (
	    CLK       => i_aclk,            -- 1-bit input: Clock input
	    A         => w_dsp_s4_x_a,        -- newX
	    B         => w_dsp_s4_x_b,        -- theta
	    C         => w_dsp_s4_x_c,        -- i_center_x
	    INMODE    => "00000",
	    OPMODE    => "0110101",          -- 7-bit input: Operation mode input
	    ALUMODE   => w_dsp_s4_x_alumode, -- 7-bit input: Operation mode input
	    CARRYIN   => w_dsp_s4_x_carryin, -- 1-bit input: Carry input signal
	    CEC       => rs_axis_tvalid_shift(4),
	    CECARRYIN => rs_axis_tvalid_shift(4),
	    CECTRL    => rs_axis_tvalid_shift(4),
		CEM		  => rs_axis_tvalid_shift(4),  -- 1-bit input: CE input for Multiplier
	    CEP       => rs_axis_tvalid_shift(4),  -- 1-bit input: CE input for PREG
	    CEA1      => rs_axis_tvalid_shift(4),
	    -- Reset Signals
		RSTA          => w_dsp_reset,
		RSTB          => w_dsp_reset,
		RSTC          => w_dsp_reset,
		RSTD          => w_dsp_reset,
		RSTM          => w_dsp_reset,
		RSTP          => w_dsp_reset,
		RSTINMODE     => w_dsp_reset,
		RSTALUMODE    => w_dsp_reset,
		RSTCTRL       => w_dsp_reset,
		RSTALLCARRYIN => w_dsp_reset,
	    --
	    PATTERNDETECT => open,		  -- Match indicator P[47:0] with pattern
	    P             => w_dsp_s4_x_p); -- 48-bit output: Primary data output

    -- center_y + theta*newY
    -- P[47:0] = center_y + (theta * newY)
	w_dsp_s4_y_a <= x"0" & "00" & r_dsp_s1_p_newy_ddd;
	w_dsp_s4_y_b <= "00" & w_lut_b_theta_data;
	--w_dsp_s3_y_b <= "00" & x"8000";
	w_dsp_s4_y_c <= x"00000" & "00" & i_center_y & x"000" & "000"; -- Two's compliment, sum of neighbouring pixels

    w_dsp_s4_y_alumode <= "0011" when r_pos_y_sign_shift(2) = '1' else "0000";
    w_dsp_s4_y_carryin <=    '1' when r_pos_y_sign_shift(2) = '1' else '0';

    DSP48E1_stage4_y_inst : entity work.dsp48_wrap
	generic map (
	    PREG => 1,				        -- Pipeline stages for P (0 or 1)
	    USE_MULT => "MULTIPLY",
	    USE_DPORT => TRUE,
	    MASK => x"000000000000",		    -- 48-bit mask value for pattern detect
	    SEL_PATTERN => "PATTERN",			-- Select pattern value ("PATTERN" or "C")
	    USE_PATTERN_DETECT => "NO_PATDET",	-- ("PATDET" or "NO_PATDET")
	    USE_SIMD => "ONE48" )		        -- SIMD selection ("ONE48", "TWO24", "FOUR12")
	port map (
	    CLK       => i_aclk,              -- 1-bit input: Clock input
	    A         => w_dsp_s4_y_a,        -- M11
	    B         => w_dsp_s4_y_b,        -- Gain
	    C         => w_dsp_s4_y_c,        -- S3_0
	    INMODE    => "00000",
	    OPMODE    => "0110101",          -- 7-bit input: Operation mode input
	    ALUMODE   => w_dsp_s4_y_alumode, -- 7-bit input: Operation mode input
	    CARRYIN   => w_dsp_s4_y_carryin, -- 1-bit input: Carry input signal
	    CEC       => rs_axis_tvalid_shift(4),
	    CECARRYIN => rs_axis_tvalid_shift(4),
	    CECTRL    => rs_axis_tvalid_shift(4),
		CEM		  => rs_axis_tvalid_shift(4),  -- 1-bit input: CE input for Multiplier
	    CEP       => rs_axis_tvalid_shift(4),  -- 1-bit input: CE input for PREG
	    CEA1      => rs_axis_tvalid_shift(4),
	    -- Reset Signals
		RSTA          => w_dsp_reset,
		RSTB          => w_dsp_reset,
		RSTC          => w_dsp_reset,
		RSTD          => w_dsp_reset,
		RSTM          => w_dsp_reset,
		RSTP          => w_dsp_reset,
		RSTINMODE     => w_dsp_reset,
		RSTALUMODE    => w_dsp_reset,
		RSTCTRL       => w_dsp_reset,
		RSTALLCARRYIN => w_dsp_reset,
	    --
	    PATTERNDETECT => open,		  -- Match indicator P[47:0] with pattern
	    P             => w_dsp_s4_y_p); -- 48-bit output: Primary data output

end rtl;

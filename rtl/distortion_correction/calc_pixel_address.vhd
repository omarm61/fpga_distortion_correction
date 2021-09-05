library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity calc_pixel_address is
    generic (
        C_INIT_X_FILE : string := "NONE";
        C_INIT_Y_FILE : string := "NONE"
    );
    port (
        -- Clock/Reset
        i_aclk    : in std_logic;
        i_aresetn : in std_logic;
        -- Configure
        i_line_length : in std_logic_vector (15 downto 0);
        -- X/Y pixel location
        s_src_pos_tdata     : in  std_logic_vector (21 downto 0);
        s_src_pos_tvalid    : in  std_logic;
        s_src_pos_tready    : out std_logic;
        s_src_pos_tuser_sof : in  std_logic;
        s_src_pos_tlast     : in  std_logic;
        -- Memory address
        m_mem_addr_tdata     : out std_logic_vector (31 downto 0);
        m_mem_addr_tvalid    : out std_logic;
        m_mem_addr_tready    : in  std_logic;
        m_mem_addr_tuser_sof : out std_logic;
        m_mem_addr_tlast     : out std_logic
    );
end calc_pixel_address;

architecture rtl of calc_pixel_address is

    -- DSP Chip enable and reset
    signal w_dsp_reset : std_logic;
    signal w_dsp_cen   : std_logic;

	-- DSP: P = (B*A) + C
	signal w_dsp_a : std_logic_vector (29 downto 0); -- In
	signal w_dsp_b : std_logic_vector (17 downto 0); -- In
	signal w_dsp_c : std_logic_vector (47 downto 0); -- In
	--
	signal w_dsp_p      : std_logic_vector (47 downto 0); -- Out
	--

    -- Delay
    signal r_src_pos_tvalid_d    : std_logic;
    signal r_src_pos_tuser_sof_d : std_logic;
    signal r_src_pos_tlast_d     : std_logic;

begin

    -- DSP reset and enable
    w_dsp_reset <= not i_aresetn;
    w_dsp_cen   <= s_src_pos_tvalid;
    -- DSP Input
    w_dsp_a <= "000" & x"0000" & s_src_tdata(21 downto 11);
    w_dsp_b <= "00" & i_line_length;
    w_dsp_c <= s_src_tdata(10 downto 0);

    -- AXI-Stream out
    s_src_pos_tready  <= m_mem_addr_tready;
    --
    m_mem_addr_tdata     <= w_dsp_p(31 donwto 0);
    m_mem_addr_tvalid    <= r_src_pos_tvalid_d;
    m_mem_addr_tuser_sof <= r_src_pos_tuser_sof_d;
    m_mem_addr_tlast     <= r_src_pos_tlast_d;

    -- 1cc
    proc_delay: process(i_aclk, i_aresetn)
    begin
        if (i_aresetn = '0') then
            r_src_pos_tvalid_d    <= '0';
            r_src_pos_tuser_sof_d <= '0';
            r_src_pos_tlast_d     <= '0';
        elsif (i_aclk'event and (i_aclk = '1')) then
            r_src_pos_tvalid_d    <= s_src_pos_tvalid;
            r_src_pos_tuser_sof_d <= s_src_pos_tuser_sof;
            r_src_pos_tlast_d     <= s_src_pos_tlast;
        end if;
    end process;

    -- Stage four - Multiplication, Subtraction = (Gain * Center pixel) - neighbouring pixels
    -- P[47:0] = X + (Y * line_length)
    DSP48E1_stage4_inst : entity work.dsp48_wrap
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
        A         => w_dsp_a,        -- M11
        B         => w_dsp_b,        -- Gain
        C         => w_dsp_c,        -- S3_0
        INMODE    => "00000",
        OPMODE    => "0110101",         -- 7-bit input: Operation mode input
        ALUMODE   => "0000",			-- 7-bit input: Operation mode input --
        CARRYIN   => '0',			    -- 1-bit input: Carry input signal
        CEC       => w_dsp_cen,
        CECARRYIN => w_dsp_cen,
        CECTRL    => w_dsp_cen,
        CEM		  => w_dsp_cen,  -- 1-bit input: CE input for Multiplier
        CEP       => w_dsp_cen,  -- 1-bit input: CE input for PREG
        CEA1      => w_dsp_cen,
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
        P             => w_dsp_p); -- 48-bit output: Primary data output

end rtl;

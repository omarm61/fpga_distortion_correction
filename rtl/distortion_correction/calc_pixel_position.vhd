library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unimacro;
use unimacro.VCOMPONENTS.all;

entity calc_pixel_position is
    generic (
        C_INIT_X_FILE : string := "NONE";
        C_INIT_Y_FILE : string := "NONE"
    );
    port (
        -- Clock/Reset
        i_aclk    : in std_logic;
        i_aresetn : in std_logic;
        -- LUT X Configure
        i_lut_x_wdata      : in  std_logic_vector (10 downto 0);
        o_lut_x_rdata      : out std_logic_vector (10 downto 0);
        i_lut_x_addr       : in  std_logic_vector (10 downto 0);
        i_lut_x_enable     : in  std_logic;
        i_lut_x_wren       : in  std_logic;
        -- LUT Y Configure
        i_lut_y_wdata      : in  std_logic_vector (10 downto 0);
        o_lut_y_rdata      : out std_logic_vector (10 downto 0);
        i_lut_y_addr       : in  std_logic_vector (10 downto 0);
        i_lut_y_enable     : in  std_logic;
        i_lut_y_wren       : in  std_logic;
        -- Destination Positon -- Pixel location in corrected image
        s_dst_pos_tdata     : in  std_logic_vector (21 downto 0);
        s_dst_pos_tvalid    : in  std_logic;
        s_dst_pos_tready    : out std_logic;
        s_dst_pos_tuser_sof : in  std_logic;
        s_dst_pos_tlast     : in  std_logic;
        -- Source Position -- Pixel Location in raw image
        m_src_pos_tdata     : out std_logic_vector (21 downto 0);
        m_src_pos_tvalid    : out std_logic;
        m_src_pos_tready    : in  std_logic;
        m_src_pos_tuser_sof : out std_logic;
        m_src_pos_tlast     : out std_logic
    );
end calc_pixel_position;

architecture rtl of calc_pixel_position is

    -- Resets
    signal w_dsp_reset : std_logic;
    signal w_lut_reset : std_logic;
    --
    signal w_lut_b_x_data        : std_logic_vector(10 downto 0);
    signal w_lut_b_y_data        : std_logic_vector(10 downto 0);
    signal r_dst_pos_tvalid_d    : std_logic;
    signal r_dst_pos_tuser_sof_d : std_logic;
    signal r_dst_pos_tlast_d     : std_logic;

    --Input position
    signal w_lut_b_x_addr   : std_logic_vector(15 downto 0);
    signal w_dst_pos_y_data : std_logic_vector(15 downto 0);

    -- DSP48 Stage 1
    --signal w_dsp_s1_ab : std_logic_vector (47 downto 0);
    --alias  w_dsp_s1_a  : std_logic_vector (29 downto 0) is w_dsp_s1_ab (47 downto 18);
    --alias  w_dsp_s1_b  : std_logic_vector (17 downto 0) is w_dsp_s1_ab (47 downto 18);
    ----
    --signal w_dsp_s1_c  : std_logic_vector (47 downto 0);
    ----
    --signal w_dsp_s1_p      : std_logic_vector (47 downto 0);
    --alias  w_dsp_s1_p_newy : std_logic_vector (23 downto 0) is w_dsp_s1_p(47 downto 24);
    --alias  w_dsp_s1_p_newx : std_logic_vector (23 downto 0) is w_dsp_s1_p(23 downto 0);
    ----
    --signal w_dsp_s1_carryout : std_logic_vector (3 downto 0);

    ---- DSP48 Stage 2
    --signal w_dsp_s2_ab : std_logic_vector (47 downto 0);
    --alias  w_dsp_s2_a  : std_logic_vector (29 downto 0) is w_dsp_s1_ab (47 downto 18);
    --alias  w_dsp_s2_b  : std_logic_vector (17 downto 0) is w_dsp_s1_ab (47 downto 18);
    ----
    --signal w_dsp_s2_c  : std_logic_vector (47 downto 0);
    ----
    --signal w_dsp_s2_p      : std_logic_vector (47 downto 0); -- ru

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

    --
    w_lut_b_x_addr  <= s_dst_pos_tdata(10 downto 0);
    w_lut_b_y_addr  <= s_dst_pos_tdata(21 downto 11);
    w_lut_b_valid   <= s_axis_tvalid;
    s_axis_tready   <= m_axis_tready;

    --
    m_src_pos_tdata     <= w_lut_b_y_data & w_lut_b_x_data;
    m_src_pos_tvalid    <= r_dst_pos_tvalid_d;
    m_src_pos_tuser_sof <= r_dst_pos_tuser_sof_d;
    m_src_pos_tlast     <= r_dst_pos_tlast_d;

    -- 1cc delay
    delay_proc: process(i_aclk, i_aresetn)
    begin
        if (i_aresetn = '0') then
            r_dst_pos_tvalid_d    <= '0';
            r_dst_pos_tuser_sof_d <= '0';
            r_dst_pos_tlast_d     <= '0';
        elsif (i_aclk'event and (i_aclk = '1')) then
            r_dst_pos_tvalid_d    <= s_dst_pos_tvalid;
            r_dst_pos_tuser_sof_d <= s_dst_pos_tuser_sof;
            r_dst_post_tlast_d    <= s_dst_pos_tlast;
        end if;
    end process;



    -- LUT Theta
    -- ru = (ru')^-2
    -- rNorm = ru / i_src_radius
    -- LUT: theta = atan(rNorm) / rNorm
    BRAM_LUT_x_inst : BRAM_TDP_MACRO
    generic map (
        BRAM_SIZE     => "36Kb",
        DEVICE        => "7SERIES",
        INIT_FILE     => C_INIT_X_FILE,
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
        DIA    => i_lut_x_wdata,
        DOA    => o_lut_x_rdata,
        ADDRA  => i_lut_x_addr,
        REGCEA => '0',
        ENA    => i_lut_x_enable,
        WEA    => i_lut_x_wren,
        -- B port - Video In/Out
        DIB    => x"00",
        DOB    => w_lut_b_x_data,
        ADDRB  => w_lut_b_x_addr,
        REGCEB => '0',
        ENB    => w_lut_b_valid,
        WEB    => "0"
    );

    -- LUT Theta
    -- ru = (ru')^-2
    -- rNorm = ru / i_src_radius
    -- LUT: theta = atan(rNorm) / rNorm
    BRAM_LUT_y_inst : BRAM_TDP_MACRO
    generic map (
        BRAM_SIZE     => "36Kb",
        DEVICE        => "7SERIES",
        INIT_FILE     => C_INIT_Y_FILE,
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
        DIA    => i_lut_y_wdata,
        DOA    => o_lut_y_rdata,
        ADDRA  => i_lut_y_addr,
        REGCEA => '0',
        ENA    => i_lut_y_enable,
        WEA    => i_lut_y_wren,
        -- B port - Video In/Out
        DIB    => x"00",
        DOB    => w_lut_b_y_data,
        ADDRB  => w_lut_b_y_addr,
        REGCEB => '0',
        ENB    => w_lut_b_valid,
        WEB    => "0"
    );


end rtl;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity dist_correction is
    generic (
        C_IMAGE_WIDTH  : integer := 362,
        C_IMAGE_HEIGHT : integer := 200
    );
    port (
        -- Clock/Reset
        i_aclk           : in std_logic;
        i_aresetn        : in std_logic;
        -- Configuration
        i_strength       : in std_logic_vector (15 downto 0); -- distortion strength
        i_src_radius     : in std_logic_vector (15 downto 0); -- Source Radius
        i_bypass         : in std_logic;
        -- LUT Configure
        i_lut_wdata      : in std_logic_vector (15 downto 0);
        i_lut_rdata      : in std_logic_vector (15 downto 0);
        i_lut_enable     : in std_logic;
        i_lut_wen        : in std_logic;
        -- Memory Interface - Image In
        i_pxl_data       : in std_logic_vector (7 downto 0);
        i_pxl_addr       : in std_logic_vector (15 downto 0);
        i_pxl_rden       : in std_logic;
        -- AXI Stream - Image Out corrected
    	m_axis_tdata     : out std_Logic_vector (15 downto 0);
    	m_axis_tvalid    : out std_logic;
    	m_axis_tready    : in  std_Logic;
    	m_axis_tuser_sof : out std_Logic;
    	m_axis_tlast     : out std_logic
);
end dist_correction;

architecture rtl of dist_correction is


    -- Destination Image positon
    signal r_dst_pos_tdata     : std_logic_vector (15 downto 0); -- pixel address
    signal r_dst_pos_tvalid    : std_logic;
    signal w_dst_pos_tready    : std_logic;
    signal r_dst_pos_tuser_sof : std_logic;
    signal r_dst_pos_tlast     : std_logic;

    -- Source Image positon
    signal r_dst_pos_tdata     : std_logic_vector (15 downto 0); -- pixel address
    signal r_dst_pos_tvalid    : std_logic;
    signal w_dst_pos_tready    : std_logic;
    signal r_dst_pos_tuser_sof : std_logic;
    signal r_dst_pos_tlast     : std_logic;

begin

    calc_pixel_position_inst : calc_pixel_position
    generic map (
        C_IMAGE_WIDTH => C_IMAGE_WIDTH,
        C_IMAGE_HEIGHT => C_IMAGE_HEIGHT
    ) port map (
        -- Clock/Reset
        i_aclk => i_aclk,
        i_aresetn => i_aresetn,
        -- Configuration
        i_strength => i_strength
        -- Destination Positon
        m_dst_pos_tdata     => r_dst_pos_tdata,
        m_dst_pos_tvalid    => r_dst_pos_tvalid,
        m_dst_pos_tready    => w_dst_pos_tready,
        m_dst_pos_tuser_sof => r_dst_pos_tuser_sof,
        m_dst_pos_tlast     => r_dst_pos_tlast,
        -- Source Position
        s_src_pos_tdata     => w_dst_pos_tdata,
        s_src_pos_tvalid    => w_dst_pos_tvalid,
        s_src_pos_tready    => r_dst_pos_tready,
        s_src_pos_tuser_sof => w_dst_pos_tuser_sof,
        s_src_pos_tlast     => w_dst_pos_tlast
    );

end rtl;

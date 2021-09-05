library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity dist_correction is
    generic (
        C_IMAGE_WIDTH    : integer := 362;
        C_IMAGE_HEIGHT   : integer := 200;
        C_INIT_X_FILE    : string  := "NONE";
        C_INIT_Y_FILE    : string  := "NONE"
    );
    port (
        -- Clock/Reset
        i_aclk           : in  std_logic;
        i_aresetn        : in  std_logic;
        -- LUT X Configure
        i_lut_x_wdata    : in  std_logic_vector (10 downto 0);
        o_lut_x_rdata    : out std_logic_vector (10 downto 0);
        i_lut_x_addr     : in  std_logic_vector (10 downto 0);
        i_lut_x_enable   : in  std_logic;
        i_lut_x_wren     : in  std_logic;
        -- LUT Y Configure
        i_lut_y_wdata    : in  std_logic_vector (10 downto 0);
        o_lut_y_rdata    : out std_logic_vector (10 downto 0);
        i_lut_y_addr     : in  std_logic_vector (10 downto 0);
        i_lut_y_enable   : in  std_logic;
        i_lut_y_wren     : in  std_logic;
        -- Memory Interface - Image In
        i_mem_rdata       : in  std_logic_vector (7 downto 0);
        o_mem_addr       : out std_logic_vector (15 downto 0);
        o_mem_rden       : out std_logic;
        -- AXI Stream - Image Out corrected
    	m_axis_tdata     : out std_Logic_vector (15 downto 0);
    	m_axis_tvalid    : out std_logic;
    	m_axis_tready    : in  std_Logic;
    	m_axis_tuser_sof : out std_Logic;
    	m_axis_tlast     : out std_logic
);
end dist_correction;

architecture rtl of dist_correction is

    -- Counters
    r_pixel_counter_x  : std_logic_vector (15 downto 0);
    r_pixel_counter_y  : std_logic_vector (15 downto 0);

    -- Destination Image positon
    signal w_dst_pos_tdata     : std_logic_vector (21 downto 0); -- X position in corrected image
    signal r_dst_pos_tvalid    : std_logic;
    signal w_dst_pos_tready    : std_logic;
    signal r_dst_pos_tuser_sof : std_logic;
    signal r_dst_pos_tlast     : std_logic;

    -- Source Image positon
    signal w_src_pos_tdata     : std_logic_vector (21 downto 0); -- pixel address
    signal w_src_pos_tvalid    : std_logic;
    signal w_src_pos_tready    : std_logic;
    signal w_src_pos_tuser_sof : std_logic;
    signal w_src_pos_tlast     : std_logic;

    -- Memory address
    signal w_mem_addr_tdata     : std_logic_vector (31 downto 0); -- pixel address
    signal w_mem_addr_tvalid    : std_logic;
    signal r_mem_addr_tready    : std_logic;
    signal w_mem_addr_tuser_sof : std_logic;
    signal w_mem_addr_tlast     : std_logic;

    -- AXI-Stream out
    signal r_axis_tdata     : std_logic_vector (15 downto 0);
    signal r_axis_tvalid    : std_logic;
    signal r_axis_tlast     : std_logic;
    signal r_axis_tuser_sof : std_logic;
    --
    signal r_pixel_valid : std_logic;
    signal r_pixel_last  : std_logic;
    signal r_pixel_sof   : std_logic;

begin

    -- Memory interface
    o_mem_addr <= w_mem_addr_tdata(15 downto 0);
    o_mem_rden <= w_mem_addr_tvalid;

    -- AXI-Stream out
    m_axis_tdata     <= r_axis_tdata;
    m_axis_tvalid    <= r_axis_tvalid;
    m_axis_tlast     <= r_axis_tlast;
    m_axis_tuser_sof <= r_axis_tuser_sof;


    w_dst_pos_tdata <= r_pixel_counter_y & r_pixel_counter_x;
    -- HACK: This is only a counter
    proc_ctrl: process(i_aclk, i_aresetn)
    begin
        if (i_aresetn = '0') then
            r_dst_pos_tdata     <= (others => '0');
            r_dst_pos_tvalid    <= '0';
            r_dst_pos_tuser_sof <= '0';
            r_dst_pos_tlast     <= '0';
            r_pixel_counter_x   <= (others => '0');
            r_pixel_counter_y   <= (others => '0');
        elsif (i_aclk'event and (i_aclk = '1')) then
            if (w_dst_pos_tready = '1') then
                r_dst_pos_tvalid <= '1';
                if (r_pixel_counter_x = C_IMAGE_WIDTH - 1) then
                    -- Reset counter
                    r_pixel_counter_x <= (others => '0');
                    -- set last pixel flag
                    r_dst_pos_tlast <= '1';
                    -- Increment line counter
                    if (r_pixel_counter_y = C_IMAGE_HEIGHT - 1) then
                        -- Reset Coutner
                        r_pixel_counter_y <= (others => '0');
                    -- End of Frame
                    else
                        r_pixel_counter_y <= r_pixel_counter_y + 1;
                    end if;
                else
                    -- Increment pixel counter
                    r_pixel_counter_x <= r_pixel_counter_x + 1;
                end if;
            else
                r_dst_pos_tvalid <= '0';
            end if;
        end if;
    end process;

    proc_stream: process(i_acVlk, i_aresetn)
    begin
        if (i_aresetn = '0') then
            r_axis_tdata     <= (others => '0');
            r_axis_tvalid    <= '0';
            r_axis_tlast     <= '0';
            r_axis_tuser_sof <= '0';
            r_pixel_valid    <= '0';
            r_pixel_last     <= '0';
            r_pixel_sof      <= '0';
        elsif (i_aclk'event and (i_aclk = '1')) then
            -- Wait for valid data from memory
            r_pixel_valid <= w_mem_addr_tvalid;
            r_pixel_last  <= w_mem_addr_tlast;
            r_pixel_sof   <= w_mem_addr_tuser_sof;
            -- Valid data out
            if (r_pixel_valid = '1') then
                r_axis_tdata     <= x"80" & i_mem_rdata;
                r_axis_tvalid    <= '1';
                r_axis_tlast     <= r_pixel_last;
                r_axis_tuser_sof <= r_pixel_sof;
            else
                r_axis_tvalid <= '0';
            end if;
        end if;
    end process;

    -- Latency: 8cc
    calc_pixel_position_inst : calc_pixel_position
    generic map (
        C_INIT_X_FILE => C_INIT_X_FILE,
        C_INIT_Y_FILE => C_INIT_Y_FILE
    ) port map (
        -- Clock/Reset
        i_aclk      => i_aclk,
        i_aresetn   => i_aresetn,
        -- LUT X Configure
        i_lut_x_wdata      => i_lut_x_wdata,
        o_lut_x_rdata      => o_lut_x_rdata,
        i_lut_x_addr       => i_lut_x_addr,
        i_lut_x_enable     => i_lut_x_enable,
        i_lut_x_wren       => i_lut_x_wren,
        -- LUT Y Configure
        i_lut_y_wdata      => i_lut_y_wdata,
        o_lut_y_rdata      => o_lut_y_rdata,
        i_lut_y_addr       => i_lut_y_addr,
        i_lut_y_enable     => i_lut_y_enable,
        i_lut_y_wren       => i_lut_y_wren,
        -- Destination Positon -- Pixel location in corrected image
        s_dst_pos_tdata     => w_dst_pos_tdata,
        s_dst_pos_tvalid    => r_dst_pos_tvalid,
        s_dst_pos_tready    => w_dst_pos_tready,
        s_dst_pos_tuser_sof => r_dst_pos_tuser_sof,
        s_dst_pos_tlast     => r_dst_pos_tlast,
        -- Source Position -- Pixel Location in raw image
        m_src_pos_tdata     => w_src_pos_tdata,
        m_src_pos_tvalid    => w_src_pos_tvalid,
        m_src_pos_tready    => w_src_pos_tready,
        m_src_pos_tuser_sof => w_src_pos_tuser_sof,
        m_src_pos_tlast     => w_src_pos_tlast
    );

    -- Latency: 4cc
    calc_pixel_address_inst : calc_pixel_address
    generic map (
        C_IIMAGE_WIDTH => C_IMAGE_WIDTH,
        C_IMAGE_HEIGHT => C_IMAGE_HEIGHT
    ) port map (
        -- Clock/Reset
        i_aclk    => i_aclk,
        i_aresetn => i_aresetn,
        -- X/Y pixel location
        s_src_pos_tdata     => w_src_pos_tdata,
        s_src_pos_tvalid    => w_src_pos_tvalid,
        s_src_pos_tready    => w_src_pos_tready,
        s_src_pos_tuser_sof => w_src_pos_tuser_sof,
        s_src_pos_tlast     => w_src_pos_tlast,
        -- Memory address
        m_mem_addr_tdata     => w_mem_addr_tdata,
        m_mem_addr_tvalid    => w_mem_addr_tvalid,
        m_mem_addr_tready    => r_mem_addr_tready,
        m_mem_addr_tuser_sof => w_mem_addr_tuser_sof,
        m_mem_addr_tlast     => w_mem_addr_tlast
    );

end rtl;

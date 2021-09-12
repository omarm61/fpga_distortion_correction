library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity dist_correction is
    generic (
        C_IMAGE_WIDTH     : integer := 362;
        C_IMAGE_HEIGHT    : integer := 200;
        C_INIT_THETA_FILE : string  := "NONE"
    );
    port (
        -- Clock/Reset
        i_aclk             : in  std_logic;
        i_aresetn          : in  std_logic;
        -- Configure
        i_enable_correction : in std_logic;
        i_line_length       : in std_logic_vector (15 downto 0);
        i_center_x          : in std_logic_vector (10 downto 0);
        i_center_y          : in std_logic_vector (10 downto 0);
        -- LUT X Configure
        i_lut_theta_wdata  : in  std_logic_vector (15 downto 0);
        o_lut_theta_rdata  : out std_logic_vector (15 downto 0);
        i_lut_theta_addr   : in  std_logic_vector (10 downto 0);
        i_lut_theta_enable : in  std_logic;
        i_lut_theta_wren   : in  std_logic;
        -- Memory Interface - Image In
        i_mem_rdata        : in  std_logic_vector (7 downto 0);
        o_mem_addr         : out std_logic_vector (15 downto 0);
        o_mem_rden         : out std_logic;
        i_mem_valid        : in  std_logic;
        -- AXI Stream - Image Out corrected
    	m_axis_tdata       : out std_Logic_vector (15 downto 0);
    	m_axis_tvalid      : out std_logic;
    	m_axis_tready      : in  std_Logic;
    	m_axis_tuser_sof   : out std_Logic;
    	m_axis_tlast       : out std_logic
);
end dist_correction;

architecture rtl of dist_correction is

    -- Control State Machine
    type t_control_state is (sIDLE, sSOF, sFRAME, sDONE);
    signal r_control_fsm : t_control_state;

    -- Counters
    signal r_pixel_counter_x  : std_logic_vector (10 downto 0);
    signal r_pixel_counter_y  : std_logic_vector (10 downto 0);

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
    signal w_mem_addr_tready    : std_logic;
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

    -- Components
    component calc_pixel_position is
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
            i_lut_theta_wdata      : in  std_logic_vector (15 downto 0);
            o_lut_theta_rdata      : out std_logic_vector (15 downto 0);
            i_lut_theta_addr       : in  std_logic_vector (10 downto 0);
            i_lut_theta_enable     : in  std_logic;
            i_lut_theta_wren       : in  std_logic;
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
    end component;

    component calc_pixel_address is
        port (
            -- Clock/Reset
            i_aclk    : in std_logic;
            i_aresetn : in std_logic;
            -- Configure
            i_line_length : in std_logic_vector (15 downto 0);
            -- X/Y pixel location
            s_axis_tdata     : in  std_logic_vector (21 downto 0);
            s_axis_tvalid    : in  std_logic;
            s_axis_tready    : out std_logic;
            s_axis_tuser_sof : in  std_logic;
            s_axis_tlast     : in  std_logic;
            -- Memory address
            m_axis_tdata     : out std_logic_vector (31 downto 0);
            m_axis_tvalid    : out std_logic;
            m_axis_tready    : in  std_logic;
            m_axis_tuser_sof : out std_logic;
            m_axis_tlast     : out std_logic
        );
    end component;

begin

    -- Memory interface
    o_mem_addr <= w_mem_addr_tdata(15 downto 0);
    o_mem_rden <= w_mem_addr_tvalid;

    -- AXI-Stream out
    w_mem_addr_tready<= m_axis_tready;
    m_axis_tdata     <= r_axis_tdata;
    m_axis_tvalid    <= r_axis_tvalid;
    m_axis_tlast     <= r_axis_tlast;
    m_axis_tuser_sof <= r_axis_tuser_sof;


    w_dst_pos_tdata <= r_pixel_counter_y & r_pixel_counter_x;
    -- HACK: This is only a counter
    proc_ctrl: process(i_aclk, i_aresetn)
    begin
        if (i_aresetn = '0') then
            r_dst_pos_tvalid    <= '0';
            r_dst_pos_tuser_sof <= '0';
            r_dst_pos_tlast     <= '0';
            r_pixel_counter_x   <= (others => '0');
            r_pixel_counter_y   <= (others => '0');
            r_control_fsm <= sIDLE;
        elsif (i_aclk'event and (i_aclk = '1')) then
            case (r_control_fsm) is
                when sIDLE =>
                    -- Wait for ready signal
                    if (w_dst_pos_tready = '1') then
                        -- Reset counters
                        r_pixel_counter_x <= (others => '0');
                        r_pixel_counter_y <= (others => '0');
                        r_dst_pos_tvalid    <= '0';
                        r_dst_pos_tuser_sof <= '0';
                        r_dst_pos_tlast     <= '0';
                        -- NOTE: Single shot mode
                        -- Wait for enable Signal
                        if (i_enable_correction = '1') then
                            -- Next State, start of frame
                            r_control_fsm <= sSOF;
                        end if;
                    end if;
                when sSOF =>
                    if (w_dst_pos_tready = '1') then
                        -- First Pixel
                        r_pixel_counter_x <= (others => '0');
                        r_pixel_counter_y <= (others => '0');
                        -- Set start of frame signal
                        r_dst_pos_tuser_sof <= '1';
                        -- Set valid flag
                        r_dst_pos_tvalid <= '1';
                        -- Next state
                        r_control_fsm <= sFRAME;
                    end if;
                when sFRAME =>
                    if (w_dst_pos_tready = '1') then
                        -- Reset start of frame signal
                        r_dst_pos_tuser_sof <= '0';
                        -- Set valid flag
                        r_dst_pos_tvalid <= '1';
                        -- Increment Pixel counter
                        if (r_dst_pos_tvalid = '1') then
                            if (r_pixel_counter_x = std_logic_vector(to_unsigned(C_IMAGE_WIDTH - 1, r_pixel_counter_x'length))) then
                                -- Reset counter
                                r_pixel_counter_x <= (others => '0');
                                r_dst_pos_tlast <= '0';
                                -- Increment line counter
                                if (r_pixel_counter_y = std_logic_vector(to_unsigned(C_IMAGE_HEIGHT - 1, r_pixel_counter_y'length))) then
                                    -- End of Frame
                                    r_control_fsm <= sDONE;
                                else
                                    r_pixel_counter_y <= r_pixel_counter_y + 1;
                                end if;
                            else
                                -- Reset end of line signal
                                r_dst_pos_tlast <= '0';
                                -- Increment pixel counter
                                r_pixel_counter_x <= r_pixel_counter_x + 1;
                                -- Mark last pixel
                                if (r_pixel_counter_x = C_IMAGE_WIDTH - 2) then
                                    r_dst_pos_tlast <= '1';
                                else
                                    r_dst_pos_tlast <= '0';
                                end if;
                            end if;
                        end if;
                    end if;
                when sDONE =>
                    if (w_dst_pos_tready = '1') then
                        r_dst_pos_tvalid <= '0';
                        r_control_fsm <= sIDLE;
                        assert false report "dist_correction: Frame done" severity note;
                    end if;
                when others =>
                    -- Return to IDLE state
                    r_control_fsm <= sIDLE;
                    assert false report "dist_correction: Invalid State" severity error;
            end case;
        end if;
    end process;

    proc_stream: process(i_aclk, i_aresetn)
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
            if (i_mem_valid = '1') then
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
        C_INIT_THETA_FILE => C_INIT_THETA_FILE
    ) port map (
        -- Clock/Reset
        i_aclk      => i_aclk,
        i_aresetn   => i_aresetn,
        -- Configuration
        i_center_x  => i_center_x,
        i_center_y  => i_center_y,
        -- LUT X Configure
        i_lut_theta_wdata   => i_lut_theta_wdata,
        o_lut_theta_rdata   => o_lut_theta_rdata,
        i_lut_theta_addr    => i_lut_theta_addr,
        i_lut_theta_enable  => i_lut_theta_enable,
        i_lut_theta_wren    => i_lut_theta_wren,
        -- Destination Positon -- Pixel location in corrected image
        s_axis_tdata     => w_dst_pos_tdata,
        s_axis_tvalid    => r_dst_pos_tvalid,
        s_axis_tready    => w_dst_pos_tready,
        s_axis_tuser_sof => r_dst_pos_tuser_sof,
        s_axis_tlast     => r_dst_pos_tlast,
        -- Source Position -- Pixel Location in raw image
        m_axis_tdata     => w_src_pos_tdata,
        m_axis_tvalid    => w_src_pos_tvalid,
        m_axis_tready    => w_src_pos_tready,
        m_axis_tuser_sof => w_src_pos_tuser_sof,
        m_axis_tlast     => w_src_pos_tlast
    );

    -- Latency: 4cc
    calc_pixel_address_inst : calc_pixel_address
    port map (
        -- Clock/Reset
        i_aclk    => i_aclk,
        i_aresetn => i_aresetn,
        -- Configure
        i_line_length => i_line_length,
        -- X/Y pixel location
        s_axis_tdata     => w_src_pos_tdata,
        s_axis_tvalid    => w_src_pos_tvalid,
        s_axis_tready    => w_src_pos_tready,
        s_axis_tuser_sof => w_src_pos_tuser_sof,
        s_axis_tlast     => w_src_pos_tlast,
        -- Memory address
        m_axis_tdata     => w_mem_addr_tdata,
        m_axis_tvalid    => w_mem_addr_tvalid,
        m_axis_tready    => w_mem_addr_tready,
        m_axis_tuser_sof => w_mem_addr_tuser_sof,
        m_axis_tlast     => w_mem_addr_tlast
    );

end rtl;

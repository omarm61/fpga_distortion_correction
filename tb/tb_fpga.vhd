library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_fpga is
    port (
           i_sim_clk     : in std_logic;
		   i_sim_aresetn : in std_logic
       );
end;

architecture tb of tb_fpga is

    -- Constants
    constant C_COUNTER_SIZE   : integer := 8;
    -- Image Dimension
    constant C_IMAGE_WIDTH  : integer := 326;
    constant C_IMAGE_HEIGHT : integer := 200;

    -- Files
    -- input
    constant C_CORR_LUT_X_FILE : string := "corr_lut_x.mif";
    constant C_CORR_LUT_X_FILE : string := "corr_lut_y.mif";
    -- output
    constant C_VIDEO_OUT_FILE : string := "video_out_sim.txt";

    -- Signals
    signal enable : std_logic;

    -- AXI-Stream

    -- Distortion correction -> SIM Output File
    signal w_axis_dist_sim_tdata     : std_logic_vector (15 downto 0);
    signal w_axis_dist_sim_tvalid    : std_logic;
    signal r_axis_dist_sim_tready    : std_logic;
    signal w_axis_dist_sim_tuser_sof : std_logic;
    signal w_axis_dist_sim_tlast     : std_logic;

    -- Control Registers (NOTE: Currently these registers are controlled by the TCL script)
    signal r_reg_center_x   : std_logic_vector (15 downto 0);
    signal r_reg_center_y   : std_logic_vector (15 downto 0);
    signal r_reg_src_radius : std_logic_vector (15 downto 0);
    signal r_reg_bypass     : std_logic;

    signal r_reg_lut_wdata  : std_logic_vector (15 downto 0);
    signal r_reg_lut_rdata  : std_logic_vector (15 downto 0);
    signal r_reg_lut_enable : std_logic;
    signal r_reg_lut_wen    : std_logic;

    -- LUT write/read access
    signal r_lut_wdata : std_logic_vector (7 downto 0);
    signal r_lut_rdata : std_logic_vector (7 downto 0);
    signal r_lut_addr  : std_logic_vector (10 downto 0);
    signal r_lut_enable: std_logic;
    signal r_lut_wren  : std_logic;
    -- LUT X Configure
    signal w_reg_lut_x_wdata  : std_logic_vector (10 downto 0);
    signal w_reg_lut_x_rdata  : std_logic_vector (10 downto 0);
    signal w_reg_lut_x_addr   : std_logic_vector (10 downto 0);
    signal w_reg_lut_x_enable : std_logic;
    signal w_reg_lut_x_wren   : std_logic;
    -- LUT Y Configure
    signal w_reg_lut_y_wdata  : std_logic_vector (10 downto 0);
    signal w_reg_lut_y_rdata  : std_logic_vector (10 downto 0);
    signal w_reg_lut_y_addr   : std_logic_vector (10 downto 0);
    signal w_reg_lut_y_enable : std_logic;
    signal w_reg_lut_y_wren   : std_logic;

    -- Memory Interface
    signal w_mem_rdata : std_logic_vector (15 downto 0);
    signal w_mem_addr  : std_logic_vecotr (15 downto 0);

    -- Function: Convert CHAR to STD_LOGIC_VECTOR
    function conv_char_to_logic_vector(char0 : character; char1 : character)
    return std_logic_vector is

        variable v_byte0 : integer;
        variable v_byte1 : integer;
        variable ret     : std_logic_vector (15 downto 0);
    begin
        v_byte0 := character'pos(char0);
        v_byte1 := character'pos(char1);
        ret  := std_logic_vector(to_unsigned(v_byte0,8)) & std_logic_vector(to_unsigned(v_byte1,8));
        return ret;
    end function;

    -- Function: Convert STD_LOGIC_VECTOR to CHAR
    function conv_std_logic_vector_to_char(byte : std_logic_vector(7 downto 0)) return character is
        variable temp : integer := 0;
    begin
        -- Convert byte to integer
        temp := to_integer(unsigned(byte));
        return CHARACTER'VAL(temp);
    end function;

    -- Components
    component dist_correction is
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
    end component;

    -- Edge Enhancements
    component edge_enhancement_v1_0 is
        generic (
            -- Users to add parameters here
            NUM_PIXELS              : integer   := 128;
            NUM_LINES               : integer   := 144
        );
        port (
            -- Users to add ports here

            i_axis_aclk     : in  std_logic;
            i_axis_aresetn  : in  std_logic;
            -- Video In - YUV422
            s_axis_tdata     : in  std_Logic_vector (15 downto 0);	-- Slave AXI-Stream
            s_axis_tvalid    : in  std_logic;
            s_axis_tready    : out std_Logic;
            s_axis_tuser_sof : in  std_Logic;
            s_axis_tlast     : in  std_logic;

            -- Video out - YUV 422
            m_axis_tdata     : out std_Logic_vector (15 downto 0);
            m_axis_tvalid    : out std_logic;
            m_axis_tready    : in  std_Logic;
            m_axis_tuser_sof : out std_Logic;
            m_axis_tlast     : out std_logic;

            -- Control Registers
            i_reg_matrix_select : in std_logic;
            i_reg_grayscale_en  : in std_logic;
            i_reg_kernel_bypass : in std_logic;
            i_reg_kernel_gain   : in std_logic_vector (11 downto 0)
        );
    end component;

begin

    tb1 : process
    begin
        enable <= '0';
        -- Enable Counter
        wait for 400 ns;
        enable <= '1';

        -- Wait for simulation to end
        wait;
    end process;


    ------------------------------------------
    -- AXI-Stream: OUT: Wirte to file
    ------------------------------------------
    file_write : process is
        file write_file : text;
        variable v_oline : line;
        variable v_frame_counter : integer;
        variable v_pixel_counter : integer;
    begin
        r_axis_dist_sim_tready <= '1';
        v_frame_counter := 0;
        v_pixel_counter := 0;
        -- Open File
        file_open(write_file, C_VIDEO_OUT_FILE, write_mode);
        loop
            -- Wait for clock cycle
            wait until (i_sim_clk'event and i_sim_clk = '1');
            if (w_axis_dist_sim_tvalid = '1' and r_axis_dist_sim_tready = '1') then
                if (w_axis_dist_sim_tdata(7 downto 0) = x"0A") then
                    write(v_oline, conv_std_logic_vector_to_char(x"0B"));
                else
                    write(v_oline, conv_std_logic_vector_to_char(w_axis_dist_sim_tdata(7 downto 0)));
                end if;
                if (w_axis_dist_sim_tdata(15 downto 8) = x"0A") then
                    write(v_oline, conv_std_logic_vector_to_char(x"0B"));
                else
                    write(v_oline, conv_std_logic_vector_to_char(w_axis_dist_sim_tdata(15 downto 8)));
                end if;
                -- Pixel Counter
                if (v_pixel_counter = 127) then
                    v_pixel_counter := 0;
                    writeline(write_file, v_oline);
                else
                    v_pixel_counter := v_pixel_counter + 1;
                end if;
                --if (stop_stream = '1') then
                --    exit;
                --end if
            end if;
        end loop;
        report "File save done";
        file_close(write_file);
    end process;


    dist_correction_u0 : dist_correction
    generic map(
        C_IMAGE_WIDTH    => C_IMAEG_WIDTH,
        C_IMAGE_HEIGHT   => C_IAMGE_HEIGHT,
        C_INIT_X_FILE    => C_CORR_LUT_X_FILE,
        C_INIT_Y_FILE    => C_CORR_LUT_Y_FILE,
    ) port map (
        -- Clock/Reset
        i_aclk           => i_sim_clk,
        i_aresetn        => i_sim_aresetn,
        -- LUT X Configure
        i_lut_x_wdata    => w_reg_lut_x_wdata,
        o_lut_x_rdata    => w_reg_lut_x_rdata,
        i_lut_x_addr     => w_reg_lut_x_addr,
        i_lut_x_enable   => w_reg_lut_x_enable,
        i_lut_x_wren     => w_reg_lut_x_wren,
        -- LUT Y Configure
        i_lut_y_wdata    => w_reg_lut_y_wdata,
        o_lut_y_rdata    => w_reg_lut_y_rdata,
        i_lut_y_addr     => w_reg_lut_y_addr,
        i_lut_y_enable   => w_reg_lut_y_enable,
        i_lut_y_wren     => w_reg_lut_y_wren,
        -- Memory Interface - Image In
        i_pxl_data       => w_mem_rdata,
        o_pxl_addr       => w_mem_addr,
        o_pxl_rden       => w_mem_rden,
        -- AXI Stream - Image Out corrected
        m_axis_tdata     => w_axis_dist_sim_tdata,
        m_axis_tvalid    => w_axis_dist_sim_tvalid,
        m_axis_tready    => r_axis_dist_sim_tready,
        m_axis_tuser_sof => w_axis_dist_sim_tuser_sof,
        m_axis_tlast     => w_axis_dist_sim_tlast
    );


end tb;

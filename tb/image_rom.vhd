library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity image_rom is
    generic(
        C_IMAGE_FILE : string  := "NONE";
        C_NUM_PIXELS : integer := 65200;
        C_ADDR_WIDTH : integer := 16;
        C_DATA_WIDTH : integer := 7
    );
    port(
        -- Clock
        i_aclk     : in std_logic;
        i_aresetn  : in std_logic;
        -- Memory interface
        i_rom_addr : in std_logic_vector(C_ADDR_WIDTH-1 downto 0);
        o_rom_data : out std_logic_vector(C_DATA_WIDTH-1 downto 0);
        i_rom_rden : in std_logic;
        o_rom_valid: out std_logic
    );
end image_rom;

architecture rtl of image_rom is

    signal r_rom_data : std_logic_vector (C_DATA_WIDTH-1 downto 0);
    signal r_rom_valid : std_logic;

    type rom_type is array (0 to C_NUM_PIXELS-1) of std_logic_vector(C_DATA_WIDTH-1 downto 0);
    signal rom : rom_type;

    -- Input File
    attribute ram_init_file : string;
    attribute ram_init_file of rom : signal is "./image_in.mif";
begin

    o_rom_data <= r_rom_data;
    o_rom_valid <= r_rom_valid;

    mem_ctrl : process(i_aclk)
    begin
        if (i_aresetn = '0') then
            r_rom_data <= (others => '0');
        elsif (i_aclk'event and (i_aclk = '1')) then
            if (i_rom_rden = '1') then
                r_rom_data <= rom(to_integer(unsigned(i_rom_addr)));
                r_rom_valid <= '1';
            else
                r_rom_valid <= '0';
            end if;
        end if;
    end process;
end rtl;

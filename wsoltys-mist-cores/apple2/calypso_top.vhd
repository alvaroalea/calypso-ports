--
-- Apple II+ toplevel for the calypso board
-- Ported from: https://github.com/wsoltys/mist_apple2
--
-- This source file is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published
-- by the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This source file is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity calypso_top is

  port (
    -- Clocks
    
    CLK12M    : in std_logic; -- 12 MHz


    -- SDRAM
    SDRAM_nCS : out std_logic; -- Chip Select
    SDRAM_DQ : inout std_logic_vector(15 downto 0); -- SDRAM Data bus 16 Bits
    SDRAM_A : out std_logic_vector(12 downto 0); -- SDRAM Address bus 13 Bits
    SDRAM_DQMH : out std_logic; -- SDRAM High Data Mask
    SDRAM_DQML : out std_logic; -- SDRAM Low-byte Data Mask
    SDRAM_nWE : out std_logic; -- SDRAM Write Enable
    SDRAM_nCAS : out std_logic; -- SDRAM Column Address Strobe
    SDRAM_nRAS : out std_logic; -- SDRAM Row Address Strobe
    SDRAM_BA : out std_logic_vector(1 downto 0); -- SDRAM Bank Address
    SDRAM_CLK : out std_logic; -- SDRAM Clock
    SDRAM_CKE: out std_logic; -- SDRAM Clock Enable
    
    -- SPI
    SPI_SCK : in std_logic;
    SPI_DI : in std_logic;
    SPI_DO : out std_logic;
    SPI_SS2 : in std_logic;
    SPI_SS3 : in std_logic;
    CONF_DATA0 : in std_logic;

    -- VGA output
    

    VGA_HS,                                             -- H_SYNC
    VGA_VS : out std_logic;                             -- V_SYNC
    VGA_R,                                              -- Red[5:0]
    VGA_G,                                              -- Green[5:0]
    VGA_B : out std_logic_vector(5 downto 0);           -- Blue[5:0]
    
    -- Audio
    AUDIO_L,
    AUDIO_R : out std_logic;
    
    -- LEDG
    LED : out std_logic_vector(7 downto 0)

    );
  
end calypso_top;

architecture datapath of calypso_top is

  constant CONF_STR : string := "AppleII+;;S,NIB;O2,Monitor Type,Color,Monochrome;O3,Monitor Mode,Main,Alt;O4,Enable Scanlines,off,on;O5,Joysticks,Normal,Swapped;O6,Mockingboard S4,off,on;T7,Cold reset;";

  function to_slv(s: string) return std_logic_vector is 
    constant ss: string(1 to s'length) := s; 
    variable rval: std_logic_vector(1 to 8 * s'length); 
    variable p: integer; 
    variable c: integer; 
  
  begin 
    for i in ss'range loop
      p := 8 * i;
      c := character'pos(ss(i));
      rval(p - 7 to p) := std_logic_vector(to_unsigned(c,8)); 
    end loop; 
    return rval; 

  end function; 



  component user_io 
    generic ( STRLEN : integer := 0 );
     port (
            SPI_CLK, SPI_SS_IO, SPI_MOSI :in std_logic;
            SPI_MISO : out std_logic;
            conf_str : in std_logic_vector(8*STRLEN-1 downto 0);
            joystick_0 : out std_logic_vector(5 downto 0);
            joystick_1 : out std_logic_vector(5 downto 0);
            joystick_analog_0 : out std_logic_vector(15 downto 0);
            joystick_analog_1 : out std_logic_vector(15 downto 0);
            status: out std_logic_vector(7 downto 0);
            switches : out std_logic_vector(1 downto 0);
            buttons : out std_logic_vector(1 downto 0);
            scandoubler_disable : out std_logic;
            ypbpr : out std_logic;
            sd_lba : in std_logic_vector(31 downto 0);
            sd_rd : in std_logic;
            sd_wr : in std_logic;
            sd_ack : out std_logic;
            sd_conf : in std_logic;
            sd_sdhc : in std_logic;
            sd_dout : out std_logic_vector(7 downto 0);
            sd_dout_strobe : out std_logic;
            sd_din : in std_logic_vector(7 downto 0);
            sd_din_strobe : out std_logic;
            sd_change : out std_logic;
            ps2_clk : in std_logic;
            ps2_kbd_clk : out std_logic;
            ps2_kbd_data : out std_logic
        );
  end component user_io;
  
  component sd_card
    port (io_lba : out std_logic_vector(31 downto 0);
          io_rd : out std_logic;
          io_wr : out std_logic;
          io_ack : in std_logic;
          io_sdhc : out std_logic;
          io_conf : out std_logic;
          io_din : in std_logic_vector(7 downto 0);
          io_din_strobe : in std_logic;
          io_dout : out std_logic_vector(7 downto 0);
          io_dout_strobe : in std_logic;
          allow_sdhc : in std_logic;
          sd_cs : in std_logic;
          sd_sck : in std_logic;
          sd_sdi : in std_logic;
          sd_sdo : out std_logic
    );
  end component sd_card;
  
  component data_io is
    port ( sck: in std_logic;
           ss: in std_logic;
           sdi: in std_logic;
           downloading: out std_logic;
           index: out std_logic_vector(4 downto 0);
           size: out std_logic_vector(24 downto 0);
           clk: in std_logic;
           wr: out std_logic;
           a: out std_logic_vector(24 downto 0);
           d: out std_logic_vector(7 downto 0));
  end component;
  
  component sdram is
    port( sd_data : inout std_logic_vector(15 downto 0);
          sd_addr : out std_logic_vector(12 downto 0);
          sd_dqm : out std_logic_vector(1 downto 0);
          sd_ba : out std_logic_vector(1 downto 0);
          sd_cs : out std_logic;
          sd_we : out std_logic;
          sd_ras : out std_logic;
          sd_cas : out std_logic;
          init : in std_logic;
          clk : in std_logic;
          clkref : in std_logic;
          din : in std_logic_vector(7 downto 0);
          dout : out std_logic_vector(7 downto 0);
          addr : in std_logic_vector(24 downto 0);
          we : in std_logic
    );
  end component;
  
  component osd
    port ( pclk, sck, ss, sdi, hs_in, vs_in, scanline_ena_h : in std_logic;
           red_in, blue_in, green_in : in std_logic_vector(5 downto 0);
           red_out, blue_out, green_out : out std_logic_vector(5 downto 0);
           hs_out, vs_out : out std_logic
         );
  end component osd;

  component rgb2ypbpr is
    port ( 
           red : in std_logic_vector(5 downto 0);
           green : in std_logic_vector(5 downto 0);
           blue : in std_logic_vector(5 downto 0);
           y :  out std_logic_vector(5 downto 0);
           pb : out std_logic_vector(5 downto 0);
           pr : out std_logic_vector(5 downto 0)
    );
  end component;

  signal CLK_28M, CLK_14M, CLK_2M, PRE_PHASE_ZERO, CLK_12k : std_logic;
  signal clk_div : unsigned(1 downto 0);
  signal IO_SELECT, DEVICE_SELECT : std_logic_vector(7 downto 0);
  signal ADDR : unsigned(15 downto 0);
  signal D, PD: unsigned(7 downto 0);
  signal DO : std_logic_vector(7 downto 0);

  signal we_ram : std_logic;
  signal VIDEO, HBL, VBL, LD194 : std_logic;
  signal COLOR_LINE : std_logic;
  signal COLOR_LINE_CONTROL : std_logic;
  signal SCREEN_MODE : std_logic_vector(1 downto 0);
  signal GAMEPORT : std_logic_vector(7 downto 0);
  signal cpu_pc : unsigned(15 downto 0);
  signal scandoubler_disable : std_logic;
  signal ypbpr : std_logic;

  signal vga_red : std_logic_vector(5 downto 0);
  signal vga_green : std_logic_vector(5 downto 0);
  signal vga_blue : std_logic_vector(5 downto 0);
  signal vga_hsync : std_logic;
  signal vga_vsync : std_logic;
  signal y : std_logic_vector(5 downto 0);
  signal pb : std_logic_vector(5 downto 0);
  signal pr : std_logic_vector(5 downto 0);
  
  signal K : unsigned(7 downto 0);
  signal read_key : std_logic;

  signal flash_clk : unsigned(22 downto 0) := (others => '0');
  signal power_on_reset : std_logic := '1';
  signal force_reset : std_logic := '0';
  signal reset : std_logic;

  signal D1_ACTIVE, D2_ACTIVE : std_logic;
  signal track_addr : unsigned(13 downto 0);
  signal TRACK_RAM_ADDR : unsigned(12 downto 0);
  signal tra : unsigned(15 downto 0);
  signal TRACK_RAM_DI : unsigned(7 downto 0);
  signal TRACK_RAM_WE : std_logic;
  signal track : unsigned(5 downto 0);
  signal image : unsigned(9 downto 0);
  signal sd_change : std_logic;

  signal CS_N, MOSI, MISO, SCLK : std_logic;
  
  signal downl : std_logic := '0';
  signal io_index : std_logic_vector(4 downto 0);
  signal size : std_logic_vector(24 downto 0) := (others=>'0');
  signal a_ram: unsigned(17 downto 0);
  signal osd_clk : std_logic;
  signal r : unsigned(7 downto 0);
  signal g : unsigned(7 downto 0);
  signal b : unsigned(7 downto 0);
  signal hsync : std_logic;
  signal vsync : std_logic;
  signal sd_we : std_logic;
  signal sd_oe : std_logic;
  signal sd_addr : std_logic_vector(18 downto 0);
  signal sd_di : std_logic_vector(7 downto 0);
  signal sd_do : std_logic_vector(7 downto 0);
  signal io_we : std_logic;
  signal io_addr : std_logic_vector(24 downto 0);
  signal io_do : std_logic_vector(7 downto 0);
  signal io_ram_we : std_logic;
  signal io_ram_d : std_logic_vector(7 downto 0);
  signal io_ram_addr : std_logic_vector(18 downto 0);
  signal ram_we : std_logic;
  signal ram_di : std_logic_vector(7 downto 0);
  signal ram_addr : std_logic_vector(24 downto 0);
  
  signal switches   : std_logic_vector(1 downto 0);
  signal buttons    : std_logic_vector(1 downto 0);
  signal joy        : std_logic_vector(5 downto 0);
  signal joy0       : std_logic_vector(5 downto 0);
  signal joy1       : std_logic_vector(5 downto 0);
  signal joy_an0    : std_logic_vector(15 downto 0);
  signal joy_an1    : std_logic_vector(15 downto 0);
  signal joy_an     : std_logic_vector(15 downto 0);
  signal status     : std_logic_vector(7 downto 0);
  signal ps2Clk     : std_logic;
  signal ps2Data    : std_logic;
  signal audio      : std_logic;
  signal audiol     : std_logic;
  signal audior     : std_logic;
  
  -- signals to connect sd card emulation with io controller
  signal sd_lba:  std_logic_vector(31 downto 0);
  signal sd_rd:   std_logic;
  signal sd_wr:   std_logic;
  signal sd_ack:  std_logic;
  signal sd_conf: std_logic;
  signal sd_sdhc: std_logic;
  
  -- data from io controller to sd card emulation
  signal sd_data_in: std_logic_vector(7 downto 0);
  signal sd_data_in_strobe:  std_logic;
  signal sd_data_out: std_logic_vector(7 downto 0);
  signal sd_data_out_strobe:  std_logic;
  
  -- sd card emulation
  signal sd_cs:	std_logic;
  signal sd_sck:	std_logic;
  signal sd_sdi:	std_logic;
  signal sd_sdo:	std_logic;
  
  signal pll_locked : std_logic;
  signal sdram_dqm: std_logic_vector(1 downto 0);
  signal joyx       : std_logic;
  signal joyy       : std_logic;
  signal pdl_strobe : std_logic;

begin

  reset <= status(0) or power_on_reset or force_reset;

  -- In the Apple ][, this was a 555 timer
  power_on : process(CLK_14M)
  begin
    if rising_edge(CLK_14M) then
      if buttons(1)='1' or status(7) = '1' then
        power_on_reset <= '1';
        flash_clk <= (others=>'0');
      else
		  if flash_clk(22) = '1' then
          power_on_reset <= '0';
			end if;
			 
        flash_clk <= flash_clk + 1;
      end if;
    end if;
  end process;
  
  SDRAM_CLK <= not CLK_28M;
  
  pll : entity work.pll 
  port map (
    areset => '0',
    inclk0 => CLK12M,
    c0     => CLK_28M,
    c1     => CLK_14M,
    c2     => CLK_12k,
    locked => pll_locked
    );

 
  -- Paddle buttons
  -- GAMEPORT input bits:
  --  7    6    5    4    3   2   1    0
  -- pdl3 pdl2 pdl1 pdl0 pb3 pb2 pb1 casette
  GAMEPORT <=  "00" & joyy & joyx & "0" & joy(5) & joy(4) & "0";
  
  joy_an <= joy_an0 when status(5)='0' else joy_an1;
  joy <= joy0 when status(5)='0' else joy1;
  
  process(CLK_2M, pdl_strobe)
    variable cx, cy : integer range -100 to 5800 := 0;
  begin
    if rising_edge(CLK_2M) then
      if cx > 0 then
        cx := cx -1;
        joyx <= '1';
      else
        joyx <= '0';
      end if;
      if cy > 0 then
        cy := cy -1;
        joyy <= '1';
      else
        joyy <= '0';
      end if;
      if pdl_strobe = '1' then
        cx := 2800+(22*to_integer(signed(joy_an(15 downto 8))));
        cy := 2800+(22*to_integer(signed(joy_an(7 downto 0)))); -- max 5650
        if cx < 0 then
          cx := 0;
        elsif cx >= 5590 then
          cx := 5650;
        end if;
        if cy < 0 then
          cy := 0;
        elsif cy >= 5590 then
          cy := 5650;
        end if;
      end if;
    end if;
  end process;

  COLOR_LINE_CONTROL <= COLOR_LINE and not (status(2) or status(3));  -- Color or B&W mode
  SCREEN_MODE <= status(2) & status(3); -- 00: Color, 01: B&W, 10:Green, 11: Amber
  
  -- sdram interface
  SDRAM_CKE <= '1';
  SDRAM_DQMH <= sdram_dqm(1);
  SDRAM_DQML <= sdram_dqm(0);

  sdram_inst : sdram
    port map( sd_data => SDRAM_DQ,
              sd_addr => SDRAM_A,
              sd_dqm => sdram_dqm,
              sd_cs => SDRAM_nCS,
              sd_ba => SDRAM_BA,
              sd_we => SDRAM_nWE,
              sd_ras => SDRAM_nRAS,
              sd_cas => SDRAM_nCAS,
              clk => CLK_28M,
              clkref => CLK_2M,
              init => not pll_locked,
              din => ram_di,
              addr => ram_addr,
              we => ram_we,
              dout => DO
    );
  
  -- Simulate power up on cold reset to go to the disk boot routine
  ram_we   <= we_ram when status(7) = '0' else '1';
  ram_addr <= "0000000" & std_logic_vector(a_ram) when status(7) = '0' else std_logic_vector(to_unsigned(1012,ram_addr'length)); -- $3F4
  ram_di   <= std_logic_vector(D) when status(7) = '0' else "00000000";
  
  core : entity work.apple2 port map (
    CLK_14M        => CLK_14M,
    CLK_2M         => CLK_2M,
    PRE_PHASE_ZERO => PRE_PHASE_ZERO,
    FLASH_CLK      => flash_clk(22),
    reset          => reset,
    ADDR           => ADDR,
    ram_addr       => a_ram,
    D              => D,
    ram_do         => unsigned(DO),
    PD             => PD,
    ram_we         => we_ram,
    VIDEO          => VIDEO,
    COLOR_LINE     => COLOR_LINE,
    HBL            => HBL,
    VBL            => VBL,
    LD194          => LD194,
    K              => K,
    read_key       => read_key,
    AN             => open,
    GAMEPORT       => GAMEPORT,
    PDL_strobe     => pdl_strobe,
    IO_SELECT      => IO_SELECT,
    DEVICE_SELECT  => DEVICE_SELECT,
    pcDebugOut     => cpu_pc,
    speaker        => audio,
    laudio         => audiol,
    raudio         => audior,
    mb_enabled     => status(6)
    );
    
  AUDIO_L <= audiol or audio;
  AUDIO_R <= audior or audio;

  vga : entity work.vga_controller port map (
    CLK_28M    => CLK_28M,
    VIDEO      => VIDEO,
    COLOR_LINE => COLOR_LINE_CONTROL,
	 SCREEN_MODE => SCREEN_MODE,
    HBL        => HBL,
    VBL        => VBL,
    LD194      => LD194,
    VGA_CLK    => open,
    VGA_HS     => hsync,
    VGA_VS     => vsync,
    VGA_BLANK  => open,
    VGA_R      => r,
    VGA_G      => g,
    VGA_B      => b
    );

  keyboard : entity work.keyboard port map (
    PS2_Clk  => ps2Clk,
    PS2_Data => ps2Data,
    CLK_14M  => CLK_14M,
    reset    => reset,
    reads     => read_key,
    K        => K
    );

  disk : entity work.disk_ii port map (
    CLK_14M        => CLK_14M,
    CLK_2M         => CLK_2M,
    PRE_PHASE_ZERO => PRE_PHASE_ZERO,
    IO_SELECT      => IO_SELECT(6),
    DEVICE_SELECT  => DEVICE_SELECT(6),
    RESET          => reset,
    A              => ADDR,
    D_IN           => D,
    D_OUT          => PD,
    TRACK          => TRACK,
    TRACK_ADDR     => TRACK_ADDR,
    D1_ACTIVE      => D1_ACTIVE,
    D2_ACTIVE      => D2_ACTIVE,
    ram_write_addr => TRACK_RAM_ADDR,
    ram_di         => TRACK_RAM_DI,
    ram_we         => TRACK_RAM_WE
    );

  sdcard_interface : entity work.spi_controller port map (
    CLK_14M        => CLK_14M,
    RESET          => RESET,

    CS_N           => sd_cs,
    MOSI           => sd_sdi,
    MISO           => sd_sdo,
    SCLK           => sd_sck,
    
    change         => sd_change,
    track          => TRACK,
    image          => (others=>'0'),
    busy           => LED(0),
    
    ram_write_addr => TRACK_RAM_ADDR,
    ram_di         => TRACK_RAM_DI,
    ram_we         => TRACK_RAM_WE
    );
    
  --LED <= not D1_ACTIVE;
  
  user_io_d : user_io
    generic map (STRLEN => CONF_STR'length)
    
    port map ( 
      SPI_CLK => SPI_SCK,
      SPI_SS_IO => CONF_DATA0,    
      SPI_MISO => SPI_DO,    
      SPI_MOSI => SPI_DI,       
      conf_str => to_slv(CONF_STR),
      status => status,   
      joystick_0 => joy0,   
      joystick_1 => joy1,
      joystick_analog_0 => joy_an0,
      joystick_analog_1 => joy_an1,
      SWITCHES => switches,
      BUTTONS => buttons,
		scandoubler_disable => scandoubler_disable,
		ypbpr => ypbpr,
      -- connection to io controller
      sd_lba  => sd_lba,
      sd_rd   => sd_rd,
      sd_wr   => sd_wr,
      sd_ack  => sd_ack,
      sd_sdhc => sd_sdhc,
      sd_conf => sd_conf,
      sd_dout => sd_data_in,
      sd_dout_strobe => sd_data_in_strobe,
      sd_din => sd_data_out,
      sd_din_strobe => sd_data_out_strobe,
      sd_change => sd_change, 
      ps2_clk => CLK_12k,
      ps2_kbd_clk => ps2Clk,
      ps2_kbd_data => ps2Data
    );
    
  sd_card_d: component sd_card
    port map
    (
      -- connection to io controller
      io_lba => sd_lba,
      io_rd  => sd_rd,
      io_wr  => sd_wr,
      io_ack => sd_ack,
      io_conf => sd_conf,
      io_sdhc => sd_sdhc,
      io_din => sd_data_in,
      io_din_strobe => sd_data_in_strobe,
      io_dout => sd_data_out,
      io_dout_strobe => sd_data_out_strobe,
   
      allow_sdhc  => '1',
      
      -- connection to host
      sd_cs  => sd_cs,
      sd_sck => sd_sck,
      sd_sdi => sd_sdi,
      sd_sdo => sd_sdo		
    );

  osd_inst : osd
    port map (
      pclk => CLK_14M,
      sdi => SPI_DI,
      sck => SPI_SCK,
      ss => SPI_SS3,
      red_in => std_logic_vector(r(7 downto 2)),
      green_in => std_logic_vector(g(7 downto 2)),
      blue_in => std_logic_vector(b(7 downto 2)),
      hs_in => hsync,
      vs_in => vsync,
      scanline_ena_h => status(4),
      red_out => vga_red,
      green_out => vga_green,
      blue_out => vga_blue,
      hs_out => vga_hsync,
      vs_out => vga_vsync
    );

  -- map ypbpr or rgb to VGA output
  VGA_R <= pr when ypbpr='1' else vga_red;
  VGA_G <= y  when ypbpr='1' else vga_green;
  VGA_B <= pb when ypbpr='1' else vga_blue;
  VGA_HS <= not (vga_hsync xor vga_vsync) when ypbpr='1' else vga_hsync;
  VGA_VS <= '1' when ypbpr='1' else vga_vsync;

  rgb2component : rgb2ypbpr
    port map (
      red   => vga_red,
      green => vga_green,
      blue  => vga_blue,
      y     => y,
      pb    => pb,
      pr    => pr
    );

end datapath;

--------------------------------------------------------------------------------
-- Company: HHI
-- Engineers: Dung
--
-- Create Date: 2023-06-27
-- Module Name: tb_utils.vhd
-- Description:
--     This package contains utilities, functions and procedures for creating
--     testbenches for VHDL designs. It also contains useful functions and
--     presets for console output and debugging.
--------------------------------------------------------------------------------

-- Import ieee and standard libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;

package tb_utils_pkg is
    ----------------------------------------------------------------------------
    -- Time constants
    ----------------------------------------------------------------------------
    constant clk_period : time := 8 ns;

    -- Wait time for initialisation process and this time duration also prevents
    -- the simulation from starting testcases automatically
    constant init_period : time := 100 * clk_period;

    -- Wait time for the simulation to finish the testcase or end of test
    constant testcase_to_finish : time := 100 * clk_period;

    ----------------------------------------------------------------------------
    -- Architecture constants
    ----------------------------------------------------------------------------
    constant AXI_DATA_WIDTH    : integer := 32;  -- PS <-> PL
    constant AXI_ADDR_WIDTH    : integer := 32;  -- PS <-> PL
    constant AXI_IC_ADDR_WIDTH : integer := 6;   -- AXI Interconnect <-> IP

    ----------------------------------------------------------------------------
    -- Array type definitions
    ----------------------------------------------------------------------------
    type sl_array is array(natural range <>) of std_logic;
    type slv8_array is array(natural range <>) of std_logic_vector(7 downto 0);
    type slv16_array is array(natural range <>) of std_logic_vector(15 downto 0);
    type slv32_array is array(natural range <>) of std_logic_vector(31 downto 0);
    type slv64_array is array(natural range <>) of std_logic_vector(63 downto 0);
    type axi_data_array is array(natural range <>) of std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);
    type axi_addr_array is array(natural range <>) of std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
    type axi_ic_addr_array is array(natural range <>) of std_logic_vector(AXI_IC_ADDR_WIDTH - 1 downto 0);

    ----------------------------------------------------------------------------
    -- Console output
    ----------------------------------------------------------------------------
    shared variable l : line;

    -- Procedure for printing an empty line to the console
    procedure PrintEmptyLines(constant lines : integer);

    -- Procedure for printing a string to the console, with optional separation
    -- line above or below the string (default is no separation line)
    constant sep_none     : integer := 0;
    constant sep_up       : integer := 1;
    constant sep_down     : integer := 2;
    constant sep_line_len : integer := 250;

    procedure Print(
        constant str     : string;
        constant sep_pos : integer := sep_none;
        constant sep_len : integer := sep_line_len
        );

    ----------------------------------------------------------------------------
    -- Read files
    ----------------------------------------------------------------------------
    type file_open_status is (opened, closed, read_error, open_error);
    constant FILENAME : string := "your_file_path_here.txt";  -- Change to your file path

    -- Procedure for reading a 8 character hex file into a 32-bit array
    procedure read_8_char_hex_file(
        file_name : in    string;
        hex_array : inout slv32_array;
        verbose   : in    boolean := false
        );
    
    -- Procedure for writing data to a file as hex values
    procedure write_signal_hex_file(
        data_array : in slv32_array;
        sample_count : in natural;  
        file_name   : in string;
        verbose     : in boolean := false
        );

    ----------------------------------------------------------------------------
    -- System procedures
    ----------------------------------------------------------------------------
    -- Generate a clock signal with a specified period
    procedure GenerateClock(
        signal clk            : out std_logic;
        constant clk_period   :     time;
        signal clk_gen_enable :     boolean
        );

    -- Reset all modules connected to reset vector and AXI components
    procedure ResetSystem(
        signal rstn        : out std_logic_vector;
        signal axi_aresetn : out std_logic
        );

    -- Reset a specific module connected to reset vector
    procedure ResetModule(
        signal rstn          : out std_logic_vector;
        constant reset_index :     integer
        );

    -- Enable a specific module connected to reset vector
    procedure EnableModule(
        signal rstn          : out std_logic_vector;
        constant reset_index :     integer
        );

    -- Disable a specific module connected to reset vector
    procedure DisableModule(
        signal rstn          : out std_logic_vector;
        constant reset_index :     integer
        );

    -- Toogle a std_logic signal
    procedure ToogleStdLogic(
        signal sig          : inout std_logic;
        constant clk_period :       time
        );

    ----------------------------------------------------------------------------
    -- Common Procedures for user IP-Cores
    ----------------------------------------------------------------------------

    -- start output at dac-bram-ctrl using dac-bram-sync IP
    procedure StartDacBramOutput(
        constant port_id         : in  integer;
        signal start_bram_output : out std_logic_vector(31 downto 0)
        );

    -- start output at dac-bram-ctrl using dac-bram-sync IP
    procedure StopDacBramOutput(
        constant port_id         : in  integer;
        signal start_bram_output : out std_logic_vector(31 downto 0)
        );

    ----------------------------------------------------------------------------
    -- Procedures for AXI4 Lite read and write transactions
    ----------------------------------------------------------------------------
    -- AXI Write procedure for writing data to an AXI device
    -- Width of signal wires are left undefined to allow for flexibility
    -- When calling the procedure, it is your job to ensure matching signal widths
    procedure AXIWrite(
        constant address    : in    std_logic_vector;
        constant data       : in    std_logic_vector;
        constant clk_period :       time;
        signal sendIt       : inout std_logic;
        signal awaddr       : out   std_logic_vector;
        signal wdata        : out   std_logic_vector;
        signal wstrb        : out   std_logic_vector;
        signal bvalid       : in    std_logic
        );

    -- Procedure to initiate a process, which simulates a master wanting to write.
    -- This process is blocked on a "Send Flag". When the flag goes to 1,
    -- the process exits the wait state and execute a write transaction.
    procedure AXIWriteHandshake(
        signal clk     : in  std_logic;
        signal sendIt  : in  std_logic;
        signal awvalid : out std_logic;
        signal awready : in  std_logic;
        signal wvalid  : out std_logic;
        signal wready  : in  std_logic;
        signal bvalid  : in  std_logic;
        signal bready  : out std_logic;
        signal bresp   : in  std_logic_vector(1 downto 0)
        );

    -- AXI Read procedure for reading data from an AXI device
    -- Width of signal wires are left undefined to allow for flexibility
    -- When calling the procedure, it is your job to ensure matching signal widths
    procedure AXIRead(
        constant address    : in    std_logic_vector;
        constant clk_period :       time;
        signal readIt       : inout std_logic;
        signal araddr       : out   std_logic_vector;
        signal rvalid       : in    std_logic
        );

    -- Procedure to initiate a process, which simulates a master wanting to read.
    -- This process is blocked on a "Read Flag". When flag is raised,
    -- the process exits the wait state and execute a read transaction.
    procedure AXIReadHandshake(
        signal clk     : in  std_logic;
        signal readIt  : in  std_logic;
        signal arvalid : out std_logic;
        signal arready : in  std_logic;
        signal rvalid  : in  std_logic;
        signal rready  : out std_logic
        );

    ----------------------------------------------------------------------------
    -- Procedures and functions for conversions
    ----------------------------------------------------------------------------
    -- Type for converting std_logic_vector to string
    type char_indexed_by_SL is array(std_logic) of character;
    constant SL_TO_CHAR : char_indexed_by_SL :=
        ('0' => '0', '1' => '1', 'U' => 'U', 'X' => 'X', 'Z' => 'Z',
         'W' => 'W', 'L' => 'L', 'H' => 'H', '-' => '-', others => '?');

    -- Function for converting std_logic_vector to string
    function Slv2Str(slv : std_logic_vector) return string;

    -- Function for converting std_logic_vector to hex string
    function Slv2HexStr(slv : std_logic_vector) return string;

    -- Function to convert hex string to std_logic_vector
    function HexStr2Int(hex_str : string) return integer;

    -- Convert integer to std_logic_vector
    function Int2Slv(x : integer; size : integer) return std_logic_vector;

    -- Convert binary value to gray code
    function Bin2Gray(bin : unsigned) return unsigned;

    -- Convert gray code to binary value
    function Gray2Bin(gray : unsigned) return unsigned;

    ----------------------------------------------------------------------------
    --  Math functions and bit manipulation
    ----------------------------------------------------------------------------
    -- Returns the ceiling of the base 2 logarithm of value x.
    -- This function does not work in port declaration!
    function clogb2(x : natural) return natural;

    ----------------------------------------------------------------------------
    -- Final test evaluation
    ----------------------------------------------------------------------------
    procedure TestbenchPassed;
    procedure TestbenchFailed;

end package tb_utils_pkg;

package body tb_utils_pkg is
    ----------------------------------------------------------------------------
    -- Console output
    ----------------------------------------------------------------------------
    -- Procedure for printing empty lines to the console
    procedure PrintEmptyLines(constant lines : integer) is
    begin
        for i in 1 to lines loop
            writeline(OUTPUT, l);
        end loop;
    end procedure;

    -- Procedure for printing a string to the console
    procedure Print(
        constant str     : string;
        constant sep_pos : integer := sep_none;
        constant sep_len : integer := sep_line_len
        ) is
        variable sep_line : string(1 to sep_len);
    begin
        for i in 1 to sep_len loop
            sep_line(i) := '-';
        end loop;

        if (sep_up = sep_pos) then
            write(l, sep_line);
            writeline(OUTPUT, l);
        end if;

        write(l, str);
        writeline(OUTPUT, l);

        if (sep_down = sep_pos) then
            write(l, sep_line);
            writeline(OUTPUT, l);
        end if;
    end procedure;

    ----------------------------------------------------------------------------
    -- Read files
    ----------------------------------------------------------------------------
    -- Procedure for reading a 8 character hex file into a 32-bit array
    procedure read_8_char_hex_file(
        file_name : in    string;
        hex_array : inout slv32_array;
        verbose   : in    boolean := false
        ) is
        file f           : text open read_mode is file_name;
        variable line    : line;
        variable hex_int : integer;
        variable hex_str : string(1 to 8);
        variable hex_val : std_logic_vector(31 downto 0);
        variable i       : integer := 0;
    begin
        if verbose then
            PrintEmptyLines(1);
            Print("Reading file: " & file_name, sep_up);
        end if;

        while not endfile(f) loop
            readline(f, line);
            read(line, hex_str);
            hex_int      := HexStr2Int(hex_str);
            hex_val      := std_logic_vector(to_unsigned(hex_int, hex_val'length));
            hex_array(i) := hex_val;
            i            := i + 1;

            if verbose then
                Print("Index " & integer'image(i-1) & " | hex_val: " & Slv2HexStr(hex_val));
            end if;
        end loop;

        if verbose then
            Print("Read " & integer'image(i) & " values from file", sep_down);
        end if;
        file_close(f);
    end procedure read_8_char_hex_file;


    -- Procedure for logging a signal to a file as hex values
    procedure write_signal_hex_file(
        data_array : in slv32_array;
        sample_count : in natural;
        file_name   : in string;
        verbose     : in boolean := false
    ) is
        file f : text open write_mode is file_name;
        variable L : line;
    begin
        for i in 0 to sample_count - 1 loop
            write(L, string'("0x"));
            write(L, to_hstring(data_array(i)));
            writeline(f, L);

            if verbose then
                Print("Index " & integer'image(i) & " | hex_val: " & Slv2HexStr(data_array(i)));
            end if;
        end loop;
    end procedure;


    ----------------------------------------------------------------------------
    -- System procedures
    ----------------------------------------------------------------------------
    -- Generate a clock signal with a specified period
    procedure GenerateClock(
        signal clk            : out std_logic;
        constant clk_period   :     time;
        signal clk_gen_enable :     boolean
        ) is
    begin
        while (clk_gen_enable) loop
            clk <= '0', '1' after clk_period / 2;
            wait for clk_period;
        end loop;
    end procedure;

    -- This procedure needs to be called at the beginning of the simulation
    -- to reset the DUT(s) and all AXI components
    procedure ResetSystem(
        signal rstn        : out std_logic_vector;
        signal axi_aresetn : out std_logic
        ) is
    begin
        rstn        <= (others => '0');
        axi_aresetn <= '0';
        wait for clk_period;
        rstn        <= (others => '1');
        axi_aresetn <= '1';
    end procedure;

    -- Reset a specific module connected to reset vector
    procedure ResetModule(
        signal rstn          : out std_logic_vector;
        constant reset_index :     integer
        ) is
    begin
        rstn(reset_index) <= '0';
        wait for clk_period;
        rstn(reset_index) <= '1';
    end procedure;

    -- Enable a specific module connected to reset vector
    procedure EnableModule(
        signal rstn          : out std_logic_vector;
        constant reset_index :     integer
        ) is
    begin
        rstn(reset_index) <= '1';
    end procedure;

    -- Disable a specific module connected to reset vector
    procedure DisableModule(
        signal rstn          : out std_logic_vector;
        constant reset_index :     integer
        ) is
    begin
        rstn(reset_index) <= '0';
    end procedure;

    -- Toogle a std_logic signal
    procedure ToogleStdLogic(
        signal sig          : inout std_logic;
        constant clk_period :       time
        ) is
    begin
        sig <= not sig;
        wait for clk_period;
        sig <= not sig;
    end procedure;

    ----------------------------------------------------------------------------
    -- Common Procedures for user IP-Cores
    ----------------------------------------------------------------------------
    procedure StartDacBramOutput(
        constant port_id         : in  integer;
        signal start_bram_output : out std_logic_vector(31 downto 0)) is
    begin
        start_bram_output(port_id) <= '1';
    end procedure;

    procedure StopDacBramOutput(
        constant port_id         : in  integer;
        signal start_bram_output : out std_logic_vector(31 downto 0)) is
    begin
        start_bram_output(port_id) <= '0';
    end procedure;

    ----------------------------------------------------------------------------
    -- Procedures for AXI4 Lite read and write transactions
    ----------------------------------------------------------------------------
    -- Procedure for writing data to an AXI device (part 1)
    procedure AXIWrite(
        constant address    : in    std_logic_vector;
        constant data       : in    std_logic_vector;
        constant clk_period :       time;
        signal sendIt       : inout std_logic;
        signal awaddr       : out   std_logic_vector;
        signal wdata        : out   std_logic_vector;
        signal wstrb        : out   std_logic_vector;
        signal bvalid       : in    std_logic
        ) is
    begin
        wdata  <= data;
        awaddr <= address;
        wstrb  <= (others => '1');
        -- Toogle send flag and wait until write is finished
        sendIt <= '1';
        wait for clk_period;
        sendIt <= '0';
        wait until bvalid = '1';
        wait until bvalid = '0';
        wstrb  <= (others => '0');
    end procedure;

    -- Procedure for writing data to an AXI device (part 2)
    procedure AXIWriteHandshake(
        signal clk     : in  std_logic;
        signal sendIt  : in  std_logic;
        signal awvalid : out std_logic;
        signal awready : in  std_logic;
        signal wvalid  : out std_logic;
        signal wready  : in  std_logic;
        signal bvalid  : in  std_logic;
        signal bready  : out std_logic;
        signal bresp   : in  std_logic_vector(1 downto 0)
        ) is
    begin
        awvalid <= '0';
        wvalid  <= '0';
        bready  <= '0';
        loop
            wait until sendIt = '1';
            wait until clk = '0';
            awvalid <= '1';
            wvalid  <= '1';
            -- Wait until slave is ready to accept data
            wait until (awready and wready) = '1';
            bready  <= '1';
            wait until bvalid = '1';
            assert bresp = "00" report "AXI data not written" severity failure;
            awvalid <= '0';
            wvalid  <= '0';
            bready  <= '1';
            -- Wait until write transaction is finished
            wait until bvalid = '0';
            bready  <= '0';
        end loop;
    end procedure;

    -- Procedure for reading data from an AXI device (part 1)
    procedure AXIRead(
        constant address    : in    std_logic_vector;
        constant clk_period :       time;
        signal readIt       : inout std_logic;
        signal araddr       : out   std_logic_vector;
        signal rvalid       : in    std_logic
        ) is
    begin
        araddr <= address;
        -- Toogle read flag and wait until read finished
        readIt <= '1';
        wait for clk_period;
        readIt <= '0';
        wait until rvalid = '1';
        wait until rvalid = '0';
    end procedure;

    -- Procedure for reading data from an AXI device (part 2)
    procedure AXIReadHandshake(
        signal clk     : in  std_logic;
        signal readIt  : in  std_logic;
        signal arvalid : out std_logic;
        signal arready : in  std_logic;
        signal rvalid  : in  std_logic;
        signal rready  : out std_logic
        ) is
    begin
        arvalid <= '0';
        rready  <= '0';
        loop
            wait until readIt = '1';
            wait until clk = '0';
            arvalid <= '1';
            rready  <= '1';
            wait until arready = '0';
            arvalid <= '0';
            wait until rvalid = '0';
            rready  <= '0';
        end loop;
    end procedure;

    ----------------------------------------------------------------------------
    -- Procedures and functions for conversions
    ----------------------------------------------------------------------------
    -- Function for converting std_logic_vector to string
    function Slv2Str(slv : std_logic_vector) return string is
        variable slv_string : string(slv'length downto 1);
        variable j          : integer;
    begin
        j := slv'length;
        if slv'ascending then
            for i in slv'left to slv'right loop
                slv_string(j) := SL_TO_CHAR(slv(i));
                j             := j - 1;
            end loop;
        else
            for i in slv'left downto slv'right loop
                slv_string(j) := SL_TO_CHAR(slv(i));
                j             := j - 1;
            end loop;
        end if;
        return slv_string;
    end function Slv2Str;

    -- Function for converting std_logic_vector to hex string
    function Slv2HexStr(slv : std_logic_vector) return string is
        variable hex_string : string(1 to slv'length/4);
        variable hex_map    : string(1 to 16) := "0123456789ABCDEF";
        variable nibble     : std_logic_vector(3 downto 0);
    begin
        for i in 0 to slv'length/4-1 loop
            nibble          := slv(slv'high-4*i downto slv'high-4*i-3);
            hex_string(i+1) := hex_map(to_integer(unsigned(nibble))+1);
        end loop;
        return hex_string;
    end function Slv2HexStr;

    -- This version is for VHDL 2008 and newer, which has built-in to_hstring
    -- Change to this version if using Vivado 2023.1 or newer
    -- function Slv2HexStr(slv : std_logic_vector) return string is
    -- begin
    --     return to_hstring(to_bitvector(slv));
    -- end function Slv2HexStr;

    -- Function to convert hex string to integer
    function HexStr2Int(hex_str : string) return integer is
        variable result : integer := 0;
    begin
        for i in hex_str'range loop
            result := result * 16;
            case hex_str(i) is
                when '0' to '9' => result := result + character'pos(hex_str(i)) - character'pos('0');
                when 'A' to 'F' => result := result + character'pos(hex_str(i)) - character'pos('A') + 10;
                when 'a' to 'f' => result := result + character'pos(hex_str(i)) - character'pos('a') + 10;
                when others     => null;  -- Ignore invalid characters
            end case;
        end loop;
        return result;
    end function HexStr2Int;

    -- Convert integer to std_logic_vector
    function Int2Slv(
        x    : integer;
        size : integer
        ) return std_logic_vector is
        variable res : std_logic_vector(size - 1 downto 0);
    begin
        return std_logic_vector(to_unsigned(x, size));
    end function Int2Slv;

    -- Convert binary value to gray code
    function Bin2Gray(
        bin : unsigned
        ) return unsigned is
        variable result : unsigned(bin'range);
    begin
        result := ('0' & bin(bin'high downto 1)) xor bin;
        return result;
    end function Bin2Gray;

    -- Convert gray code to binary value
    function Gray2Bin(
        gray : unsigned
        ) return unsigned is
        variable result : unsigned(gray'range);
    begin
        result(result'high) := gray(gray'high);

        for i in gray'high-1 downto 0 loop
            result(i) := gray(i) xor result(i+1);
        end loop;

        return result;
    end function Gray2Bin;


    ----------------------------------------------------------------------------
    --  Math functions and bit manipulation
    ----------------------------------------------------------------------------
    -- Returns the ceiling of the base 2 logarithm of value x.
    -- This function does not work in port declaration!
    function clogb2 (x : natural) return natural is
        variable res : natural := 0;
        variable val : natural := x;
    begin
        while val > 1 loop
            val := val / 2;
            res := res + 1;
        end loop;
        return res;
    end function clogb2;

    ----------------------------------------------------------------------------
    -- Final test evaluation
    ----------------------------------------------------------------------------
    procedure TestbenchPassed is
    begin
        Print("                                                 /===-_---~~~~~~~~~------____");
        Print("                                                |===-~___                _,-'");
        Print("                 -==\\                         `//~\\   ~~~~`---.___.-~~");
        Print("             ______-==|                         | |  \\           _-~`");
        Print("       __--~~~  ,-/-==\\                        | |   `\\        ,'");
        Print("    _-~       /'    |  \\                      / /      \\      /");
        Print("  .'        /       |   \\                   /' /        \\   /'");
        Print(" /  ____  /         |    `\\.__/-~~ ~ \\ _ _/'  /          \\/'");
        Print("/-'~    ~~~~~---__  |     ~-/~         ( )   /'        _--~`");
        Print("                  \\_|      /        _)   ;  ),   __--~~");
        Print("                    '~~--_/      _-~/-  / \\   '-~ \\");
        Print("                   {\\__--_/}    / \\\\_&gt;- )<__\\      \\");
        Print("                   /'   (_/  _-~  | |__&gt;--<__|      |");
        Print("                  |0  0 _/) )-~     | |__&gt;--<__|     |");
        Print("                  / /~ ,_/       / /__&gt;---<__/      |");
        Print("                 o o _//        /-~_&gt;---<__-~      /");
        Print("                 (^(~          /~_&gt;---<__-      _-~");
        Print("                ,/|           /__&gt;--<__/     _-~");
        Print("             ,//('(          |__&gt;--<__|     /                  .----_");
        Print("            ( ( '))          |__&gt;--<__|    |                 /' _---_~\\");
        Print("         `-)) )) (           |__&gt;--<__|    |               /'  /     ~\\`\\");
        Print("        ,/,'//( (             \\__&gt;--<__\\    \\            /'  //        ||");
        Print("      ,( ( ((, ))              ~-__&gt;--<__~-_  ~--____---~' _/'/        /'");
        Print("    `~/  )` ) ,/|                 ~-_~&gt;--<__/-__       __-~ _/");
        Print("  ._-~//( )/ )) `                    ~~-'_/_/ /~~~~~~~__--~");
        Print("   ;'( ')/ ,)(                              ~~~~~~~~~~");
        Print("  ' ') '( (/");
        Print("    '   '  `");
        PrintEmptyLines(1);
        Print("The module is working flawlessly!");
        Print("Here's a mighty fine dragon for your efforts!");
        PrintEmptyLines(1);
    end procedure;


    procedure TestbenchFailed is
    begin
        Print("                               ________________");
        Print("                          ____/ (  (    )   )  \___");
        Print("                         /( (  (  )   _    ))  )   )\");
        Print("                       ((     (   )(    )  )   (   )  )");
        Print("                     ((/  ( _(   )   (   _) ) (  () )  )");
        Print("                    ( (  ( (_)   ((    (   )  .((_ ) .  )_");
        Print("                   ( (  )    (      (  )    )   ) . ) (   )");
        Print("                  (  (   (  (   ) (  _  ( _) ).  ) . ) ) ( )");
        Print("                  ( (  (   ) (  )   (  ))     ) _)(   )  )  )");
        Print("                 ( (  ( \ ) (    (_  ( ) ( )  )   ) )  )) ( )");
        Print("                  (  (   (  (   (_ ( ) ( _    )  ) (  )  )   )");
        Print("                 ( (  ( (  (  )     (_  )  ) )  _)   ) _( ( )");
        Print("                  ((  (   )(    (     _    )   _) _(_ (  (_ )");
        Print("                   (_((__(_(__(( ( ( |  ) ) ) )_))__))_)___)");
        Print("                   ((__)        \\||lll|l||///          \\_))");
        Print("                                /(/ (  )  ) )\\");
        Print("                               ( ( ( | | ) ) )\\");
        Print("                               /(| / ( )) ) ) ");
        Print("                               ( ((((_(|)_)))))");
        Print("                                 ||\\(|(|)|/||");
        Print("                                 |(||(||)||||");
        Print("                                //|/l|||)|\\\\ \\");
        Print("                         / / //  /|//||||\\\\  \\ \\  ");
        PrintEmptyLines(1);
        Print("The module is not working as expected!");
        Print("Your parents are disappointed in you!");
        PrintEmptyLines(1);
    end procedure;
end package body tb_utils_pkg;

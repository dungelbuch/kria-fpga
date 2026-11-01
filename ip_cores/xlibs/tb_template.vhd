--------------------------------------------------------------------------------
-- Company:
-- Engineers:
--
-- Create Date:
-- Module Name:
-- Project Name:
-- Target Devices:
-- Tool Versions: Vivado 2020.1
-- Description:
--
--------------------------------------------------------------------------------

-- Import ieee and standard libraries
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;
library std;
use std.textio.all;
-- Import custom libraries
use work.tb_utils_pkg.all;

entity module_tb is
    generic (
        -- Reset parameters
        reset_width      : natural := 1;
        reset_index      : natural := 0;
        -- Parameters of Axi Slave Bus Interface S00_AXI
        s_axi_data_width : natural := 32;
        s_axi_addr_width : natural := 6;
        -- Parameters of testvector
        tv_data_width    : natural := 1000;
        -- Path to the repository, used to locate the test vectors.
        -- Set by scripts/core_sim.tcl when the simulation project is created.
        repo_path        : string  := "."
        );
end module_tb;

architecture sim of module_tb is
    ----------------------------------------------------------------------------
    -- Location of the test vectors, repo_path is a generic
    constant test_path      : string := "/ip_cores/<module_name>/sim/test_data/";
    constant test_data_path : string := repo_path & test_path;
    ----------------------------------------------------------------------------

    -- Simulation time constants
    constant aclk_period : time := 8 ns;

    -- DUT signals
    signal aclk_gen_enable : boolean                                    := true;
    signal aclk            : std_logic                                  := '0';
    signal rstn            : std_logic_vector(reset_width - 1 downto 0) := (others => '1');

    -- AXI slave interface
    signal s_axi_aresetn      : std_logic := '1';
    signal s_axi_regs_awaddr  : std_logic_vector(s_axi_addr_width - 1 downto 0);
    signal s_axi_regs_awprot  : std_logic_vector(2 downto 0);
    signal s_axi_regs_awvalid : std_logic;
    signal s_axi_regs_awready : std_logic;
    signal s_axi_regs_wdata   : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal s_axi_regs_wstrb   : std_logic_vector((s_axi_data_width/8) - 1 downto 0);
    signal s_axi_regs_wvalid  : std_logic;
    signal s_axi_regs_wready  : std_logic;
    signal s_axi_regs_bresp   : std_logic_vector(1 downto 0);
    signal s_axi_regs_bvalid  : std_logic;
    signal s_axi_regs_bready  : std_logic;
    signal s_axi_regs_araddr  : std_logic_vector(s_axi_addr_width - 1 downto 0);
    signal s_axi_regs_arprot  : std_logic_vector(2 downto 0);
    signal s_axi_regs_arvalid : std_logic;
    signal s_axi_regs_arready : std_logic;
    signal s_axi_regs_rdata   : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal s_axi_regs_rresp   : std_logic_vector(1 downto 0);
    signal s_axi_regs_rvalid  : std_logic;
    signal s_axi_regs_rready  : std_logic;

    -- Signals for AXI read/write transaction handshake
    signal sendItRegs : std_logic := '0';
    signal readItRegs : std_logic := '0';

    ----------------------------------------------------------------------------
    -- General testbench data
    ----------------------------------------------------------------------------
    -- Create a shared variable to store the test input data
    constant input_data_path         : string := test_data_path & "input_data.tv";
    shared variable input_data_array : slv32_array(0 to tv_data_width - 1);

    -- Test vectors array definition
    type int_arr is array(natural range <>) of integer;

    -- Test states
    type test_state is (
        init,
        tc1_name_of_test
        );
    signal testcase : test_state := init;

    -- Register addresses
    constant num_samples_addr : std_logic_vector(s_axi_addr_width - 1 downto 0) := "000100";  -- 0x04
    constant enable_send_addr : std_logic_vector(s_axi_addr_width - 1 downto 0) := "001000";  -- 0x08


    ----------------------------------------------------------------------------
    -- Testcase 1 parameters
    ----------------------------------------------------------------------------
    signal countSamples         : boolean := false;
    shared variable numSamples  : integer := 0;
    shared variable tc1_num_err : integer := 0;
    constant tc1_num_cases      : integer := 3;
    constant tc1_samples : int_arr := (
        2**10, 2**11, 2**12
        );

    ----------------------------------------------------------------------------
    -- Variables for final report
    ----------------------------------------------------------------------------
    shared variable total_tc      : integer := 0;
    shared variable total_tc_err  : integer := 0;
    shared variable total_tc_pass : integer := 0;

begin
    ----------------------------------------------------------------------------
    -- Module instantiation section starts here
    ----------------------------------------------------------------------------



    ----------------------------------------------------------------------------
    -- Generate clock and start AXI handshake processes
    ----------------------------------------------------------------------------
    -- Generate reference clock
    GenerateClock(aclk, clk_period, aclk_gen_enable);

    -- AXI read/write transaction handshake for slave registers
    AXIWriteHandshake(aclk, sendItRegs, s_axi_regs_awvalid, s_axi_regs_awready, s_axi_regs_wvalid, s_axi_regs_wready, s_axi_regs_bvalid, s_axi_regs_bready, s_axi_regs_bresp);
    AXIReadHandshake(aclk, readItRegs, s_axi_regs_arvalid, s_axi_regs_arready, s_axi_regs_rvalid, s_axi_regs_rready);

    ----------------------------------------------------------------------------
    -- Testbench processes section:
    --     Here we define the processes for each testcase if needed, that will
    --     be executed parallelly with the main testbench process. This is
    --     useful for testcases that require a specific sequence of operations,
    --     such as counting data packages, measuring latency, etc.
    ----------------------------------------------------------------------------
    -- EXAMPLE PROCESS, DELETE IF NOT NEEDED
    COUNT_SAMPLES : process (s_axi_regs_rvalid)
    begin
        if (countSamples) and rising_edge(s_axi_regs_rvalid) then
            numSamples := numSamples + 1;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Testbench starts here
    ----------------------------------------------------------------------------
    MAIN_TESTBENCH : process
    begin
        ------------------------------------------------------------------------
        -- Initialization: Load reference signals to IP internal BRAM
        ------------------------------------------------------------------------
        PrintEmptyLines(3);
        Print("Initializing testbench...", sep_up);
        PrintEmptyLines(1);

        Print("Reset module and AXI components...", sep_up, sep_line_len/2);
        -- Reset DUT and AXI components
        SystemReset(rstn, s_axi_aresetn);
        -- Waiting prevents the simulation from starting automatically
        wait for init_period;
        Print("...Done resetting module and AXI components!", sep_down, sep_line_len/2);
        PrintEmptyLines(1);

        -- Copy test data to array
        Print("Reading test vectors...", sep_up, sep_line_len/2);
        read_8_char_hex_file(input_data_path, input_data_array);
        Print("...Done reading test vectors, enable verbose mode for more information!", sep_down, sep_line_len/2);
        PrintEmptyLines(1);

        Print("Testbench initialization completed!", sep_down);

        ------------------------------------------------------------------------
        -- Testcase 1: This is an example testcase, only serves to show how a
        -- self checking testcase can be implemented. This testcase counts the
        -- number of data packages received by the module.
        ------------------------------------------------------------------------
        -- This is only an example testcase
        Print("Testcase 1: Count number of data packages.", sep_up);
        total_tc := total_tc + 1;
        testcase <= tc1_name_of_test;

        -- Disable module by holding reset signal
        rstn <= (others => '0');

        for i in 0 to (tc1_num_cases - 1) loop
            -- Write into register the amount of samples to be sent
            AXIWrite(num_samples_addr, Int2Slv(tc1_samples(i), 32), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
            wait for aclk_period;

            -- Assert flag to start process that monitors the number of samples
            countSamples <= true;

            -- Apply changes by resetting the module
            moduleReset(rstn, reset_index);

            -- Wait for a specified amount of time or other condition to
            -- deassert the flag, here we wait for given time span.
            -- Depending on your module you can use different conditions to
            -- deassert the flag, such as a specific number of samples received,
            -- or wait for a specific signal such as m_axis_tlast ...
            wait for 10 * tc1_samples(i) * aclk_period;
            countSamples <= false;

            if (numSamples = tc1_samples(i)) then
                tc1_num_err := tc1_num_err + 1;
            end if;
        end loop;

        -- Testcase 1 evaluation
        if (0 = tc1_num_err) then
            total_tc_pass := total_tc_pass + 1;
            report "The number of samples received is correct!";
        else
            report "The number of samples received is incorrect: Received " & integer'image(numSamples) & " | Expected " & integer'image(tc1_samples(i));
        end if;

        wait for testcase_to_finish;
        Print("Testcase completed!", sep_down);
        PrintEmptyLines(2);

        ------------------------------------------------------------------------
        -- Final report
        ------------------------------------------------------------------------
        -- Stop simulation
        aclk_gen_enable <= false;

        -- Print final report
        total_tc_err := tc1_num_err;


        PrintEmptyLines(2);
        Print("Final report:", sep_up);

        if (0 = total_tc_err) then
            TestbenchPassed;
        else
            TestbenchFailed;
            Print("Errors encountered: " & integer'image(total_tc_err));
        end if;

        Print("Testcases passed: " & integer'image(total_tc_pass) & "/" & integer'image(total_tc), sep_down);
        wait;

    end process;

end architecture sim;

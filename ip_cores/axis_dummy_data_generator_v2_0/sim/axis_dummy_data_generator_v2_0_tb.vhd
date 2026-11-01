--------------------------------------------------------------------------------
-- WARNING: Testbench has issues running with Vivado 2020.1
--          Vivado 2023.2 is recommended for running this testbench.
--
--          The BRAM testcases are not meant to be run with zero sample delay,
--          since some of the test evaluation processes are reliant on the
--          transistions of clock cycles. Feel free to modify them so that they
--          are able to run with zero sample delay.
--------------------------------------------------------------------------------

-- Import ieee and standard library
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use ieee.math_real.all;
library std;
use std.textio.all;
-- Import custom library
use work.tb_utils_pkg.all;

entity axis_test_pattern_generator_v2_0_tb is
    generic (
        -- General parameters
        reset_width              : natural := 1;
        reset_index              : natural := 0;
        -- BRAM parameters
        int_bram_depth           : natural := 16384;
        int_bram_width           : natural := 32;
        int_bram_ctrl_addr_width : natural := clogb2(int_bram_depth * (int_bram_width / 8));  -- don't use clogb2 in synthesis
        int_bram_addr_offset     : natural := clogb2(int_bram_width / 8);  -- don't use clogb2 in synthesis
        -- AXI slave interface parameters
        s_axi_data_width         : natural := 32;
        s_axi_addr_width         : natural := 6;
        -- AXIS master interface parameters
        m_axis_tdata_width       : natural := 32;
        -- Path to the repository, used to locate the test vectors.
        -- Set by scripts/core_sim.tcl when the simulation project is created.
        repo_path                : string  := "."
        );
end;

architecture bench of axis_test_pattern_generator_v2_0_tb is
    ----------------------------------------------------------------------------
    -- Location of the test vectors, repo_path is a generic
    constant test_path      : string  := "/ip_cores/axis_dummy_data_generator_v2_0/sim/test_data/";
    constant test_data_path : string  := repo_path & test_path;
    -- Adjust this value according to your test data size
    constant bram_data_size : integer := 16384;
    ----------------------------------------------------------------------------

    -- DUT signals
    constant aclk_period   : time                                       := 8 ns;
    signal aclk            : std_logic                                  := '0';
    signal aclk_gen_enable : boolean                                    := true;
    signal s_axi_aresetn   : std_logic                                  := '1';
    signal rstn            : std_logic_vector(reset_width - 1 downto 0) := (others => '1');
    alias rst              : std_logic is rstn(reset_index);

    -- AXI slave signals for register access
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

    -- AXI BRAM controller ports
    signal s_axi_bram_awaddr  : std_logic_vector(int_bram_ctrl_addr_width - 1 downto 0);
    signal s_axi_bram_awprot  : std_logic_vector(2 downto 0);
    signal s_axi_bram_awvalid : std_logic;
    signal s_axi_bram_awready : std_logic;
    signal s_axi_bram_wdata   : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal s_axi_bram_wstrb   : std_logic_vector((s_axi_data_width/8) - 1 downto 0);
    signal s_axi_bram_wvalid  : std_logic;
    signal s_axi_bram_wready  : std_logic;
    signal s_axi_bram_bresp   : std_logic_vector(1 downto 0);
    signal s_axi_bram_bvalid  : std_logic;
    signal s_axi_bram_bready  : std_logic;
    signal s_axi_bram_araddr  : std_logic_vector(int_bram_ctrl_addr_width - 1 downto 0);
    signal s_axi_bram_arprot  : std_logic_vector(2 downto 0);
    signal s_axi_bram_arvalid : std_logic;
    signal s_axi_bram_arready : std_logic;
    signal s_axi_bram_rdata   : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal s_axi_bram_rresp   : std_logic_vector(1 downto 0);
    signal s_axi_bram_rvalid  : std_logic;
    signal s_axi_bram_rready  : std_logic;

    -- AXI-Stream Master (connected to RP-DAC-Interface)
    signal m_axis_tvalid : std_logic;
    signal m_axis_tdata  : std_logic_vector(m_axis_tdata_width - 1 downto 0);
    signal m_axis_tready : std_logic := '1';  --rp slave is always ready to receiver new data

    -- Debug AXI-Stream Master signals
    signal debug_m_axis_tvalid : std_logic;
    signal debug_m_axis_tdata  : std_logic_vector(m_axis_tdata_width - 1 downto 0);
    signal debug_m_axis_tready : std_logic := '1';  --rp slave is always ready to receiver new data

    -- Data input
    signal test_data_input : std_logic_vector(s_axi_data_width - 1 downto 0);

    -- AXI read/write flags
    signal sendItRegs : std_logic := '0';
    signal readItRegs : std_logic := '0';
    signal sendItBRAM : std_logic := '0';
    signal readItBRAM : std_logic := '0';

    -- Slave register address
    constant mode_addr             : std_logic_vector(s_axi_addr_width - 1 downto 0) := "000000";  --0x00
    constant sample_delay_addr     : std_logic_vector(s_axi_addr_width - 1 downto 0) := "000100";  --0x04
    constant cnt_max_value_addr    : std_logic_vector(s_axi_addr_width - 1 downto 0) := "001000";  --0x08
    constant max_samples_addr      : std_logic_vector(s_axi_addr_width - 1 downto 0) := "001100";  --0x0C
    constant transaction_done_addr : std_logic_vector(s_axi_addr_width - 1 downto 0) := "010000";  --0x10
    constant bram_max_addr_addr    : std_logic_vector(s_axi_addr_width - 1 downto 0) := "010100";  --0x14

    -- Dummy Data Generator modes
    constant bram_counter_mode          : std_logic_vector(s_axi_data_width - 1 downto 0) := (0      => '0', 1 => '1', others => '0');
    constant bram_continuous_mode       : std_logic_vector(s_axi_data_width - 1 downto 0) := (0      => '1', 1 => '1', others => '0');
    constant bram_continuous_mode_debug : std_logic_vector(s_axi_data_width - 1 downto 0) := (0      => '1', 1 => '1', 2 => '1', others => '0');
    constant continuous_mode            : std_logic_vector(s_axi_data_width - 1 downto 0) := (0      => '1', others => '0');
    constant counter_mode               : std_logic_vector(s_axi_data_width - 1 downto 0) := (others => '0');

    ----------------------------------------------------------------------------
    -- General testbench data
    ----------------------------------------------------------------------------
    -- Test vectors array definition
    type addr_arr is array(natural range <>) of std_logic_vector(s_axi_addr_width - 1 downto 0);
    type bram_addr_arr is array(natural range <>) of std_logic_vector(int_bram_ctrl_addr_width - 1 downto 0);
    type data_arr is array(natural range <>) of std_logic_vector(s_axi_data_width - 1 downto 0);
    type int_arr is array(natural range <>) of integer;

    -- Read data from file
    constant mixer_input_data_path   : string  := test_data_path & "input_data.tv";
    constant input_data_array_offset : integer := 4;
    shared variable input_data_array : slv32_array(0 to int_bram_depth - 1);

    -- Test states
    type t_state is (
        init,
        register_test,
        cnt_max_value_test,
        sample_delay_test,
        max_sample_test,
        mode_test,
        bram_mode_axi_test,
        bram_continuous_mode_test,
        bram_counter_mode_test,
        debug_port_test,
        bram_max_addr_test,
        done_testing
        );
    signal testcase : t_state := init;

    -- BRAM parameters


    shared variable total_tc        : integer := 0;
    shared variable total_tc_passed : integer := 0;
    shared variable total_err       : integer := 0;

    ----------------------------------------------------------------------------
    -- Data for testcase 1 (register test)
    ----------------------------------------------------------------------------
    shared variable numErrorsRegTest    : integer := 0;
    shared variable numErrorsCntMaxTest : integer := 0;
    constant num_reg_testcases          : integer := 5;
    constant addr_reg_test : addr_arr := (
        mode_addr, sample_delay_addr, cnt_max_value_addr, max_samples_addr, transaction_done_addr
        );
    constant data_reg_test : data_arr := (
        X"00000000", X"00000001", X"00000002", X"00000003", X"00000004"
        );

    ----------------------------------------------------------------------------
    -- Data for testcase 2 & 3 (cnt_max_value & max_samples)
    ----------------------------------------------------------------------------
    shared variable extraSamples           : integer := 5;
    shared variable numErrorsMaxSampleTest : integer := 0;
    constant num_cnt_max_testcases         : integer := 4;
    constant data_cnt_max_test : int_arr := (
        2 ** 4,                         -- 15
        2 ** 10,                        -- 1023
        2 ** 12,                        -- 4095
        2 ** 14                         -- 16381 (max value)
        );
    constant cnt_return_value       : integer := 0;
    constant testcase2_sample_delay : integer := 2;
    -- Variable and flags
    shared variable numSamples      : integer := 0;
    signal cnt_return_to_init_val   : boolean := false;
    signal check_return_to_init_val : boolean := false;
    signal countSamples             : boolean := false;

    ----------------------------------------------------------------------------
    -- Data for testcase 4 (sample_delay)
    ----------------------------------------------------------------------------
    shared variable numErrorsSampleDelay : integer := 0;
    constant testcase4_num_cases         : integer := 4;
    constant testcase4_max_samples       : integer := 5;
    constant testcase4_cnt_max_value     : integer := 2 ** 14;
    constant testcase4_sample_delay : int_arr := (
        --0, 1, 10, 100, 1000
        1, 10, 100, 200
        );
    -- Variables and flags
    shared variable testcase4_num_delay : integer := 0;
    signal testcase4_count_delay        : boolean := false;

    ----------------------------------------------------------------------------
    -- Data for testcase 5 (mode test)
    ----------------------------------------------------------------------------
    shared variable numErrorsDelay           : integer                                         := 0;
    shared variable numErrorsModeTest        : integer                                         := 0;
    constant testcase5_max_samples           : integer                                         := 2 ** 5;
    constant testcase5_cnt_max_value         : integer                                         := 2 ** 5;
    constant testcase5_num_cases             : integer                                         := 2;
    constant testcase5_sample_delay          : int_arr                                         := (2, 1);
    -- constants as vector
    constant testcase5_max_samples_vector    : std_logic_vector(s_axi_data_width - 1 downto 0) := std_logic_vector(to_unsigned(testcase5_max_samples, s_axi_data_width));
    constant testcase5_cnt_max_value_vector  : std_logic_vector(s_axi_data_width - 1 downto 0) := std_logic_vector(to_unsigned(testcase5_cnt_max_value, s_axi_data_width));
    -- Variables and flags
    signal testcase5_check_tdata             : boolean                                         := false;
    signal testcase5_count_samples           : boolean                                         := false;
    shared variable testcase5_sample_counter : integer                                         := 0;

    ----------------------------------------------------------------------------
    -- Data for testcase 6 (BRAM AXI read/write test)
    ----------------------------------------------------------------------------
    shared variable numErrorsBRAMAXI    : integer := 0;
    constant testcase6_max_shown_errors : integer := 10;
    constant testcase6_num_data         : integer := 5;


    ----------------------------------------------------------------------------
    -- Data for testcase 7 (BRAM continuous mode test)
    ----------------------------------------------------------------------------
    shared variable numErrorsBRAMContinuous     : integer := 0;
    shared variable ErrorBRAMContinuousSubtest1 : integer := 0;
    constant bram_max_addr_subtest_1            : integer := bram_data_size;
    shared variable ErrorBRAMContinuousSubtest2 : integer := 0;
    constant bram_max_addr_subtest_2            : integer := 10;
    shared variable testcase7_sample_counter    : integer := 0;
    signal testcase7_count_samples              : boolean := false;
    constant testcase7_max_samples              : integer := 2 ** 5;
    constant testcase7_sample_delay             : integer := 2;


    ----------------------------------------------------------------------------
    -- Data for testcase 8 (BRAM counter mode test)
    ----------------------------------------------------------------------------
    shared variable numErrorsBRAMCounter     : integer := 0;
    shared variable testcase8_sample_counter : integer := 1;
    signal testcase8_count_samples           : boolean := false;
    constant testcase8_max_samples           : integer := 2 ** 2;
    constant testcase8_sample_delay          : integer := 2;

    ----------------------------------------------------------------------------
    -- Data for testcase 9 (Debug port test) this is a repeat of testcase 7
    ----------------------------------------------------------------------------
    shared variable numErrorsDebugPort       : integer := 0;
    shared variable testcase9_sample_counter : integer := 0;
    signal testcase9_count_samples           : boolean := false;


begin
    ------------------------------------------------------------------------------
    -- Instantiating device unter test
    ------------------------------------------------------------------------------
    DUT : entity work.axis_dummy_data_generator
        generic map(
            reset_width              => reset_width,
            reset_index              => reset_index,
            int_bram_depth           => int_bram_depth,
            int_bram_ctrl_addr_width => int_bram_ctrl_addr_width,
            int_bram_addr_offset     => int_bram_addr_offset
            )
        port map(
            aclk                => aclk,
            rstn                => rstn,
            s_axi_aresetn       => s_axi_aresetn,
            -- AXI slave ports
            s_axi_regs_awaddr   => s_axi_regs_awaddr,
            s_axi_regs_awprot   => s_axi_regs_awprot,
            s_axi_regs_awvalid  => s_axi_regs_awvalid,
            s_axi_regs_awready  => s_axi_regs_awready,
            s_axi_regs_wdata    => s_axi_regs_wdata,
            s_axi_regs_wstrb    => s_axi_regs_wstrb,
            s_axi_regs_wvalid   => s_axi_regs_wvalid,
            s_axi_regs_wready   => s_axi_regs_wready,
            s_axi_regs_bresp    => s_axi_regs_bresp,
            s_axi_regs_bvalid   => s_axi_regs_bvalid,
            s_axi_regs_bready   => s_axi_regs_bready,
            s_axi_regs_araddr   => s_axi_regs_araddr,
            s_axi_regs_arprot   => s_axi_regs_arprot,
            s_axi_regs_arvalid  => s_axi_regs_arvalid,
            s_axi_regs_arready  => s_axi_regs_arready,
            s_axi_regs_rdata    => s_axi_regs_rdata,
            s_axi_regs_rresp    => s_axi_regs_rresp,
            s_axi_regs_rvalid   => s_axi_regs_rvalid,
            s_axi_regs_rready   => s_axi_regs_rready,
            -- AXI BRAM controller ports
            s_axi_bram_awaddr   => s_axi_bram_awaddr,
            s_axi_bram_awprot   => s_axi_bram_awprot,
            s_axi_bram_awvalid  => s_axi_bram_awvalid,
            s_axi_bram_awready  => s_axi_bram_awready,
            s_axi_bram_wdata    => s_axi_bram_wdata,
            s_axi_bram_wstrb    => s_axi_bram_wstrb,
            s_axi_bram_wvalid   => s_axi_bram_wvalid,
            s_axi_bram_wready   => s_axi_bram_wready,
            s_axi_bram_bresp    => s_axi_bram_bresp,
            s_axi_bram_bvalid   => s_axi_bram_bvalid,
            s_axi_bram_bready   => s_axi_bram_bready,
            s_axi_bram_araddr   => s_axi_bram_araddr,
            s_axi_bram_arprot   => s_axi_bram_arprot,
            s_axi_bram_arvalid  => s_axi_bram_arvalid,
            s_axi_bram_arready  => s_axi_bram_arready,
            s_axi_bram_rdata    => s_axi_bram_rdata,
            s_axi_bram_rresp    => s_axi_bram_rresp,
            s_axi_bram_rvalid   => s_axi_bram_rvalid,
            s_axi_bram_rready   => s_axi_bram_rready,
            -- AXI-Stream master ports
            m_axis_tvalid       => m_axis_tvalid,
            m_axis_tdata        => m_axis_tdata,
            m_axis_tready       => m_axis_tready,
            -- Debug AXI-Stream master ports
            debug_m_axis_tvalid => debug_m_axis_tvalid,
            debug_m_axis_tdata  => debug_m_axis_tdata,
            debug_m_axis_tready => debug_m_axis_tready
            );

    ----------------------------------------------------------------------------
    -- Start testbench related precesses
    ----------------------------------------------------------------------------
    -- Generate reference clock
    GenerateClock(aclk, aclk_period, aclk_gen_enable);

    -- AXI read/write transaction handshake for slave registers
    AXIWriteHandshake(aclk, sendItRegs, s_axi_regs_awvalid, s_axi_regs_awready, s_axi_regs_wvalid, s_axi_regs_wready, s_axi_regs_bvalid, s_axi_regs_bready, s_axi_regs_bresp);
    AXIReadHandshake(aclk, readItRegs, s_axi_regs_arvalid, s_axi_regs_arready, s_axi_regs_rvalid, s_axi_regs_rready);

    -- AXI read/write transaction handshake for BRAM
    AXIWriteHandshake(aclk, sendItBRAM, s_axi_bram_awvalid, s_axi_bram_awready, s_axi_bram_wvalid, s_axi_bram_wready, s_axi_bram_bvalid, s_axi_bram_bready, s_axi_bram_bresp);
    AXIReadHandshake(aclk, readItBRAM, s_axi_bram_arvalid, s_axi_bram_arready, s_axi_bram_rvalid, s_axi_bram_rready);

    ------------------------------------------------------------------------------
    -- Process for counting samples
    ------------------------------------------------------------------------------

    COUNT_SAMPLES : process (m_axis_tvalid)
    begin
        if (countSamples) and rising_edge(m_axis_tvalid) then
            numSamples := numSamples + 1;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- Process for counting clock cycles
    ------------------------------------------------------------------------------

    COUNT_DELAY : process (aclk)
    begin
        if (testcase4_count_delay) and rising_edge(aclk) then
            testcase4_num_delay := testcase4_num_delay + 1;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- Process for counting samples in continuous mode (testcase 5)
    ------------------------------------------------------------------------------

    COUNT_SAMPLES_CONTINUOUS : process (m_axis_tdata)
    begin
        if (testcase5_count_samples = true) then
            testcase5_sample_counter := testcase5_sample_counter + 1;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- Process for counting samples in BRAM continuous mode (testcase 7)
    ------------------------------------------------------------------------------

    COUNT_SAMPLES_BRAM_CONTINUOUS_MODE : process (m_axis_tvalid)
    begin
        if rising_edge(m_axis_tvalid) then
            if (testcase7_count_samples = true) then
                testcase7_sample_counter := testcase7_sample_counter + 1;
            else
                testcase7_sample_counter := 0;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- Process for counting samples in BRAM counter mode (testcase 8)
    ------------------------------------------------------------------------------

    COUNT_SAMPLES_BRAM_COUNTER_MODE : process (m_axis_tvalid)
    begin
        if (testcase8_count_samples = true and rising_edge(m_axis_tvalid)) then
            testcase8_sample_counter := testcase8_sample_counter + 1;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- Process for counting samples in BRAM continuous mode (testcase 9)
    ------------------------------------------------------------------------------

    COUNT_SAMPLES_BRAM_CONTINUOUS_MODE_TC9 : process (debug_m_axis_tvalid)
    begin
        if rising_edge(debug_m_axis_tvalid) then
            if (testcase9_count_samples = true) then
                testcase9_sample_counter := testcase9_sample_counter + 1;
            else
                testcase9_sample_counter := 0;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------------
    -- Start testbench
    ------------------------------------------------------------------------------

    TESTBENCH : process
    begin
        ------------------------------------------------------------------------
        -- Initialization
        ------------------------------------------------------------------------
        PrintEmptyLines(3);
        Print("Initializing testbench...", sep_up);
        PrintEmptyLines(1);

        -- Copy test data to array
        Print("Reading test vectors...", sep_up, sep_line_len/2);
        read_8_char_hex_file(mixer_input_data_path, input_data_array);
        Print("...Done reading test vectors, enable verbose mode for more information!", sep_down, sep_line_len/2);
        PrintEmptyLines(1);

        -- Reset module and AXI components
        Print("Reset module and AXI components...", sep_up, sep_line_len/2);
        ResetSystem(rstn, s_axi_aresetn);
        Print("...Done resetting module and AXI components!", sep_down, sep_line_len/2);
        PrintEmptyLines(1);

        -- Init all slave registers with zeros, and apply setting by toogling reset
        Print("Initialize all slave registers with zeros...", sep_up, sep_line_len/2);
        AXIWrite(mode_addr, counter_mode, aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        AXIWrite(sample_delay_addr, std_logic_vector(to_unsigned(0, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        AXIWrite(cnt_max_value_addr, std_logic_vector(to_unsigned(0, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        AXIWrite(max_samples_addr, std_logic_vector(to_unsigned(0, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        ToogleStdLogic(rst, aclk_period);
        Print("...Done initializing slave registers!", sep_down, sep_line_len/2);
        PrintEmptyLines(1);

        -- Waiting prevents the simulation from starting automatically
        wait for init_period;
        Print("Testbench initialization completed!", sep_down);
        PrintEmptyLines(2);

        ----------------------------------------------------------------------------
        -- Testcase 1
        ----------------------------------------------------------------------------
        Print("Testcase 1: Check if AXI slave registers are correctly implemented.", sep_up);
        total_tc := total_tc + 1;
        testcase <= register_test;

        for i in 0 to (num_reg_testcases - 1) loop
            -- Write into register and wait for 1 clock cycle to read from register
            AXIWrite(addr_reg_test(i), data_reg_test(i), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
            wait for aclk_period;
            AXIRead(addr_reg_test(i), aclk_period, readItRegs, s_axi_regs_araddr, s_axi_regs_rvalid);

            if ((num_reg_testcases - 1) > i) then
                -- These registers can be written via software (AXI bus)
                if (data_reg_test(i) /= s_axi_regs_rdata) then
                    Print("Error: Wrong data coming from module! Received: 0x" & Slv2HexStr(s_axi_regs_rdata) & " | Expected: 0x" & Slv2HexStr(data_reg_test(i)));
                    numErrorsRegTest := numErrorsRegTest + 1;
                end if;
            else
                if (data_reg_test(i) = s_axi_regs_rdata) then
                    Print("This register is only writable via hardware, writing via software should have no effect!");
                    numErrorsRegTest := numErrorsRegTest + 1;
                end if;
            end if;
        end loop;

        -- Testcase 1 evaluation
        if (0 = numErrorsRegTest) then
            total_tc_passed := total_tc_passed + 1;
            report "Register test successful!";
        else
            report "Register test failed: " & integer'image(numErrorsRegTest) & " errors detected!";
        end if;

        wait for testcase_to_finish;
        Print("Testcase completed!", sep_down);
        PrintEmptyLines(2);

        ----------------------------------------------------------------------------
        -- Testcase 2: Testcase 3 runs simultaniously with testcase 2
        ----------------------------------------------------------------------------
        Print("Testcase 2: Check if module increments data values correctly.", sep_up);
        total_tc := total_tc + 1;
        testcase <= cnt_max_value_test;

        -- Disable module
        rstn <= (others => '0');

        -- Sample delay is the same for all partial tests
        --AXIWriteRegister(sample_delay_addr, std_logic_vector(to_unsigned(1, 32)), s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid, sendItRegs);
        AXIWrite(sample_delay_addr, std_logic_vector(to_unsigned(testcase2_sample_delay, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);

        for i in 0 to (num_cnt_max_testcases - 1) loop
            -- Reset test variables and signals
            cnt_return_to_init_val   <= false;
            check_return_to_init_val <= false;
            numSamples               := 0;

            -- Write cnt_max_value and max_samples into register, data output should return to initial value, once max_sample is reached
            AXIWrite(mode_addr, counter_mode, aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
            AXIWrite(cnt_max_value_addr, std_logic_vector(to_unsigned(data_cnt_max_test(i), 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
            AXIWrite(max_samples_addr, std_logic_vector(to_unsigned(data_cnt_max_test(i) + extraSamples, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);

            ResetModule(rstn, reset_index);
            -- Raise flag to enable counting of samples
            countSamples <= true;

            loop
                -- Set flag to signalise that counter has reached maximum value or not
                if (std_logic_vector(to_unsigned(cnt_return_value, 32)) <= m_axis_tdata) then
                    check_return_to_init_val <= true;
                else
                    check_return_to_init_val <= false;
                end if;

                case check_return_to_init_val is
                    when true =>
                        if (std_logic_vector(to_unsigned(cnt_return_value, 32)) = m_axis_tdata) then
                            -- This flag will remain true for test evaluation
                            -- Flag will be cleared with next test
                            cnt_return_to_init_val <= true;
                        end if;

                    when others => null;
                end case;

                -- Polling for transaction_done signal
                AXIRead(transaction_done_addr, aclk_period, readItRegs, s_axi_regs_araddr, s_axi_regs_rvalid);
                exit when s_axi_regs_rdata = X"00000001";
            end loop;

            -- Evaluate partial result
            if (false = cnt_return_to_init_val) then
                Print("Counter did not return to initial value after reaching maximum value (max_val = " & integer'image(data_cnt_max_test(i)) & ")!");
                numErrorsCntMaxTest := numErrorsCntMaxTest + 1;
            end if;

            if ((data_cnt_max_test(i) + extraSamples) /= numSamples) then
                Print("Amount of output samples did not match with maximum samples! Received: " & integer'image(numSamples) & " | Expected: " & integer'image(data_cnt_max_test(i) + extraSamples));
                numErrorsMaxSampleTest := numErrorsMaxSampleTest + 1;
            end if;

            -- Clear flag to disable counting of samples
            countSamples <= false;

        end loop;

        -- Testcase 2 evaluation
        if (0 = numErrorsCntMaxTest) then
            total_tc_passed := total_tc_passed + 1;
            report "Maximum counter value test passed!";
        else
            report "Maximum counter value test failed: " & integer'image(numErrorsCntMaxTest) & " errors detected!";
        end if;

        wait for testcase_to_finish;
        Print("Testcase completed!", sep_down);
        PrintEmptyLines(2);

        ----------------------------------------------------------------------------
        -- Testcase 3: Only evaluation of this testcase is done here
        ----------------------------------------------------------------------------
        Print("Testcase 3: Check if module ends transmission after sending the configured amount of samples.", sep_up);
        total_tc := total_tc + 1;
        testcase <= max_sample_test;

        if (0 = numErrorsMaxSampleTest) then
            total_tc_passed := total_tc_passed + 1;
            report "Maximum sample test passed!";
        else
            report "Maximum sample test failed: " & integer'image(numErrorsMaxSampleTest) & " errors detected!";
        end if;

        wait for testcase_to_finish;
        Print("Testcase completed!", sep_down);
        PrintEmptyLines(2);

        ----------------------------------------------------------------------------
        -- Testcase 4: Check if delay between samples is correct.
        ----------------------------------------------------------------------------
        Print("Testcase 4: Check if delay between two samples are correct.", sep_up);
        total_tc := total_tc + 1;
        testcase <= sample_delay_test;

        -- Disable flags from testcase 3
        cnt_return_to_init_val   <= false;
        check_return_to_init_val <= false;

        -- Configure counter max value and max samples, and mode
        AXIWrite(cnt_max_value_addr, std_logic_vector(to_unsigned(testcase4_cnt_max_value, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        AXIWrite(max_samples_addr, std_logic_vector(to_unsigned(testcase4_max_samples, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        AXIWrite(mode_addr, counter_mode, aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);

        -- AXIWriteRegister(cnt_max_value_addr, std_logic_vector(to_unsigned(testcase4_cnt_max_value, 32)), s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid, sendItRegs);
        -- AXIWriteRegister(max_samples_addr, std_logic_vector(to_unsigned(testcase4_max_samples, 32)), s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid, sendItRegs);
        -- AXIWriteRegister(mode_addr, counter_mode, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid, sendItRegs);

        for i in 0 to (testcase4_num_cases - 1) loop
            -- Reset test variables
            testcase4_num_delay := 0;
            if (1 /= testcase4_sample_delay(i)) then
                -- Write value into sample delay register
                AXIWrite(sample_delay_addr, std_logic_vector(to_unsigned(testcase4_sample_delay(i), 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
                -- Apply config by resetting module
                ResetModule(rstn, reset_index);
                -- Update s_axi_regs_rdata output It should be X"00000000" at this
                AXIRead(transaction_done_addr, aclk_period, readItRegs, s_axi_regs_araddr, s_axi_regs_rvalid);

                -- Start counting sample delay
                wait until (m_axis_tvalid = '1');
                testcase4_count_delay <= true;
                wait until (m_axis_tvalid = '0');
                wait until (m_axis_tvalid = '1');
                testcase4_count_delay <= false;


                if (testcase4_sample_delay(i) /= testcase4_num_delay) then
                    Print("Sample delay: " & integer'image(testcase4_sample_delay(i)));
                    Print("The amount of delays (in clock cycles) does not match with configured delay value: testcase4_num_delay = " & integer'image(testcase4_num_delay) & " (expected: " & integer'image(testcase4_sample_delay(i)) & ")");
                    numErrorsSampleDelay := numErrorsSampleDelay + 1;
                end if;

            else
                -- Special case since there is no delay -> tvalid is remain asserted until transmission is done
                -- Write value into sample delay register
                AXIWrite(sample_delay_addr, std_logic_vector(to_unsigned(testcase4_sample_delay(i), 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
                -- Apply config by resetting module
                ResetModule(rstn, reset_index);

                -- Start counting sample delay
                wait until (m_axis_tvalid = '1');
                testcase4_count_delay <= true;
                wait until (m_axis_tvalid = '0');
                testcase4_count_delay <= false;

                -- Here testcase4_num_delay is use to count the amount of samples
                -- during the period where tvalid is constantly asserted
                if (testcase4_max_samples /= testcase4_num_delay) then
                    Print("Sample delay: " & integer'image(testcase4_sample_delay(i)));
                    Print("The duration of tvalid signal does not match with maximum sample value: tvalid_duration = " & integer'image(testcase4_num_delay) & " (expected: " & integer'image(testcase4_max_samples) & ")");
                    numErrorsSampleDelay := numErrorsSampleDelay + 1;
                end if;

            end if;

            loop
                -- Polling for transaction_done signal
                AXIRead(transaction_done_addr, aclk_period, readItRegs, s_axi_regs_araddr, s_axi_regs_rvalid);
                exit when s_axi_regs_rdata = X"00000001";
            end loop;

        end loop;

        -- Testcase 4 evaluation
        if (0 = numErrorsSampleDelay) then
            total_tc_passed := total_tc_passed + 1;
            report "Sample delay test passed!";
        else
            report "Sample delay test failed: " & integer'image(numErrorsSampleDelay) & " errors detected!";
        end if;

        wait for testcase_to_finish;
        Print("Testcase completed!", sep_down);
        PrintEmptyLines(2);

        ----------------------------------------------------------------------------
        -- Testcase 5
        ----------------------------------------------------------------------------
        Print("Testcase 5: Check if module runs continuously even after max_samples is reached."
              & "Test is repeated for two cases: outputting data with zero delay or with delay of n clock cycles.", sep_up);
        total_tc := total_tc + 1;
        testcase <= mode_test;

        -- Disable module
        rstn <= (others => '0');

        -- Configure dummy data generator
        AXIWrite(mode_addr, continuous_mode, aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        AXIWrite(max_samples_addr, std_logic_vector(to_unsigned(testcase5_max_samples, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        AXIWrite(cnt_max_value_addr, std_logic_vector(to_unsigned(testcase5_cnt_max_value, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);

        for i in 0 to (testcase5_num_cases - 1) loop
            -- Disable module
            rstn <= (others => '0');

            -- Reset test variables and flags
            numErrorsDelay          := 0;
            testcase5_count_samples <= true;

            -- Set sample delay and apply config by resetting module
            AXIWrite(sample_delay_addr, std_logic_vector(to_unsigned(testcase5_sample_delay(i), 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
            ResetModule(rstn, reset_index);

            -- Wait so that module can continue outputting data, 10 * aclk_period is more than sufficient to cover for sample delay of 1
            wait for ((testcase5_max_samples * 10) * aclk_period);

            -- Polling for transaction_done signal and check if dummy data generator has stopped
            -- outputting data, which it should not while in continuous mode
            AXIRead(transaction_done_addr, aclk_period, readItRegs, s_axi_regs_araddr, s_axi_regs_rvalid);
            if X"00000001" = s_axi_regs_rdata then
                Print("Data output should not stop at on its own!");
                numErrorsDelay := numErrorsDelay + 1;
            end if;

            -- Check if data output stops at maximum value or continue running
            if (testcase5_max_samples = testcase5_sample_counter) then
                Print("Data output should not stop at maximum value!");
                numErrorsDelay := numErrorsDelay + 1;
            end if;

            if (numErrorsDelay > 0) then
                Print("Continuous mode failed for sample delay: " & integer'image(testcase5_sample_delay(i)));
                numErrorsModeTest := numErrorsModeTest + 1;
            end if;

            -- Disable counting of samples
            testcase5_count_samples <= false;
        end loop;

        -- Testcase 5 evaluation
        if (0 = numErrorsModeTest) then
            total_tc_passed := total_tc_passed + 1;
            report "Continuous mode test passed!";
        else
            report "Continuous mode test failed: " & integer'image(numErrorsModeTest) & " errors detected!";
        end if;

        wait for testcase_to_finish;
        Print("Testcase completed!", sep_down);
        PrintEmptyLines(2);

        ----------------------------------------------------------------------------
        -- Testcase 6
        ----------------------------------------------------------------------------
        Print("Testcase 6: Check if internal BRAM is accessible."
              & " Writing to and reading from BRAM via AXI Interface (BRAM port A) will be tested.", sep_up);
        total_tc := total_tc + 1;
        testcase <= bram_mode_axi_test;

        -- Reset module
        ResetModule(rstn, reset_index);

        -- Write data into BRAM via AXI
        for i in 0 to (int_bram_depth - 1) loop
            AXIWrite(Int2Slv(i * input_data_array_offset, s_axi_bram_awaddr'length), input_data_array(i), aclk_period, sendItBRAM, s_axi_bram_awaddr, s_axi_bram_wdata, s_axi_bram_wstrb, s_axi_bram_bvalid);
        end loop;

        -- Clear BRAM write address and data and wait for a couple of clock cycles
        s_axi_bram_awaddr <= (others => '0');
        s_axi_bram_wdata  <= (others => '0');
        wait for (10 * aclk_period);

        -- Read data from BRAM via AXI
        for i in 0 to (int_bram_depth - 1) loop
            AXIRead(Int2Slv(i * input_data_array_offset, s_axi_bram_awaddr'length), aclk_period, readItBRAM, s_axi_bram_araddr, s_axi_bram_rvalid);
            if (input_data_array(i) /= s_axi_bram_rdata) then
                numErrorsBRAMAXI := numErrorsBRAMAXI + 1;
                if (testcase6_max_shown_errors > numErrorsBRAMAXI) then
                    Print("Wrong data coming from BRAM (i = " & integer'image(i) & "): s_axi_bram_rdata = 0x" & Slv2HexStr(s_axi_bram_rdata) & " (expected: 0x" & Slv2HexStr(input_data_array(i)) & ")");
                elsif (testcase6_max_shown_errors = numErrorsBRAMAXI) then
                    Print("There are more errors, but only " & integer'image(testcase6_max_shown_errors) & " are shown!");
                end if;
            end if;
        end loop;

        -- Testcase 6 evaluation
        if (0 = numErrorsBRAMAXI) then
            total_tc_passed := total_tc_passed + 1;
            report "Writing and reading from BRAM via AXI passed!";
        else
            report "Writing and reading from BRAM via AXI failed: " & integer'image(numErrorsModeTest) & " errors detected!";
        end if;

        wait for testcase_to_finish;
        Print("Testcase completed!", sep_down);
        PrintEmptyLines(2);

        ----------------------------------------------------------------------------
        -- Testcase 7
        ----------------------------------------------------------------------------
        Print("Testcase 7: Check if Module outputs data correctly, while in BRAM continuous mode.", sep_up);
        total_tc := total_tc + 1;
        testcase <= bram_continuous_mode_test;

        -- Disable module
        rstn <= (others => '0');

        PrintEmptyLines(1);
        Print("Subtest 1: Maximum address is set to 0, address should increment up to (BRAM depth - 1) and then return to 0...", sep_up, sep_line_len/2);

        -- BRAM already written in testcase 6, so no need to write again
        -- Configure dummy data generator and apply config by resetting module
        AXIWrite(mode_addr, bram_continuous_mode, aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        AXIWrite(max_samples_addr, std_logic_vector(to_unsigned(testcase7_max_samples, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        AXIWrite(sample_delay_addr, std_logic_vector(to_unsigned(testcase7_sample_delay, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);

        -- Special case where maximum address is set to 0
        -- Set maximum address to highest possible BRAM address
        AXIWrite(bram_max_addr_addr, std_logic_vector(to_unsigned(bram_max_addr_subtest_1, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        ResetModule(rstn, reset_index);

        -- Start counting samples
        wait until ('1' = m_axis_tvalid);
        testcase7_count_samples <= true;
        -- Wait until last bram value is outputted
        wait until (input_data_array(int_bram_depth-1) = m_axis_tdata and '1' = m_axis_tvalid);
        -- Wait until first bram value is outputted again
        wait until (input_data_array(0) = m_axis_tdata and '1' = m_axis_tvalid);
        testcase7_count_samples <= false;

        -- Check if BRAM address returns to first BRAM address and sample counter is equal to BRAM depth
        if (input_data_array(0) /= m_axis_tdata or int_bram_depth /= testcase7_sample_counter) then
            Print("BRAM address should return to first BRAM address (0x0) and sample counter should be equal to BRAM depth!");
            Print("BRAM depth: " & integer'image(int_bram_depth) & " | Samples counted: " & integer'image(testcase7_sample_counter));
            numErrorsBRAMContinuous     := numErrorsBRAMContinuous + 1;
            ErrorBRAMContinuousSubtest1 := ErrorBRAMContinuousSubtest1 + 1;
        end if;

        if (ErrorBRAMContinuousSubtest1 > 0) then
            Print("...Subtest 1 failed!", sep_down, sep_line_len/2);
        else
            Print("...Subtest 1 passed!", sep_down, sep_line_len/2);
        end if;

        -- Disable module
        rstn <= (others => '0');

        PrintEmptyLines(1);
        Print("Subtest 2: Maximum address is set to a specific value, address should increment to given value and then return to 0...", sep_up, sep_line_len/2);

        -- Set maximum address to a specific value
        AXIWrite(bram_max_addr_addr, std_logic_vector(to_unsigned(bram_max_addr_subtest_2, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        ResetModule(rstn, reset_index);

        -- Start counting samples
        wait until ('1' = m_axis_tvalid);
        testcase7_count_samples <= true;
        -- Wait until last bram value is outputted
        wait until (input_data_array(bram_max_addr_subtest_2 - 1) = m_axis_tdata and '1' = m_axis_tvalid);
        -- Wait until first bram value is outputted again
        wait until (input_data_array(0) = m_axis_tdata and '1' = m_axis_tvalid);
        testcase7_count_samples <= false;

        -- Check if BRAM address returns to first BRAM address and sample counter is equal to BRAM depth
        if (input_data_array(0) /= m_axis_tdata or bram_max_addr_subtest_2 /= testcase7_sample_counter) then
            Print("BRAM address should return to first BRAM address (0x0) and sample counter should be equal to BRAM depth!");
            Print("BRAM depth: " & integer'image(bram_max_addr_subtest_2) & " | Samples counted: " & integer'image(testcase7_sample_counter));
            numErrorsBRAMContinuous     := numErrorsBRAMContinuous + 1;
            ErrorBRAMContinuousSubtest2 := ErrorBRAMContinuousSubtest2 + 1;
        end if;

        if (ErrorBRAMContinuousSubtest2 > 0) then
            Print("...Subtest 2 failed!", sep_down, sep_line_len/2);
        else
            Print("...Subtest 2 passed!", sep_down, sep_line_len/2);
        end if;

        -- Testcase 7 evaluation
        PrintEmptyLines(1);
        if (0 = numErrorsBRAMContinuous) then
            total_tc_passed := total_tc_passed + 1;
            report "BRAM continuous mode test passed!";
        else
            report "BRAM continuous mode test failed: " & integer'image(numErrorsBRAMContinuous) & " errors detected!";
        end if;

        wait for testcase_to_finish;
        Print("Testcase completed!", sep_down);
        PrintEmptyLines(2);

        ----------------------------------------------------------------------------
        -- Testcase 8
        ----------------------------------------------------------------------------
        Print("Testcase 8: Check if Module outputs data correctly, while in BRAM counter mode.", sep_up);
        total_tc := total_tc + 1;
        testcase <= bram_counter_mode_test;

        -- Disable module
        rstn <= (others => '0');

        -- BRAM already written in testcase 6, so no need to write again
        -- Configure dummy data generator and apply config by resetting module
        AXIWrite(mode_addr, bram_counter_mode, aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        AXIWrite(max_samples_addr, std_logic_vector(to_unsigned(testcase8_max_samples, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        AXIWrite(sample_delay_addr, std_logic_vector(to_unsigned(testcase8_sample_delay, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        ResetModule(rstn, reset_index);

        -- Start counting samples
        wait until ('1' = m_axis_tvalid);
        testcase8_count_samples <= true;

        loop
            -- Polling for transaction_done signal
            AXIRead(transaction_done_addr, aclk_period, readItRegs, s_axi_regs_araddr, s_axi_regs_rvalid);
            exit when s_axi_regs_rdata = X"00000001";
        end loop;

        testcase8_count_samples <= false;

        -- Testcase 8 evaluation
        if (testcase8_max_samples /= testcase8_sample_counter) then
            Print("BRAM counter mode failed! Expected samples: " & integer'image(testcase8_max_samples) & " | Samples counted: " & integer'image(testcase8_sample_counter));
            numErrorsBRAMCounter := numErrorsBRAMCounter + 1;
        end if;

        if (0 = numErrorsBRAMCounter) then
            total_tc_passed := total_tc_passed + 1;
            report "BRAM counter mode test passed!";
        else
            report "BRAM counter mode test failed: " & integer'image(numErrorsBRAMCounter) & " errors detected!";
        end if;

        wait for testcase_to_finish;
        Print("Testcase completed!", sep_down);
        PrintEmptyLines(2);

        ----------------------------------------------------------------------------
        -- Testcase 9
        ----------------------------------------------------------------------------
        Print("Testcase 9: Repeat of testcase 7, but output will be routed to debug port.", sep_up);
        total_tc := total_tc + 1;
        testcase <= debug_port_test;

        -- Disable module
        rstn <= (others => '0');

        -- BRAM already written in testcase 6, so no need to write again
        -- Configure dummy data generator and apply config by resetting module
        AXIWrite(mode_addr, bram_continuous_mode_debug, aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        AXIWrite(max_samples_addr, std_logic_vector(to_unsigned(testcase7_max_samples, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        AXIWrite(sample_delay_addr, std_logic_vector(to_unsigned(testcase7_sample_delay, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        -- Set maximum address to 0 to access all BRAM addresses
        AXIWrite(bram_max_addr_addr, std_logic_vector(to_unsigned(0, 32)), aclk_period, sendItRegs, s_axi_regs_awaddr, s_axi_regs_wdata, s_axi_regs_wstrb, s_axi_regs_bvalid);
        ResetModule(rstn, reset_index);

        -- Start counting samples
        wait until ('1' = debug_m_axis_tvalid);
        testcase9_count_samples <= true;
        -- Wait until last bram value is outputted
        wait until (input_data_array(int_bram_depth-1) = debug_m_axis_tdata and '1' = debug_m_axis_tvalid);
        -- Wait until first bram value is outputted again
        wait until (input_data_array(0) = debug_m_axis_tdata and '1' = debug_m_axis_tvalid);
        testcase9_count_samples <= false;

        -- Check if BRAM address returns to first BRAM address and sample counter is equal to BRAM depth
        if (input_data_array(0) /= debug_m_axis_tdata or int_bram_depth /= testcase9_sample_counter) then
            Print("BRAM address should return to first BRAM address (0x0) and sample counter should be equal to BRAM depth!");
            Print("BRAM depth: " & integer'image(int_bram_depth) & " | Samples counted: " & integer'image(testcase9_sample_counter));
            numErrorsDebugPort := numErrorsDebugPort + 1;
        end if;

        -- Testcase 7 evaluation
        if (0 = numErrorsDebugPort) then
            total_tc_passed := total_tc_passed + 1;
            report "Debug port test passed!";
        else
            report "Debug port test failed: " & integer'image(numErrorsDebugPort) & " errors detected!";
        end if;

        wait for testcase_to_finish;
        Print("Testcase completed!", sep_down);
        PrintEmptyLines(2);

        ----------------------------------------------------------------------------
        -- End of Test
        ----------------------------------------------------------------------------
        -- Final test evaluation
        total_err := numErrorsRegTest +
                     numErrorsCntMaxTest +
                     numErrorsMaxSampleTest +
                     numErrorsSampleDelay +
                     numErrorsDelay +
                     numErrorsModeTest +
                     numErrorsBRAMAXI +
                     numErrorsBRAMContinuous +
                     numErrorsBRAMCounter;

        -- Stop simulating system clock
        aclk_gen_enable <= false;

        -- Print final test evaluation
        Print("Final report:", sep_up);

        if (0 = total_err) then
            TestbenchPassed;
        else
            TestbenchFailed;
            Print("Errors encountered: " & integer'image(total_err));
        end if;

        Print("Testcases passed: " & integer'image(total_tc_passed) & "/" & integer'image(total_tc), sep_down);
        wait;

    end process TESTBENCH;

end;

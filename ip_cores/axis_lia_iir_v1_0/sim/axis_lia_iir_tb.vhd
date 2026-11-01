--------------------------------------------------------------------------------
-- Company: HHI
-- Engineers: Dung
--
-- Create Date: 2024-04-01
-- Module Name: axis_lock_in_mixer_tb
-- Project Name: Lock In Amplifier
-- Target Devices: Red Pitaya
-- Tool Versions: Vivado 2020.1 & Vivado 2023.1 (for simulation)
-- Description:
--      This testbench is used to simulate the Lock In Amplifier IP core.
--      The testbench is used to test the following functionalities:
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

entity axis_lia_iir_tb is
    generic (
        -- Reset parameters
        reset_width          : natural := 1;
        reset_index          : natural := 0;
        -- Parameters of Axi Slave Bus Interface S00_AXI
        s_axi_data_width     : natural := 32;
        s_axi_addr_width     : natural := 8;
        -- Parameters of Axi Stream Interface
        s_axis_tdata_width   : natural := 32;
        m_axis_tdata_width   : natural := 32;
        -- Testvector parameters
        iir_sos_stages       : natural := 3;  -- use max no. of available iir sos stages
        iir_coeff_width      : natural := 25;
        iir_coeff_frac_width : natural := 23;
        num_regs             : natural := 32;
        sample_rate_div      : natural := 10;  -- Set sampling frequency (adjust in iir_design.ipynb)
        tv_depth             : natural := 10000;  -- Length of test signal (adjust in iir_design.ipynb)
        -- Path to the repository, used to locate the test vectors.
        -- Set by scripts/core_sim.tcl when the simulation project is created.
        repo_path            : string  := "."
        );
end axis_lia_iir_tb;

architecture sim of axis_lia_iir_tb is
    ----------------------------------------------------------------------------
    -- Location of the test vectors, repo_path is a generic
    constant test_path      : string := "/ip_cores/axis_lia_iir_v1_0/sim/test_data/";
    constant test_data_path : string := repo_path & test_path;
    ----------------------------------------------------------------------------

    -- Simulation time constants
    constant aclk_period : time := 8 ns;
    constant init_period : time := 8000 ns;

    -- DUT signals
    signal aclk_gen_enable : boolean                                    := true;
    signal aclk            : std_logic                                  := '0';
    signal rstn            : std_logic_vector(reset_width - 1 downto 0) := (others => '1');

    -- AXI slave interface
    signal s_axi_aresetn     : std_logic := '1';
    signal s_axi_iir_awaddr  : std_logic_vector(s_axi_addr_width - 1 downto 0);
    signal s_axi_iir_awprot  : std_logic_vector(2 downto 0);
    signal s_axi_iir_awvalid : std_logic;
    signal s_axi_iir_awready : std_logic;
    signal s_axi_iir_wdata   : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal s_axi_iir_wstrb   : std_logic_vector((s_axi_data_width/8) - 1 downto 0);
    signal s_axi_iir_wvalid  : std_logic;
    signal s_axi_iir_wready  : std_logic;
    signal s_axi_iir_bresp   : std_logic_vector(1 downto 0);
    signal s_axi_iir_bvalid  : std_logic;
    signal s_axi_iir_bready  : std_logic;
    signal s_axi_iir_araddr  : std_logic_vector(s_axi_addr_width - 1 downto 0);
    signal s_axi_iir_arprot  : std_logic_vector(2 downto 0);
    signal s_axi_iir_arvalid : std_logic;
    signal s_axi_iir_arready : std_logic;
    signal s_axi_iir_rdata   : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal s_axi_iir_rresp   : std_logic_vector(1 downto 0);
    signal s_axi_iir_rvalid  : std_logic;
    signal s_axi_iir_rready  : std_logic;

    -- AXIS slave interface
    signal s_axis_i_tready : std_logic;
    signal s_axis_i_tvalid : std_logic                                         := '0';
    signal s_axis_i_tdata  : std_logic_vector(s_axis_tdata_width - 1 downto 0) := (others => '0');
    signal s_axis_q_tready : std_logic;
    signal s_axis_q_tvalid : std_logic                                         := '0';
    signal s_axis_q_tdata  : std_logic_vector(s_axis_tdata_width - 1 downto 0) := (others => '0');

    -- AXIS master interface
    signal m_axis_tready : std_logic := '1';
    signal m_axis_tvalid : std_logic;
    signal m_axis_tdata  : std_logic_vector(m_axis_tdata_width - 1 downto 0);

    -- Signals for AXI read/write transaction handshake
    signal sendItRegs : std_logic := '0';
    signal readItRegs : std_logic := '0';

    ----------------------------------------------------------------------------
    -- General testbench data
    ----------------------------------------------------------------------------
    -- Create a shared variable to store the input data
    constant i_data_path             : string := test_data_path & "i_data.tv";
    constant q_data_path             : string := test_data_path & "q_data.tv";
    constant coeff_data_path         : string := test_data_path & "iir_coeff_data.tv";
    shared variable i_data_array     : slv32_array(0 to tv_depth - 1);
    shared variable q_data_array     : slv32_array(0 to tv_depth - 1);
    shared variable coeff_data_array : slv32_array(0 to num_regs - 1);

    -- File path to write the filtered data
    constant log_file_path          : string  := test_data_path & "filt_sim_data.res";
    shared variable num_log_samples : integer := 2 * tv_depth;  -- Since we have I und Q alternating at the output
    shared variable log_data        : slv32_array(0 to num_log_samples - 1);
    shared variable log_data_index  : integer := 0;
    shared variable stop_logging    : boolean := true;

    -- Test vectors array definition
    type int_arr is array(natural range <>) of integer;

    -- Test states
    type test_state is (init, filter_data, tvalid_delay);
    signal testcase : test_state := init;

    ----------------------------------------------------------------------------
    -- Testcase 1 parameters
    ----------------------------------------------------------------------------
    signal countSamples         : boolean := false;
    shared variable numSamples  : integer := 0;
    shared variable tc1_num_err : integer := 0;

    ----------------------------------------------------------------------------
    -- Testcase 2 parameters
    ----------------------------------------------------------------------------
    signal tc2_count_tvalid_delay : boolean := false;

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
    IIR : entity work.axis_lia_iir_filter
        generic map (
            reset_width          => reset_width,
            reset_index          => reset_index,
            iir_sos_stages       => iir_sos_stages,
            iir_coeff_width      => iir_coeff_width,
            iir_coeff_frac_width => iir_coeff_frac_width,
            s_axi_addr_width     => s_axi_addr_width,
            s_axis_tdata_width   => s_axis_tdata_width,
            m_axis_tdata_width   => m_axis_tdata_width
            )
        port map (
            aclk              => aclk,
            rstn              => rstn,
            -- AXI Slave interface
            s_axi_aresetn     => s_axi_aresetn,
            s_axi_iir_awaddr  => s_axi_iir_awaddr,
            s_axi_iir_awprot  => s_axi_iir_awprot,
            s_axi_iir_awvalid => s_axi_iir_awvalid,
            s_axi_iir_awready => s_axi_iir_awready,
            s_axi_iir_wdata   => s_axi_iir_wdata,
            s_axi_iir_wstrb   => s_axi_iir_wstrb,
            s_axi_iir_wvalid  => s_axi_iir_wvalid,
            s_axi_iir_wready  => s_axi_iir_wready,
            s_axi_iir_bresp   => s_axi_iir_bresp,
            s_axi_iir_bvalid  => s_axi_iir_bvalid,
            s_axi_iir_bready  => s_axi_iir_bready,
            s_axi_iir_araddr  => s_axi_iir_araddr,
            s_axi_iir_arprot  => s_axi_iir_arprot,
            s_axi_iir_arvalid => s_axi_iir_arvalid,
            s_axi_iir_arready => s_axi_iir_arready,
            s_axi_iir_rdata   => s_axi_iir_rdata,
            s_axi_iir_rresp   => s_axi_iir_rresp,
            s_axi_iir_rvalid  => s_axi_iir_rvalid,
            s_axi_iir_rready  => s_axi_iir_rready,
            -- AXIS slave interface
            s_axis_i_tready   => s_axis_i_tready,
            s_axis_i_tvalid   => s_axis_i_tvalid,
            s_axis_i_tdata    => s_axis_i_tdata,
            s_axis_q_tready   => s_axis_q_tready,
            s_axis_q_tvalid   => s_axis_q_tvalid,
            s_axis_q_tdata    => s_axis_q_tdata,
            -- AXIS master interface
            m_axis_tready     => m_axis_tready,
            m_axis_tvalid     => m_axis_tvalid,
            m_axis_tdata      => m_axis_tdata
            );


    ----------------------------------------------------------------------------
    -- Generate clock and start AXI handshake processes
    ----------------------------------------------------------------------------
    -- Generate reference clock
    GenerateClock(aclk, aclk_period, aclk_gen_enable);

    -- AXI read/write transaction handshake for slave registers
    AXIWriteHandshake(aclk, sendItRegs, s_axi_iir_awvalid, s_axi_iir_awready, s_axi_iir_wvalid, s_axi_iir_wready, s_axi_iir_bvalid, s_axi_iir_bready, s_axi_iir_bresp);
    AXIReadHandshake(aclk, readItRegs, s_axi_iir_arvalid, s_axi_iir_arready, s_axi_iir_rvalid, s_axi_iir_rready);

    ------------------------------------------------------------------------
    -- Testbench processes
    ------------------------------------------------------------------------

    -- Process to write the 
    WRITE_FILTERED_DATA : process(aclk)
    begin
        if rising_edge(aclk) and m_axis_tvalid = '1' then
            if log_data_index < num_log_samples then
                log_data(log_data_index) := m_axis_tdata;
                log_data_index           := log_data_index + 1;
            end if;
        end if;
    end process;


    ----------------------------------------------------------------------------
    -- Testbench starts here
    ----------------------------------------------------------------------------
    MAIN_TESTBENCH : process

        -- Procedure to drive a number of input samples with specific data
        -- data is the data value to drive on the tdata signal
        -- samples is the number of zero-data input samples to drive
        procedure drive_data (
            data_1  : slv32_array;
            data_2  : slv32_array;
            samples : natural := 1) is
            variable i : integer := 0;
        begin
            i := 0;
            loop
                s_axis_i_tvalid <= '1' and s_axis_i_tready;
                s_axis_i_tdata  <= data_1(i);
                s_axis_q_tvalid <= '1' and s_axis_q_tready;
                s_axis_q_tdata  <= data_2(i);
                i               := i + 1;
                wait for aclk_period;
                -- Input rate is 1 input each 200 clock cycles: drive valid inputs at this rate
                s_axis_i_tvalid <= '0';
                s_axis_q_tvalid <= '0';
                wait for aclk_period * (sample_rate_div - 1);
                exit when i >= samples - 1;
            end loop;
        end procedure drive_data;


        -- Procedure to drive an impulse signal after waiting 100 clock cycles
        -- This is used to measure the delay between the input data and the
        -- output data of the filter. This is used to determine the length of
        -- the filter's shift register, used to delay the tvalid signal.
        procedure get_tvalid_delay (
            duration_time : natural := 1000;  -- Duration of the procedure in clock cycles
            impulse_time  : natural := 100  -- Assert impulse after this number of clock cycles
            ) is
            variable i : integer := 0;
        begin
            i := duration_time;

            loop
                i := i - 1;
                -- Assert impulse signal after impulse_time clock cycles
                if (i = duration_time - impulse_time) then
                    -- Drive impulse signal and assert tvalid
                    s_axis_i_tdata         <= x"000000FF";
                    s_axis_q_tdata         <= x"000000FF";
                    s_axis_i_tvalid        <= '1' and s_axis_i_tready;
                    s_axis_q_tvalid        <= '1' and s_axis_q_tready;
                    -- Set flag to count the tvlaid delay (clock cycles)
                    tc2_count_tvalid_delay <= true;
                    -- Wait for 1 clock cycle and deassert tvalid of input data
                    wait for aclk_period;
                    s_axis_i_tvalid        <= '0';
                    s_axis_q_tvalid        <= '0';
                end if;

                -- Wait for 1 clock cycle
                wait for aclk_period * (sample_rate_div - 1);
                -- Exit after duration_time clock cycles
                exit when i = 0;
            end loop;
        end procedure get_tvalid_delay;


    begin
        ------------------------------------------------------------------------
        -- Initialization: Load reference signals to IP internal BRAM
        ------------------------------------------------------------------------
        PrintEmptyLines(3);
        Print("Initializing testbench...", sep_up);
        PrintEmptyLines(1);

        Print("Reset module and AXI components...", sep_up, sep_line_len/2);
        ResetSystem(rstn, s_axi_aresetn);
        Print("...Done resetting module and AXI components!", sep_down, sep_line_len/2);
        PrintEmptyLines(1);

        -- Copy test data to array
        Print("Reading test vectors...", sep_up, sep_line_len/2);

        -- Read test vectors for In-phase and Quadrature input data and combine
        -- them into a single array
        read_8_char_hex_file(i_data_path, i_data_array, false);
        read_8_char_hex_file(q_data_path, q_data_array, false);
        read_8_char_hex_file(coeff_data_path, coeff_data_array, false);

        Print("...Done reading test vectors, enable verbose mode for more information!", sep_down, sep_line_len/2);
        PrintEmptyLines(1);

        -- Waiting prevents the simulation from starting automatically
        Print("Testbench initialization completed!", sep_down);
        wait for init_period;

        ------------------------------------------------------------------------
        -- Initialization phase: Load filter coefficients
        ------------------------------------------------------------------------
        Print("Initialization phase: Loading filter coefficients...", sep_up);
        testcase <= init;

        -- Load filter coefficients via AXI interface
        for i in 0 to num_regs - 1 loop
            AXIWrite(Int2Slv(i*4, s_axi_addr_width), coeff_data_array(i), aclk_period, sendItRegs, s_axi_iir_awaddr, s_axi_iir_wdata, s_axi_iir_wstrb, s_axi_iir_bvalid);
        end loop;

        Print("...Done loading filter coefficients!", sep_down);

        ------------------------------------------------------------------------
        -- Testcase 1: Send data into filter
        ------------------------------------------------------------------------
        Print("Testcase 1: Send predefined data into filter."
              & " This testcase is not self-checking!"
              & " Please verify the output data manually...", sep_up);

        testcase     <= filter_data;
        total_tc     := total_tc + 1;

        -- Drive data into filter and start logging
        stop_logging := false;
        drive_data(I_data_array, Q_data_array, tv_depth);

        -- Stop logging and write data to file
        stop_logging := true;
        write_signal_hex_file(log_data, num_log_samples, log_file_path);

        Print("...Done sending data into filter!", sep_down);

        ------------------------------------------------------------------------
        -- Testcase 2: This testcase is used to show the delay between the input
        -- data and the output data of the filter. As well as the delay of the
        -- tvalid signal. Nothing is evaluated here.
        ------------------------------------------------------------------------
        Print("Testcase 2: Visualize the delay between input and output data of the filter.", sep_up);

        testcase <= tvalid_delay;
        total_tc := total_tc + 1;

        -- Procedure duration: 1000 clock cycles, Impulse after 100 clock cycles
        get_tvalid_delay(1000, 100);

        Print("...Done visualizing the delay between input and output data of the filter!", sep_down);

        ------------------------------------------------------------------------
        -- Final report
        ------------------------------------------------------------------------
        -- Stop simulation
        aclk_gen_enable <= false;

        -- Print final report
        total_tc_err := tc1_num_err;

        --PrintEmptyLines(2);
        Print("Total amount of testcases: " & integer'image(total_tc), sep_up);
        Print("Testcases completed: Remember to verify the output data manually, since this testbench is not self-checking!", sep_down);
        wait;

    end process;

end architecture sim;

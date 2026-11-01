--------------------------------------------------------------------------------
-- Company: HHI
-- Engineers: Dung
--
-- Create Date: 2024-04-01
-- Module Name: axis_lock_in_mixer_tb
-- Project Name: Lock In Amplifier
-- Target Devices: Red Pitaya
-- Tool Versions: Vivado 2020.1 & Vivado 2023.1 (for simulation)
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

entity axis_lia_fir_tb is
    generic (
        -- Reset parameters
        reset_width          : natural := 1;
        reset_index          : natural := 0;
        -- Parameters of Axi Slave Bus Interface S00_AXI
        s_axi_data_width     : natural := 32;
        s_axi_addr_width     : natural := 6;
        -- Parameters of Axi Stream Interface
        s_axis_tdata_width   : natural := 32;
        m_axis_tdata_width   : natural := 32;
        -- Parameters of FIR filter
        fir_coeff_width      : natural := 25;
        fir_coeff_frac_width : natural := 24;

        -- Testvector parameters
        sample_rate_div   : natural := 10;
        num_reload_coeffs : natural := 252;
        tv_depth          : natural := 2000;
        -- Path to the repository, used to locate the test vectors.
        -- Set by scripts/core_sim.tcl when the simulation project is created.
        repo_path         : string  := "."
        );
end axis_lia_fir_tb;

architecture sim of axis_lia_fir_tb is
    ----------------------------------------------------------------------------
    -- Location of the test vectors, repo_path is a generic
    constant test_path      : string := "/ip_cores/axis_lia_fir_v1_0/sim/test_data/";
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
    signal s_axi_fir_awaddr  : std_logic_vector(s_axi_addr_width - 1 downto 0);
    signal s_axi_fir_awprot  : std_logic_vector(2 downto 0);
    signal s_axi_fir_awvalid : std_logic;
    signal s_axi_fir_awready : std_logic;
    signal s_axi_fir_wdata   : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal s_axi_fir_wstrb   : std_logic_vector((s_axi_data_width/8) - 1 downto 0);
    signal s_axi_fir_wvalid  : std_logic;
    signal s_axi_fir_wready  : std_logic;
    signal s_axi_fir_bresp   : std_logic_vector(1 downto 0);
    signal s_axi_fir_bvalid  : std_logic;
    signal s_axi_fir_bready  : std_logic;
    signal s_axi_fir_araddr  : std_logic_vector(s_axi_addr_width - 1 downto 0);
    signal s_axi_fir_arprot  : std_logic_vector(2 downto 0);
    signal s_axi_fir_arvalid : std_logic;
    signal s_axi_fir_arready : std_logic;
    signal s_axi_fir_rdata   : std_logic_vector(s_axi_data_width - 1 downto 0);
    signal s_axi_fir_rresp   : std_logic_vector(1 downto 0);
    signal s_axi_fir_rvalid  : std_logic;
    signal s_axi_fir_rready  : std_logic;

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

    ----------------------------------------------------------------------------
    -- General testbench data
    ----------------------------------------------------------------------------
    -- Create a shared variable to store the input data
    constant i_data_path         : string := test_data_path & "i_data.tv";
    constant q_data_path         : string := test_data_path & "q_data.tv";
    shared variable i_data_array : slv32_array(0 to tv_depth - 1);
    shared variable q_data_array : slv32_array(0 to tv_depth - 1);


    -- Test vectors array definition
    type int_arr is array(natural range <>) of integer;

    -- Test states
    type test_state is (
        init,
        filter
        );
    signal testcase : test_state := init;

    ----------------------------------------------------------------------------
    -- Testcase 1 parameters
    ----------------------------------------------------------------------------
    signal countSamples         : boolean := false;
    shared variable numSamples  : integer := 0;
    shared variable tc1_num_err : integer := 0;

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
    FIR : entity work.axis_lia_fir
        generic map (
            reset_width         => reset_width,
            reset_index         => reset_index,
            s_axis_tdata_width  => s_axis_tdata_width,
            m_axis_tdata_width  => m_axis_tdata_width,
            fir_coeff_width     => fir_coeff_width,
            fir_coeff_frac_bits => fir_coeff_frac_width
            )
        port map (
            aclk              => aclk,
            rstn              => rstn,
            -- AXI Slave interface
            s_axi_aresetn     => s_axi_aresetn,
            s_axi_fir_awaddr  => s_axi_fir_awaddr,
            s_axi_fir_awprot  => s_axi_fir_awprot,
            s_axi_fir_awvalid => s_axi_fir_awvalid,
            s_axi_fir_awready => s_axi_fir_awready,
            s_axi_fir_wdata   => s_axi_fir_wdata,
            s_axi_fir_wstrb   => s_axi_fir_wstrb,
            s_axi_fir_wvalid  => s_axi_fir_wvalid,
            s_axi_fir_wready  => s_axi_fir_wready,
            s_axi_fir_bresp   => s_axi_fir_bresp,
            s_axi_fir_bvalid  => s_axi_fir_bvalid,
            s_axi_fir_bready  => s_axi_fir_bready,
            s_axi_fir_araddr  => s_axi_fir_araddr,
            s_axi_fir_arprot  => s_axi_fir_arprot,
            s_axi_fir_arvalid => s_axi_fir_arvalid,
            s_axi_fir_arready => s_axi_fir_arready,
            s_axi_fir_rdata   => s_axi_fir_rdata,
            s_axi_fir_rresp   => s_axi_fir_rresp,
            s_axi_fir_rvalid  => s_axi_fir_rvalid,
            s_axi_fir_rready  => s_axi_fir_rready,
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

    ----------------------------------------------------------------------------
    -- Testbench evaluation processes section
    ----------------------------------------------------------------------------

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

        Print("...Done reading test vectors, enable verbose mode for more information!", sep_down, sep_line_len/2);
        PrintEmptyLines(1);

        -- Waiting prevents the simulation from starting automatically
        Print("Testbench initialization completed!", sep_down);
        wait for init_period;

        ------------------------------------------------------------------------
        -- Testcase 1: Send data into filter
        ------------------------------------------------------------------------

        -- This is only an example testcase
        Print("Testcase 1: Filtering, this testcase is not self checking and can only be verified by looking at the output data.", sep_up);
        total_tc := total_tc + 1;
        testcase <= init;

        testcase <= filter;
        drive_data(I_data_array, Q_data_array, tv_depth);

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

        wait;

    end process;

end architecture sim;

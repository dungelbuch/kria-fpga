library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axis_ram_writer_S_AXI is
    generic (
        c_s_axi_data_width : integer := 32;
        c_s_axi_addr_width : integer := 5;
        cfg_data_width     : integer := 32;
        sts_data_width     : integer := 32
        );
    port (
        -- Register input and output
        cfg_data       : out std_logic_vector(cfg_data_width - 1 downto 0);  --0x00
        sts_data       : in  std_logic_vector(sts_data_width - 1 downto 0);  --0x04
        block_mode_en  : out std_logic;  --0x08
        sts_width_mask : out std_logic_vector(c_s_axi_data_width - 1 downto 0);  --0x0C

        -- AXI Lite signals
        s_axi_aclk    : in  std_logic;
        s_axi_aresetn : in  std_logic;
        s_axi_awaddr  : in  std_logic_vector(c_s_axi_addr_width - 1 downto 0);
        s_axi_awprot  : in  std_logic_vector(2 downto 0);
        s_axi_awvalid : in  std_logic;
        s_axi_awready : out std_logic;
        s_axi_wdata   : in  std_logic_vector(c_s_axi_data_width - 1 downto 0);
        s_axi_wstrb   : in  std_logic_vector((c_s_axi_data_width/8) - 1 downto 0);
        s_axi_wvalid  : in  std_logic;
        s_axi_wready  : out std_logic;
        s_axi_bresp   : out std_logic_vector(1 downto 0);
        s_axi_bvalid  : out std_logic;
        s_axi_bready  : in  std_logic;
        s_axi_araddr  : in  std_logic_vector(c_s_axi_addr_width - 1 downto 0);
        s_axi_arprot  : in  std_logic_vector(2 downto 0);
        s_axi_arvalid : in  std_logic;
        s_axi_arready : out std_logic;
        s_axi_rdata   : out std_logic_vector(c_s_axi_data_width - 1 downto 0);
        s_axi_rresp   : out std_logic_vector(1 downto 0);
        s_axi_rvalid  : out std_logic;
        s_axi_rready  : in  std_logic
        );
end axis_ram_writer_S_AXI;

architecture arch_imp of axis_ram_writer_S_AXI is

    -- Signal for padding
    signal zeros : std_logic_vector(c_s_axi_data_width - 1 downto 0) := (others => '0');

    -- AXI4LITE signals
    signal axi_awaddr  : std_logic_vector(c_s_axi_addr_width - 1 downto 0);
    signal axi_awready : std_logic;
    signal axi_wready  : std_logic;
    signal axi_bresp   : std_logic_vector(1 downto 0);
    signal axi_bvalid  : std_logic;
    signal axi_araddr  : std_logic_vector(c_s_axi_addr_width - 1 downto 0);
    signal axi_arready : std_logic;
    signal axi_rdata   : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal axi_rresp   : std_logic_vector(1 downto 0);
    signal axi_rvalid  : std_logic;

    -- Example-specific design signals
    -- local parameter for addressing 32 bit / 64 bit c_s_axi_data_width
    -- ADDR_LSB is used for addressing 32/64 bit registers/memories
    -- ADDR_LSB = 2 for 32 bits (n downto 2)
    -- ADDR_LSB = 3 for 64 bits (n downto 3)
    constant ADDR_LSB          : integer := (c_s_axi_data_width/32) + 1;
    constant OPT_MEM_ADDR_BITS : integer := 3;

    ------------------------------------------------
    ---- Signals for user logic register space example
    --------------------------------------------------
    signal slv_reg0     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg1     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg2     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg3     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg4     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg5     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg6     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg7     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg8     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg9     : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg10    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg11    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg12    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg13    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg14    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg15    : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal slv_reg_rden : std_logic;
    signal slv_reg_wren : std_logic;
    signal reg_data_out : std_logic_vector(c_s_axi_data_width - 1 downto 0);
    signal byte_index   : integer;
    signal aw_en        : std_logic;

begin

    -- I/O Connections assignments
    s_axi_awready <= axi_awready;
    s_axi_wready  <= axi_wready;
    s_axi_bresp   <= axi_bresp;
    s_axi_bvalid  <= axi_bvalid;
    s_axi_arready <= axi_arready;
    s_axi_rdata   <= axi_rdata;
    s_axi_rresp   <= axi_rresp;
    s_axi_rvalid  <= axi_rvalid;

    ----------------------------------------------------------------------------
    -- User Slave Register:
    ----------------------------------------------------------------------------
    -- Config register (at 0x00) contain RAM base address
    -- Software: rw / Hardware: ro
    cfg_data <= slv_reg0;

    -- Status register (at 0x04) contain the RAM writer'd current address offset
    -- Software: ro / Hardware: wo
    -- None <= slv_reg1;

    -- Block mode enable register (at 0x08)
    -- Software: rw / Hardware: ro
    block_mode_en <= slv_reg2(0);

    -- Address width mask register (at 0x0C)
    -- Software: rw / Hardware: ro
    sts_width_mask <= slv_reg3;         --X"0C"

    --  <= slv_reg4;  --X"10"
    --  <= slv_reg5;  --X"14"
    --  <= slv_reg6;  --X"18"
    --  <= slv_reg7;  --X"1C"
    --  <= slv_reg8;  --X"20"
    --  <= slv_reg9;  --X"24"
    --  <= slv_reg10; --X"28"
    --  <= slv_reg11; --X"2C"
    --  <= slv_reg12; --X"30"
    --  <= slv_reg13; --X"34"
    --  <= slv_reg14; --X"38"
    --  <= slv_reg15; --X"3C"

    -- Implement axi_awready generation
    -- axi_awready is asserted for one s_axi_aclk clock cycle when both
    -- S_AXI_AWVALID and s_axi_wvalid are asserted. axi_awready is
    -- de-asserted when reset is low.
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_awready <= '0';
                aw_en       <= '1';
            else
                if (axi_awready = '0' and S_AXI_AWVALID = '1' and s_axi_wvalid = '1' and aw_en = '1') then
                                        -- slave is ready to accept write address when
                                        -- there is a valid write address and write data
                                        -- on the write address and data bus. This design
                                        -- expects no outstanding transactions.
                    axi_awready <= '1';
                    aw_en       <= '0';
                elsif (s_axi_bready = '1' and axi_bvalid = '1') then
                    aw_en       <= '1';
                    axi_awready <= '0';
                else
                    axi_awready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Implement axi_awaddr latching
    -- This process is used to latch the address when both
    -- S_AXI_AWVALID and s_axi_wvalid are valid.
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_awaddr <= (others => '0');
            else
                if (axi_awready = '0' and S_AXI_AWVALID = '1' and s_axi_wvalid = '1' and aw_en = '1') then
                                        -- Write Address latching
                    axi_awaddr <= s_axi_awaddr;
                end if;
            end if;
        end if;
    end process;

    -- Implement axi_wready generation
    -- axi_wready is asserted for one s_axi_aclk clock cycle when both
    -- S_AXI_AWVALID and s_axi_wvalid are asserted. axi_wready is
    -- de-asserted when reset is low.
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_wready <= '0';
            else
                if (axi_wready = '0' and s_axi_wvalid = '1' and S_AXI_AWVALID = '1' and aw_en = '1') then
                                        -- slave is ready to accept write data when
                                        -- there is a valid write address and write data
                                        -- on the write address and data bus. This design
                                        -- expects no outstanding transactions.
                    axi_wready <= '1';
                else
                    axi_wready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Implement memory mapped register select and write logic generation
    -- The write data is accepted and written to memory mapped registers when
    -- axi_awready, s_axi_wvalid, axi_wready and s_axi_wvalid are asserted. Write strobes are used to
    -- select byte enables of slave registers while writing.
    -- These registers are cleared when reset (active low) is applied.
    -- Slave register write enable is asserted when valid address and data are available
    -- and the slave is ready to accept the write address and write data.
    slv_reg_wren <= axi_wready and s_axi_wvalid and axi_awready and S_AXI_AWVALID;

    process (s_axi_aclk)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                slv_reg0  <= (others => '0');
                slv_reg1  <= (others => '0');
                slv_reg2  <= (others => '0');
                slv_reg3  <= (others => '0');
                slv_reg4  <= (others => '0');
                slv_reg5  <= (others => '0');
                slv_reg6  <= (others => '0');
                slv_reg7  <= (others => '0');
                slv_reg8  <= (others => '0');
                slv_reg9  <= (others => '0');
                slv_reg11 <= (others => '0');
                slv_reg12 <= (others => '0');
                slv_reg13 <= (others => '0');
                slv_reg14 <= (others => '0');
                slv_reg15 <= (others => '0');
            else
                loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
                if (slv_reg_wren = '1') then
                    case loc_addr is
                        when b"0000" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave registor 0
                                    slv_reg0(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"0001" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave registor 1
                                    slv_reg1(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"0010" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave registor 2
                                    slv_reg2(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"0011" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave register 3
                                    slv_reg3(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"0100" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave register 4
                                    slv_reg4(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"0101" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave register 5
                                    slv_reg5(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"0110" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave register 5
                                    slv_reg6(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"0111" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave register 5
                                    slv_reg7(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"1000" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave register 5
                                    slv_reg8(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"1001" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave register 5
                                    slv_reg9(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"1011" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave register 5
                                    slv_reg11(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"1100" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave register 5
                                    slv_reg12(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"1101" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave register 5
                                    slv_reg13(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"1110" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave register 5
                                    slv_reg14(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when b"1111" =>
                            for byte_index in 0 to (c_s_axi_data_width/8 - 1) loop
                                if (s_axi_wstrb(byte_index) = '1') then
                                        -- Respective byte enables are asserted as per write strobes
                                        -- slave register 5
                                    slv_reg15(byte_index * 8 + 7 downto byte_index * 8) <= s_axi_wdata(byte_index * 8 + 7 downto byte_index * 8);
                                end if;
                            end loop;
                        when others =>
                            slv_reg0  <= slv_reg0;
                            slv_reg1  <= slv_reg1;
                            slv_reg2  <= slv_reg2;
                            slv_reg3  <= slv_reg3;
                            slv_reg4  <= slv_reg4;
                            slv_reg5  <= slv_reg5;
                            slv_reg6  <= slv_reg6;
                            slv_reg7  <= slv_reg7;
                            slv_reg8  <= slv_reg8;
                            slv_reg9  <= slv_reg9;
                            slv_reg10 <= slv_reg10;
                            slv_reg11 <= slv_reg11;
                            slv_reg12 <= slv_reg12;
                            slv_reg13 <= slv_reg13;
                            slv_reg14 <= slv_reg14;
                            slv_reg15 <= slv_reg15;
                    end case;
                end if;
            end if;
        end if;
    end process;

    -- Implement write response logic generation
    -- The write response and response valid signals are asserted by the slave
    -- when axi_wready, s_axi_wvalid, axi_wready and s_axi_wvalid are asserted.
    -- This marks the acceptance of address and indicates the status of
    -- write transaction.
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_bvalid <= '0';
                axi_bresp  <= "00";     --need to work more on the responses
            else
                if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and s_axi_wvalid = '1' and axi_bvalid = '0') then
                    axi_bvalid <= '1';
                    axi_bresp  <= "00";
                elsif (s_axi_bready = '1' and axi_bvalid = '1') then  --check if bready is asserted while bvalid is high)
                    axi_bvalid <= '0';  -- (there is a possibility that bready is always asserted high)
                end if;
            end if;
        end if;
    end process;

    -- Implement axi_arready generation
    -- axi_arready is asserted for one s_axi_aclk clock cycle when
    -- s_axi_arvalid is asserted. axi_awready is
    -- de-asserted when reset (active low) is asserted.
    -- The read address is also latched when s_axi_arvalid is
    -- asserted. axi_araddr is reset to zero on reset assertion.
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_arready <= '0';
                axi_araddr  <= (others => '1');
            else
                if (axi_arready = '0' and s_axi_arvalid = '1') then
                                        -- indicates that the slave has acceped the valid read address
                    axi_arready <= '1';
                                        -- Read Address latching
                    axi_araddr  <= s_axi_araddr;
                else
                    axi_arready <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Implement axi_arvalid generation
    -- axi_rvalid is asserted for one s_axi_aclk clock cycle when both
    -- s_axi_arvalid and axi_arready are asserted. The slave registers
    -- data are available on the axi_rdata bus at this instance. The
    -- assertion of axi_rvalid marks the validity of read data on the
    -- bus and axi_rresp indicates the status of read transaction.axi_rvalid
    -- is deasserted on reset (active low). axi_rresp and axi_rdata are
    -- cleared to zero on reset (active low).
    process (s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                axi_rvalid <= '0';
                axi_rresp  <= "00";
            else
                if (axi_arready = '1' and s_axi_arvalid = '1' and axi_rvalid = '0') then
                                         -- Valid read data is available at the read data bus
                    axi_rvalid <= '1';
                    axi_rresp  <= "00";  -- 'OKAY' response
                elsif (axi_rvalid = '1' and s_axi_rready = '1') then
                                         -- Read data is accepted by the master
                    axi_rvalid <= '0';
                end if;
            end if;
        end if;
    end process;

    -- Implement memory mapped register select and read logic generation
    -- Slave register read enable is asserted when valid address is available
    -- and the slave is ready to accept the read address.
    slv_reg_rden <= axi_arready and s_axi_arvalid and (not axi_rvalid);

    process (slv_reg0, sts_data, slv_reg1, slv_reg2, slv_reg3, slv_reg4, slv_reg5, slv_reg6, slv_reg7, slv_reg8, slv_reg9, slv_reg10, slv_reg11, slv_reg12, slv_reg13, slv_reg14, slv_reg15, axi_araddr, s_axi_aresetn, slv_reg_rden)
        variable loc_addr : std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
    begin
        -- Address decoding for reading registers
        loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
        case loc_addr is
            when b"0000" =>
                reg_data_out <= slv_reg0;
            when b"0001" =>
                reg_data_out <= sts_data;
            when b"0010" =>
                reg_data_out <= slv_reg2;
            when b"0011" =>
                reg_data_out <= slv_reg3;
            when b"0100" =>
                reg_data_out <= slv_reg4;
            when b"0101" =>
                reg_data_out <= slv_reg5;
            when b"0110" =>
                reg_data_out <= slv_reg6;
            when b"0111" =>
                reg_data_out <= slv_reg7;
            when b"1000" =>
                reg_data_out <= slv_reg8;
            when b"1001" =>
                reg_data_out <= slv_reg9;
            when b"1010" =>
                reg_data_out <= slv_reg10;
            when b"1011" =>
                reg_data_out <= slv_reg11;
            when b"1100" =>
                reg_data_out <= slv_reg12;
            when b"1101" =>
                reg_data_out <= slv_reg13;
            when b"1110" =>
                reg_data_out <= slv_reg14;
            when b"1111" =>
                reg_data_out <= slv_reg15;
            when others =>
                reg_data_out <= (others => '0');
        end case;
    end process;

    -- Output register or memory read data
    process (s_axi_aclk) is
    begin
        if (rising_edge (s_axi_aclk)) then
            if (s_axi_aresetn = '0') then
                axi_rdata <= (others => '0');
            else
                if (slv_reg_rden = '1') then
                                                -- When there is a valid read address (s_axi_arvalid) with
                                                -- acceptance of read address by the slave (axi_arready),
                                                -- output the read dada
                                                -- Read address mux
                    axi_rdata <= reg_data_out;  -- register read data
                end if;
            end if;
        end if;
    end process;
    -- Add user logic here

    -- User logic ends

end arch_imp;

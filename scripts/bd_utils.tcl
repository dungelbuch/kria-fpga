# Helper procedures for writing block designs, sourced by project.tcl.

# Connects a pin/interface of a cell to a pin, port, interface pin or interface port
proc bd_connect {local_name remote_name} {
    set local [get_bd_pins -quiet $local_name]
    if {[llength $local] == 1} {
        set remote [get_bd_pins -quiet $remote_name]
        if {[llength $remote] != 1} { set remote [get_bd_ports -quiet $remote_name] }
        if {[llength $remote] == 1} {
            connect_bd_net $local $remote
            return
        }
    }
    set local [get_bd_intf_pins -quiet $local_name]
    if {[llength $local] == 1} {
        set remote [get_bd_intf_pins -quiet $remote_name]
        if {[llength $remote] != 1} { set remote [get_bd_intf_ports -quiet $remote_name] }
        if {[llength $remote] == 1} {
            connect_bd_intf_net $local $remote
            return
        }
    }
    error "** ERROR: can't connect $local_name and $remote_name"
}

# Places an IP core in the block design, configures it and connects its pins
#   cell <vlnv> <name> {PARAM value ...} {local_pin remote_pin ...}
proc cell {cell_vlnv cell_name {cell_props {}} {cell_ports {}}} {
    set cell [create_bd_cell -type ip -vlnv $cell_vlnv $cell_name]
    set prop_list {}
    foreach {prop_name prop_value} [uplevel 1 [list subst $cell_props]] {
        lappend prop_list CONFIG.$prop_name $prop_value
    }
    if {[llength $prop_list] > 1} {
        set_property -dict $prop_list $cell
    }
    foreach {local_name remote_name} [uplevel 1 [list subst $cell_ports]] {
        bd_connect $cell_name/$local_name $remote_name
    }
}

# Creates a hierarchy, fills it by evaluating module_body inside it and connects its pins
#   module <name> {body} {local_pin remote_pin ...}
proc module {module_name module_body {module_ports {}}} {
    set bd [current_bd_instance .]
    current_bd_instance [create_bd_cell -type hier $module_name]
    uplevel 1 $module_body
    current_bd_instance $bd
    foreach {local_name remote_name} [uplevel 1 [list subst $module_ports]] {
        bd_connect $module_name/$local_name $remote_name
    }
}

# Connects an AXI master to an AXI slave through a SmartConnect. One SmartConnect is created per
# master and gets an extra master port for every slave added. The SmartConnect is clocked and
# reset by the globals axi_clk and axi_rstn, which the block design sets.
proc axi_connect {slave master} {
    global axi_clk axi_rstn
    set ic_name ic_[string map {/ _} $master]
    set ic [get_bd_cells -quiet /$ic_name]
    if {[llength $ic] == 0} {
        set ic [create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect /$ic_name]
        set_property -dict {CONFIG.NUM_SI 1 CONFIG.NUM_MI 1} $ic
        connect_bd_intf_net [get_bd_intf_pins $master] [get_bd_intf_pins $ic/S00_AXI]
        connect_bd_net [get_bd_pins $axi_clk] [get_bd_pins $ic/aclk]
        connect_bd_net [get_bd_pins $axi_rstn] [get_bd_pins $ic/aresetn]
        set mi 0
    } else {
        set mi [get_property CONFIG.NUM_MI $ic]
        set_property CONFIG.NUM_MI [expr {$mi + 1}] $ic
    }
    connect_bd_intf_net [get_bd_intf_pins $ic/[format M%02d_AXI $mi]] [get_bd_intf_pins $slave]
}

# Connects an AXI-Lite slave to a master and assigns it an address range
#   addr <offset> <range> <slave interface> <master interface>
proc addr {offset range port master} {
    axi_connect $port $master
    assign_bd_address -offset $offset -range $range [get_bd_addr_segs -of_objects [get_bd_intf_pins $port]]
}

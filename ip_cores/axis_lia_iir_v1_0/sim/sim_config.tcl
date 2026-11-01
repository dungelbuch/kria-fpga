# select all IPs that are used in this testbench
set simCoreList {axis_lia_iir_v1_0}

# now add all related .vhd/.v files from the cores/-folder to the design
foreach simCore $simCoreList {
	add_files -norecurse -scan_for_includes $ip_location/$simCore/hdl
}

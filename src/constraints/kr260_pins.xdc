# Pins on the KR260 carrier, taken from the kr260_carrier board files

# User LEDs UF1, UF2 (SOM240_1 D13, D14)
set_property PACKAGE_PIN F8 [get_ports {led_o[0]}]
set_property PACKAGE_PIN E8 [get_ports {led_o[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led_o[*]}]

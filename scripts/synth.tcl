# Synthesizes the design, unless synthesis is already up to date.
# Usage: vivado -mode batch -source scripts/synth.tcl

source [file join [file dirname [info script]] settings.tcl]

open_kria_project
run_to synth_1 synth_design
close_project

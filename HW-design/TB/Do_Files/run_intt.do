# run_intt.do — ModelSim compile & simulate script for INTT
# Usage: vsim -do run_intt.do

vlib work
vlog -sv barrett_reduction_kyber.sv
vlog -sv modq.sv
vlog -sv gs_butterfly.sv
vlog -sv tb_intt_full.sv

vsim -novopt tb_intt_full -t 1ns
run -all
quit

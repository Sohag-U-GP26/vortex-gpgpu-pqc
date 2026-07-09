# run_ntt.do — ModelSim compile & simulate script for NTT
# Usage: vsim -do run_ntt.do

vlib work
vlog -sv barrett_reduction_kyber.sv
vlog -sv modq.sv
vlog -sv ct_butterfly.sv
vlog -sv tb_ntt_full.sv

vsim -novopt tb_ntt_full -t 1ns
run -all
quit

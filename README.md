# VHDL Pipeline Processor
This little project is an implementation of a MIPS-like pipeline processor in VHDL using Altera's FPGA technology

This project implements the following instructions :
  - ADD $DestReg, $Reg1, $Reg2
  - ADDI $DestReg, $Reg1, Constant
  - NOR $DestReg, $Reg1, $Reg2
  - AND $DestReg, $Reg1, $Reg2
  - BEQ $Reg1, $Reg2, Jump_to_line
  - JUMP Jump_to_line
  - LOAD $DestReg, $RAM_ADDR
  - STORE $SourceReg, $RAM_ADDR
  - IN $DestReg
  - OUT $SourceReg
  - MOVE $DestReg, $SourceReg
  - BGT $Reg1, $Reg2, Jump_to_line

The chosen architecture is depicted on the following figure (Check PLProcessorDoc.pdf to have every information about this project)

![alt text](https://github.com/gabriel-f-o/VHDL_Pipeline_Processor/blob/master/LaTeX%20Source%20Code/PLProcessor.png?raw=true)

In this project you will find all source codes ready to be compiled and simulated, as well as a project for testing and debuging

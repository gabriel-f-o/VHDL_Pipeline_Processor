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

The chosen architecture is based on the following figure, but with several changes (Check PLProcessorDoc.pdf to understand the modifications and all information about this project)

![alt text](https://d2vlcm61l7u1fs.cloudfront.net/media%2Fd78%2Fd782f7aa-1932-48b2-b65a-8575636f8749%2FphpAWJIrf.png)

Source = https://www.chegg.com/homework-help/questions-and-answers/th-exercise-intended-help-understand-relationship-forwarding-hazard-detection-isa-design-p-q12039689

Also http://mi.eng.cam.ac.uk/~ahg/MIPS-Datapath/ (highly recommended if you want to implement the pipeline yourself)

In this project you will find all source codes ready to be compiled and simulated, as well as a project for testing and debuging

//////////////////////////////////////////////////////////////////////
////                                                              ////
////  8051 cores top level module                                 ////
////                                                              ////
////  This file is part of the 8051 cores project                 ////
////  http://www.opencores.org/cores/8051/                        ////
////                                                              ////
////  Description                                                 ////
////  8051 definitions.                                           ////
////                                                              ////
////  To Do:                                                      ////
////    nothing                                                   ////
////                                                              ////
////  Author(s):                                                  ////
////      - Simon Teran, simont@opencores.org                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2000 Authors and OPENCORES.ORG                 ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE.  See the GNU Lesser General Public License for more ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
//
// CVS Revision History
//
// $Log: not supported by cvs2svn $
// Revision 1.18  2003/01/13 14:14:41  simont
// replace some modules
//
// Revision 1.17  2002/11/05 17:23:54  simont
// add module oc8051_sfr, 256 bytes internal ram
//
// Revision 1.16  2002/10/28 14:55:00  simont
// fix bug in interface to external data ram
//
// Revision 1.15  2002/10/23 16:53:39  simont
// fix bugs in instruction interface
//
// Revision 1.14  2002/10/17 18:50:00  simont
// cahnge interface to instruction rom
//
// Revision 1.13  2002/09/30 17:33:59  simont
// prepared header
//
//

// synopsys translate_off
`include "oc8051_timescale.v"
// synopsys translate_on


module oc8051_top (wb_rst_i, wb_clk_i,
//interface to instruction rom
		wbi_adr_o, wbi_dat_i, wbi_stb_o, wbi_ack_i, wbi_cyc_o, wbi_err_i,
//interface to data ram
		wbd_dat_i, wbd_dat_o,
		wbd_adr_o, wbd_we_o, wbd_ack_i, wbd_stb_o, wbd_cyc_o, wbd_err_i,
// interrupt interface
		int0_i, int1_i,
// external access (active low)
		ea_in,
// port interface
		p0_i, p1_i, p2_i, p3_i,
		p0_o, p1_o, p2_o, p3_o,
// serial interface
		rxd_i, txd_o,
// counter interface
		t0_i, t1_i, t2_i, t2ex_i);



input         wb_rst_i,		// reset input
              wb_clk_i,		// clock input
              int0_i,		// interrupt 0
              int1_i,		// interrupt 1
              ea_in,		// external access
              rxd_i,		// receive
              t0_i,		// counter 0 input
              t1_i,		// counter 1 input
              wbd_ack_i,	// data acknowalge
              wbi_ack_i,	// instruction acknowlage
              wbd_err_i,	// data error
              wbi_err_i,	// instruction error
              t2_i,		// counter 2 input
              t2ex_i;		// ???

input [7:0]   wbd_dat_i,	// ram data input
              p0_i,		// port 0 input
	      p1_i,		// port 1 input
	      p2_i,		// port 2 input
	      p3_i;		// port 3 input
input [31:0]  wbi_dat_i;	// rom data input

output        wbd_we_o,		// data write enable
              txd_o,		// transnmit
	      wbd_stb_o,	// data strobe
	      wbd_cyc_o,	// data cycle
	      wbi_stb_o,	// instruction strobe
	      wbi_cyc_o;	// instruction cycle

output [7:0]  wbd_dat_o,	// data output
              p0_o,		// port 0 output
	      p1_o,		// port 1 output
	      p2_o,		// port 2 output
	      p3_o;		// port 3 output

output [15:0] wbd_adr_o,	// data address
              wbi_adr_o;	// instruction address


wire [7:0] op1_i, op2_i, op3_i, dptr_hi, dptr_lo, ri, rn_mem, data_out;
wire [7:0] op1, op2, op3;
wire [7:0] acc, p0_out, p1_out, p2_out, p3_out;
wire [7:0] sp, sp_w;

wire [15:0] pc;

assign wbd_cyc_o = wbd_stb_o;
assign wbi_cyc_o = wbi_stb_o;

//
// ram_rd_sel    ram read (internal)
// ram_wr_sel    ram write (internal)
// src_sel1, src_sel2    from decoder to register
wire src_sel3;
wire [2:0] ram_rd_sel, ram_wr_sel, wr_sfr;
wire [2:0] src_sel2, src_sel1;

//
// wr_addr       ram write addres
// ram_out       data from ram
// rd_addr       data ram read addres
// rd_addr_r     data ram read addres registerd
wire [7:0] ram_data, ram_out, sfr_out, wr_dat;
wire [7:0] wr_addr, rd_addr;
wire sfr_bit;


//
// cy_sel       carry select; from decoder to cy_selct1
// rom_addr_sel rom addres select; alu or pc
// ext_adddr_sel        external addres select; data pointer or Ri
// write_p      output from decoder; write to external ram, go to register;
wire [1:0] cy_sel, bank_sel;
wire rom_addr_sel, rmw, ea_int;

//
// int_uart	interrupt from uart
// tf0		interrupt from t/c 0
// tf1		interrupt from t/c 1
// tr0		timer 0 run
// tr1		timer 1 run
wire reti, intr, int_ack, istb;
wire [7:0] int_src;

//
//alu_op        alu operation (from decoder)
//psw_set       write to psw or not; from decoder to psw (through register)
wire mem_wait;
wire [2:0] mem_act;
wire [3:0] alu_op;
wire [1:0] psw_set;

//
// immediate1_r         from imediate_sel1 to alu_src1_sel1
// immediate2_r         from imediate_sel1 to alu_src2_sel1
// src1. src2, src2     alu sources
// des2, des2           alu destinations
// des1_r               destination 1 registerd (to comp1)
// desCy                carry out
// desAc
// desOv                overflow
// wr                   write to data ram
wire [7:0] src1, src2, des1, des2, des1_r;
wire [7:0] src3;
wire desCy, desAc, desOv, alu_cy, wr, wr_o;


//
// rd           read program rom
// pc_wr_sel    program counter write select (from decoder to pc)
wire rd, pc_wr;
wire [2:0] pc_wr_sel;

//
// op1_n                from op_select to decoder
// op2_n,         output of op_select, to immediate_sel1, pc1, comp1
// op3_n,         output of op_select, to immediate_sel1, ram_wr_sel1
// op2_dr,      output of op_select, to ram_rd_sel1, ram_wr_sel1
wire [7:0] op1_n, op2_n, op3_n;

//
// comp_sel     select source1 and source2 to compare
// eq           result (from comp1 to decoder)
wire [1:0] comp_sel;
wire eq, srcAc, cy, rd_ind, wr_ind;
wire [2:0] op1_cur;


//
// bit_addr     bit addresable instruction
// bit_data     bit data from ram to ram_select
// bit_out      bit data from ram_select to alu and cy_select
wire bit_addr, bit_data, bit_out, bit_addr_o;

//



//
// decoder
oc8051_decoder oc8051_decoder1(.clk(wb_clk_i), .rst(wb_rst_i), .op_in(op1_n), .op1_c(op1_cur),
     .ram_rd_sel(ram_rd_sel), .ram_wr_sel(ram_wr_sel), .bit_addr(bit_addr),
     .src_sel1(src_sel1), .src_sel2(src_sel2),
     .src_sel3(src_sel3), .alu_op(alu_op), .psw_set(psw_set),
     .cy_sel(cy_sel), .wr(wr), .pc_wr(pc_wr),
     .pc_sel(pc_wr_sel), .comp_sel(comp_sel), .eq(eq),
     .wr_sfr(wr_sfr), .rd(rd), .rmw(rmw),
     .istb(istb), .mem_act(mem_act), .mem_wait(mem_wait));


//
//alu
oc8051_alu oc8051_alu1(.rst(wb_rst_i), .clk(wb_clk_i), .op_code(alu_op), .rd(rd),
     .src1(src1), .src2(src2), .src3(src3), .srcCy(alu_cy), .srcAc(srcAc),
     .des1(des1), .des2(des2), .des1_r(des1_r), .desCy(desCy),
     .desAc(desAc), .desOv(desOv), .bit_in(bit_out));

//
//data ram
oc8051_ram_top oc8051_ram_top1(.clk(wb_clk_i), .rst(wb_rst_i), .rd_addr(rd_addr), .rd_data(ram_data),
          .wr_addr(wr_addr), .bit_addr(bit_addr_o), .wr_data(wr_dat), .wr(wr_o && (!wr_addr[7] || wr_ind)),
	  .bit_data_in(desCy), .bit_data_out(bit_data));

//

oc8051_alu_src_sel oc8051_alu_src_sel1(.clk(wb_clk_i), .rst(wb_rst_i), .rd(rd),
     .sel1(src_sel1), .sel2(src_sel2), .sel3(src_sel3),
     .acc(acc), .ram(ram_out), .pc(pc), .dptr({dptr_hi, dptr_lo}),
     .op1(op1_n), .op2(op2_n), .op3(op3_n),
     .src1(src1), .src2(src2), .src3(src3));


//
//
oc8051_comp oc8051_comp1(.sel(comp_sel), .eq(eq), .b_in(bit_out), .cy(cy), .acc(acc), .des(des1_r));


//
//program rom
oc8051_rom oc8051_rom1(.rst(wb_rst_i), .clk(wb_clk_i), .ea_int(ea_int), .addr(wbi_adr_o),
		.data1(op1_i), .data2(op2_i), .data3(op3_i));

//
//
oc8051_cy_select oc8051_cy_select1(.cy_sel(cy_sel), .cy_in(cy), .data_in(bit_out),
		 .data_out(alu_cy));
//
//
oc8051_indi_addr oc8051_indi_addr1 (.clk(wb_clk_i), .rst(wb_rst_i), .rd_addr(rd_addr), .wr_addr(wr_addr),
      .data_in(wr_dat), .wr(wr_o), .wr_bit(bit_addr_o), .rn_out(rn_mem),
      .ri_out(ri), .sel(op1_cur), .bank(bank_sel));


//
//
oc8051_memory_interface oc8051_memory_interface1(.clk(wb_clk_i), .rst(wb_rst_i),
   .wr_i(wr), .wr_o(wr_o), .wr_bit_i(bit_addr), .wr_bit_o(bit_addr_o), .wr_dat(wr_dat),
//rom_addr_sel
   .iack_i(wbi_ack_i), .des1(des1), .des2(des2),
   .iadr_o(wbi_adr_o), .sp_w(sp_w),

//ext_addr_sel
   .dptr({dptr_hi, dptr_lo}), .ri(ri), .rn_mem(rn_mem), .dadr_o(wbd_adr_o), .ddat_o(wbd_dat_o),
   .dwe_o(wbd_we_o), .dstb_o(wbd_stb_o), .ddat_i(wbd_dat_i), .acc(acc), .dack_i(wbd_ack_i),

//ram_addr_sel
   .rd_sel(ram_rd_sel), .wr_sel(ram_wr_sel), .sp(sp), .rn({bank_sel, op1_n[2:0]}),
   .rd_addr(rd_addr), .wr_addr(wr_addr), .rd_ind(rd_ind), .wr_ind(wr_ind),

//op_select
   .ea(ea_in), .ea_int(ea_int),
   .op1_i(op1_i), .op2_i(op2_i), .op3_i(op3_i),
   .idat_i(wbi_dat_i),
   .op1_out(op1_n), .op2_out(op2_n), .op3_out(op3_n),
   .intr(intr), .int_v(int_src), .rd(rd), .int_ack(int_ack), .istb(istb),
   .istb_o(wbi_stb_o),

//pc
   .pc_wr_sel(pc_wr_sel), .pc_wr(pc_wr), .pc(pc),
   .mem_act(mem_act), .mem_wait(mem_wait),
   .bit_in(bit_data), .in_ram(ram_data),
   .sfr(sfr_out), .sfr_bit(sfr_bit), .bit_out(bit_out), .iram_out(ram_out),
   .reti(reti));


//
//

oc8051_sfr oc8051_sfr1(.rst(wb_rst_i), .clk(wb_clk_i), .adr0(rd_addr[7:0]), .adr1(wr_addr[7:0]),
       .dat0(sfr_out), .dat1(wr_dat), .dat2(des2), .we(wr_o && !wr_ind), .bit_in(desCy),
       .bit_out(sfr_bit), .wr_bit(bit_addr_o), .ram_rd_sel(ram_rd_sel), .ram_wr_sel(ram_wr_sel), .wr_sfr(wr_sfr),
// acc
       .acc(acc),
// sp
       .sp(sp), .sp_w(sp_w),
// psw
       .bank_sel(bank_sel), .desAc(desAc), .desOv(desOv), .psw_set(psw_set),
       .srcAc(srcAc), .cy(cy),
// ports
       .rmw(rmw), .p0_out(p0_o), .p1_out(p1_o), .p2_out(p2_o), .p3_out(p3_o),
       .p0_in(p0_i), .p1_in(p1_i), .p2_in(p2_i), .p3_in(p3_i),
// uart
       .rxd(rxd_i), .txd(txd_o),
// int
       .int_ack(int_ack), .intr(intr), .int0(int0_i), .int1(int1_i),
       .reti(reti), .int_src(int_src),
// t/c
       .t0(t0_i), .t1(t1_i), .t2(t2_i), .t2ex(t2ex_i),
// dptr
       .dptr_hi(dptr_hi), .dptr_lo(dptr_lo));


endmodule

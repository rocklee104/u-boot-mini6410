/*
 *  armboot - Startup Code for S3C6400/ARM1176 CPU-core
 *
 *  Copyright (c) 2007	Samsung Electronics
 *
 *
 * See file CREDITS for list of people who contributed to this
 * project.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 *
 * 2007-09-21 - Restructured codes by jsgood (jsgood.yang@samsung.com)
 * 2007-09-21 - Added MoviNAND and OneNAND boot codes by jsgood (jsgood.yang@samsung.com)
 * Base codes by scsuh (sc.suh)
 */

#include <config.h>
#include <version.h>
#ifdef CONFIG_ENABLE_MMU
#include <asm/proc/domain.h>
#endif
#include <regs.h>

#ifndef CONFIG_ENABLE_MMU
#ifndef CFG_PHY_UBOOT_BASE
#define CFG_PHY_UBOOT_BASE	CFG_UBOOT_BASE
#endif
#endif

/*
 *************************************************************************
 *
 * Jump vector table as in table 3.1 in [1]
 *
 *************************************************************************
 */

.globl _start
_start: b	reset
	ldr	pc, _undefined_instruction
	ldr	pc, _software_interrupt
	ldr	pc, _prefetch_abort
	ldr	pc, _data_abort
	ldr	pc, _not_used
	ldr	pc, _irq
	ldr	pc, _fiq

_undefined_instruction:
	.word undefined_instruction
_software_interrupt:
	.word software_interrupt
_prefetch_abort:
	.word prefetch_abort
_data_abort:
	.word data_abort
_not_used:
	.word not_used
_irq:
	.word irq
_fiq:
	.word fiq
_pad:
	.word 0x12345678 /* now 16*4=64 */
.global _end_vect
_end_vect:

	.balignl 16,0xdeadbeef
/*
 *************************************************************************
 *
 * Startup Code (reset vector)
 *
 * do important init only if we don't start from memory!
 * setup Memory and board specific bits prior to relocation.
 * relocate armboot to ram
 * setup stack
 *
 *************************************************************************
 */

_TEXT_BASE:
	.word	TEXT_BASE

/*
 * Below variable is very important because we use MMU in U-Boot.
 * Without it, we cannot run code correctly before MMU is ON.
 * by scsuh.
 */
_TEXT_PHY_BASE:
	.word	CFG_PHY_UBOOT_BASE

.globl _armboot_start
_armboot_start:
	.word _start

/*
 * These are defined in the board-specific linker script.
 */
.globl _bss_start
_bss_start:
	.word __bss_start

.globl _bss_end
_bss_end:
	.word _end

#ifdef CONFIG_USE_IRQ
/* IRQ stack memory (calculated at run-time) */
.globl IRQ_STACK_START
IRQ_STACK_START:
	.word	0x0badc0de

/* IRQ stack memory (calculated at run-time) */
.globl FIQ_STACK_START
FIQ_STACK_START:
	.word 0x0badc0de
#endif

/*
 * the actual reset code
 */

reset:
	/*
	 * set the cpu to SVC32 mode
	 */
	#设置svc32模式,并且关闭fiq/irq
	mrs	r0,cpsr
	bic	r0,r0,#0x1f
	orr	r0,r0,#0xd3
	msr	cpsr,r0

/*
 *************************************************************************
 *
 * CPU_init_critical registers
 *
 * setup important registers
 * setup memory timing
 *
 *************************************************************************
 */
         /*
         * we do sys-critical inits only at reboot,
         * not when booting from ram!
         */
cpu_init_crit:
	/*
	 * flush v4 I/D caches
	 */
	mov	r0, #0
	#使icache/dcache invalidate
	mcr	p15, 0, r0, c7, c7, 0	/* flush v3/v4 cache */
	#Invalidate unified TLB
	mcr	p15, 0, r0, c8, c7, 0	/* flush v4 TLB */

	/*
	 * disable MMU stuff and caches
	 */
	#将控制寄存器中的数值读取到r0中
	mrc	p15, 0, r0, c1, c0, 0
	bic	r0, r0, #0x00002300	@ clear bits 13, 9:8 (--V- --RS)
	bic	r0, r0, #0x00000087	@ clear bits 7, 2:0 (B--- -CAM)
	#Fault checking enabled
	orr	r0, r0, #0x00000002	@ set bit 2 (A) Align
	#使能icache(icache在没有开启MMU时也能使用,但dcache只能在开启MMU后使用)
	orr	r0, r0, #0x00001000	@ set bit 12 (I) I-Cache
	mcr	p15, 0, r0, c1, c0, 0

	/* Peri port setup */
	#设置外围端口的地址空间0x70000000-0x7fffffff,供外设使用
	ldr	r0, =0x70000000
	orr	r0, r0, #0x13
   	mcr	p15,0,r0,c15,c2,4       @ 256M(0x70000000-0x7fffffff)
	/*
	 * Go setup Memory and board specific bits prior to relocation.
	 */
	bl	lowlevel_init	/* go setup pll,mux,memory */

	/* when we already run in ram, we don't need to relocate U-Boot.
	 * and actually, memory controller must be configured before U-Boot
	 * is running in ram.
	 */
	#判断当前u-boot是否在内存RAM中运行,如果是那么运行after_copy,否则顺序执行
	ldr	r0, =0xff000fff
	bic	r1, pc, r0		/* r0 <- current base addr of code */
	/*
	 * _TEXT_BASE也就是TEXT_BASE在board/samsung/smdk6410/config.mk
	 * 中定位为0xc7e00000(mmu on),0x57e00000(mmu off)
	 */
	ldr	r2, _TEXT_BASE		/* r1 <- original base addr in ram */
	bic	r2, r2, r0		/* r0 <- current base addr of code */
	cmp     r1, r2                  /* compare r0, r1                  */
	beq     after_copy		/* r0 == r1 then skip flash copy   */

#ifdef CONFIG_BOOT_NAND
	#copy 4k
	mov	r0, #0x1000
	bl	copy_from_nand
#endif

#ifdef CONFIG_BOOT_MOVINAND
	ldr	sp, _TEXT_PHY_BASE
	bl	movi_bl2_copy
	b	after_copy
#endif

after_copy:
	#GPIO寄存器基址
	ldr	r0, =ELFIN_GPIO_BASE
	ldr	r1, =0xC00
	str	r1, [r0, #GPPDAT_OFFSET]
	ldr	r1, [r0, #GPFPUD_OFFSET]
	bic	r1, r1, #0xc0000000
	orr	r1, r1, #0x80000000
	str	r1, [r0, #GPFPUD_OFFSET]
	ldr	r1, [r0, #GPFDAT_OFFSET]
	orr	r1, r1, #0x8000
	str	r1, [r0, #GPFDAT_OFFSET]
	ldr	r1, [r0, #GPFCON_OFFSET]
	bic	r1, r1, #0xc0000000
	orr	r1, r1, #0x40000000
	str	r1, [r0, #GPFCON_OFFSET]

#ifdef CONFIG_ENABLE_MMU
#开启MMU
enable_mmu:
	/* enable domain access */
	#D0-D7设置成manager模式
	ldr	r5, =0x0000ffff
	mcr	p15, 0, r5, c3, c0, 0		@ load domain access register

	/* Set the TTB register */
	#获取页表基址的虚拟地址, 0xc7e30000
	ldr	r0, _mmu_table_base
	#获取u-boot在内存中的二进制文件物理地址,0x57e00000
	ldr	r1, =CFG_PHY_UBOOT_BASE
	ldr	r2, =0xfff00000
	#r0保留页表的段内地址,0x30000
	bic	r0, r0, r2
	orr	r1, r0, r1
	#保存页表基址,0x57e30000
	mcr	p15, 0, r1, c2, c0, 0

	/* Enable the MMU */
mmu_on:
	mrc	p15, 0, r0, c1, c0, 0
	orr	r0, r0, #1			/* Set CR_M to enable MMU */
	mcr	p15, 0, r0, c1, c0, 0
	nop
	nop
	nop
	nop
#endif

skip_hw_init:
	/* Set up the stack						    */
stack_setup:
#ifdef CONFIG_MEMORY_UPPER_CODE
	#CFG_UBOOT_BASE=0xc7e00000,CFG_UBOOT_SIZE=2MB
	ldr	sp, =(CFG_UBOOT_BASE + CFG_UBOOT_SIZE - 0xc)
#else
	#_TEXT_BASE=0xc7e00000
	ldr	r0, _TEXT_BASE		/* upper 128 KiB: relocated uboot   */
	sub	r0, r0, #CFG_MALLOC_LEN	/* malloc area                      */
	sub	r0, r0, #CFG_GBL_DATA_SIZE /* bdinfo                        */
#ifdef CONFIG_USE_IRQ
	sub	r0, r0, #(CONFIG_STACKSIZE_IRQ+CONFIG_STACKSIZE_FIQ)
#endif
	sub	sp, r0, #12		/* leave 3 words for abort-stack    */

#endif

clear_bss:
	ldr	r0, _bss_start		/* find start of bss segment        */
	ldr	r1, _bss_end		/* stop here                        */
	mov 	r2, #0x00000000		/* clear                            */

clbss_l:
	str	r2, [r0]		/* clear loop...                    */
	add	r0, r0, #4
	cmp	r0, r1
	ble	clbss_l

	ldr	pc, _start_armboot
#c语言环境设置完成后就可以调用c函数了

_start_armboot:
	.word start_armboot

#ifdef CONFIG_ENABLE_MMU
_mmu_table_base:
	.word mmu_table
#endif

/*
 * copy U-Boot to SDRAM and jump to ram (from NAND or OneNAND)
 * r0: size to be compared
 * Load 1'st 2blocks to RAM because U-boot's size is larger than 1block(128k) size
 */
	.globl copy_from_nand
copy_from_nand:
	mov	r10, lr		/* save return address */

	#需要copy的大小保存到r9中
	mov	r9, r0
	/* get ready to call C functions */
	#_TEXT_PHY_BASE也就是CFG_PHY_UBOOT_BASE = 0x57e00000
	ldr	sp, _TEXT_PHY_BASE	/* setup temp stack pointer */
	sub	sp, sp, #12
	mov	fp, #0			/* no previous frame, so fp=0 */
	mov	r9, #0x1000
	bl	copy_uboot_to_ram

	#判断copy过程是否成功
3:	tst 	r0, #0x0
	bne	copy_failed

	#0x0c000000是stepping stone的物理地址
	ldr	r0, =0x0c000000
	ldr	r1, _TEXT_PHY_BASE
1:	ldr	r3, [r0], #4
	ldr	r4, [r1], #4
	teq	r3, r4
	bne	compare_failed	/* not matched */
	subs	r9, r9, #4
	#比较stepping stone和0x57e00000的前4k内容
	bne	1b

4:	mov	lr, r10		/* all is OK */
	#返回下一语句 --- after_copy
	mov	pc, lr

copy_failed:
	nop			/* copy from nand failed */
	b	copy_failed

compare_failed:
	nop			/* compare failed */
	b	compare_failed

/*
 * we assume that cache operation is done before. (eg. cleanup_before_linux())
 * actually, we don't need to do anything about cache if not use d-cache in U-Boot
 * So, in this function we clean only MMU. by scsuh
 *
 * void	theLastJump(void *kernel, int arch_num, uint boot_params);
 */
#ifdef CONFIG_ENABLE_MMU
	.globl theLastJump
theLastJump:
	mov	r9, r0
	ldr	r3, =0xfff00000
	ldr	r4, _TEXT_PHY_BASE
	adr	r5, phy_last_jump
	bic	r5, r5, r3
	orr	r5, r5, r4
	mov	pc, r5
phy_last_jump:
	/*
	 * disable MMU stuff
	 */
	mrc	p15, 0, r0, c1, c0, 0
	bic	r0, r0, #0x00002300	/* clear bits 13, 9:8 (--V- --RS) */
	bic	r0, r0, #0x00000087	/* clear bits 7, 2:0 (B--- -CAM) */
	orr	r0, r0, #0x00000002	/* set bit 2 (A) Align */
	orr	r0, r0, #0x00001000	/* set bit 12 (I) I-Cache */
	mcr	p15, 0, r0, c1, c0, 0

	mcr	p15, 0, r0, c8, c7, 0	/* flush v4 TLB */

	mov	r0, #0
	mov	pc, r9
#endif
/*
 *************************************************************************
 *
 * Interrupt handling
 *
 *************************************************************************
 */
@
@ IRQ stack frame.
@
#define S_FRAME_SIZE	72

#define S_OLD_R0	68
#define S_PSR		64
#define S_PC		60
#define S_LR		56
#define S_SP		52

#define S_IP		48
#define S_FP		44
#define S_R10		40
#define S_R9		36
#define S_R8		32
#define S_R7		28
#define S_R6		24
#define S_R5		20
#define S_R4		16
#define S_R3		12
#define S_R2		8
#define S_R1		4
#define S_R0		0

#define MODE_SVC 0x13
#define I_BIT	 0x80

/*
 * use bad_save_user_regs for abort/prefetch/undef/swi ...
 * use irq_save_user_regs / irq_restore_user_regs for IRQ/FIQ handling
 */

	.macro	bad_save_user_regs
	sub	sp, sp, #S_FRAME_SIZE		@ carve out a frame on current user stack
	stmia	sp, {r0 - r12}			@ Save user registers (now in svc mode) r0-r12

	ldr	r2, _armboot_start
	sub	r2, r2, #(CFG_MALLOC_LEN)
	sub	r2, r2, #(CFG_GBL_DATA_SIZE+8)	@ set base 2 words into abort stack
	ldmia	r2, {r2 - r3}			@ get values for "aborted" pc and cpsr (into parm regs)
	add	r0, sp, #S_FRAME_SIZE		@ grab pointer to old stack

	add	r5, sp, #S_SP
	mov	r1, lr
	stmia	r5, {r0 - r3}			@ save sp_SVC, lr_SVC, pc, cpsr
	mov	r0, sp				@ save current stack into r0 (param register)
	.endm

	.macro	irq_save_user_regs
	sub	sp, sp, #S_FRAME_SIZE
	stmia	sp, {r0 - r12}			@ Calling r0-r12
	add	r8, sp, #S_PC			@ !!!! R8 NEEDS to be saved !!!! a reserved stack spot would be good.
	stmdb	r8, {sp, lr}^			@ Calling SP, LR
	str	lr, [r8, #0]			@ Save calling PC
	mrs	r6, spsr
	str	r6, [r8, #4]			@ Save CPSR
	str	r0, [r8, #8]			@ Save OLD_R0
	mov	r0, sp
	.endm

	.macro	irq_restore_user_regs
	ldmia	sp, {r0 - lr}^			@ Calling r0 - lr
	mov	r0, r0
	ldr	lr, [sp, #S_PC]			@ Get PC
	add	sp, sp, #S_FRAME_SIZE
	subs	pc, lr, #4			@ return & move spsr_svc into cpsr
	.endm

	.macro get_bad_stack
	ldr	r13, _armboot_start		@ setup our mode stack (enter in banked mode)
	sub	r13, r13, #(CFG_MALLOC_LEN)	@ move past malloc pool
	sub	r13, r13, #(CFG_GBL_DATA_SIZE+8) @ move to reserved a couple spots for abort stack

	str	lr, [r13]			@ save caller lr in position 0 of saved stack
	mrs	lr, spsr			@ get the spsr
	str	lr, [r13, #4]			@ save spsr in position 1 of saved stack

	mov	r13, #MODE_SVC			@ prepare SVC-Mode
	@ msr	spsr_c, r13
	msr	spsr, r13			@ switch modes, make sure moves will execute
	mov	lr, pc				@ capture return pc
	movs	pc, lr				@ jump to next instruction & switch modes.
	.endm

	.macro get_bad_stack_swi
	sub	r13, r13, #4			@ space on current stack for scratch reg.
	str	r0, [r13]			@ save R0's value.
	ldr	r0, _armboot_start		@ get data regions start
	sub	r0, r0, #(CFG_MALLOC_LEN)	@ move past malloc pool
	sub	r0, r0, #(CFG_GBL_DATA_SIZE+8)	@ move past gbl and a couple spots for abort stack
	str	lr, [r0]			@ save caller lr in position 0 of saved stack
	mrs	r0, spsr			@ get the spsr
	str	lr, [r0, #4]			@ save spsr in position 1 of saved stack
	ldr	r0, [r13]			@ restore r0
	add	r13, r13, #4			@ pop stack entry
	.endm

	.macro get_irq_stack			@ setup IRQ stack
	ldr	sp, IRQ_STACK_START
	.endm

	.macro get_fiq_stack			@ setup FIQ stack
	ldr	sp, FIQ_STACK_START
	.endm

/*
 * exception handlers
 */
	.align	5
undefined_instruction:
	get_bad_stack
	bad_save_user_regs
	bl	do_undefined_instruction

	.align	5
software_interrupt:
	get_bad_stack_swi
	bad_save_user_regs
	bl	do_software_interrupt

	.align	5
prefetch_abort:
	get_bad_stack
	bad_save_user_regs
	bl	do_prefetch_abort

	.align	5
data_abort:
	get_bad_stack
	bad_save_user_regs
	bl	do_data_abort

	.align	5
not_used:
	get_bad_stack
	bad_save_user_regs
	bl	do_not_used

#ifdef CONFIG_USE_IRQ

	.align	5
irq:
	get_irq_stack
	irq_save_user_regs
	bl	do_irq
	irq_restore_user_regs

	.align	5
fiq:
	get_fiq_stack
	/* someone ought to write a more effiction fiq_save_user_regs */
	irq_save_user_regs
	bl	do_fiq
	irq_restore_user_regs

#else

	.align	5
irq:
	get_bad_stack
	bad_save_user_regs
	bl	do_irq

	.align	5
fiq:
	get_bad_stack
	bad_save_user_regs
	bl	do_fiq

#endif
	.align 5
.global arm1136_cache_flush
arm1136_cache_flush:
		mcr	p15, 0, r1, c7, c5, 0	@ invalidate I cache
		mov	pc, lr			@ back to caller

#if defined(CONFIG_INTEGRATOR) && defined(CONFIG_ARCH_CINTEGRATOR)
/* Use the IntegratorCP function from board/integratorcp/platform.S */
#elif defined(CONFIG_S3C64XX)
/* For future usage of S3C64XX*/
#else
	.align	5
.globl reset_cpu
reset_cpu:
	ldr	r1, rstctl	/* get addr for global reset reg */
	mov	r3, #0x2	/* full reset pll+mpu */
	str	r3, [r1]	/* force reset */
	mov	r0, r0
_loop_forever:
	b	_loop_forever
rstctl:
	.word	PM_RSTCTRL_WKUP

#endif

#
# (C) Copyright 2000-2006
# Wolfgang Denk, DENX Software Engineering, wd@denx.de.
#
# See file CREDITS for list of people who contributed to this
# project.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundatio; either version 2 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA 02111-1307 USA
#

VERSION = 1
PATCHLEVEL = 1
SUBLEVEL = 6
EXTRAVERSION =
U_BOOT_VERSION = $(VERSION).$(PATCHLEVEL).$(SUBLEVEL)$(EXTRAVERSION)
VERSION_FILE = $(obj)include/version_autogenerated.h

HOSTARCH := $(shell uname -m | \
	sed -e s/i.86/i386/ \
	    -e s/sun4u/sparc64/ \
	    -e s/arm.*/arm/ \
	    -e s/sa110/arm/ \
	    -e s/powerpc/ppc/ \
	    -e s/macppc/ppc/)

HOSTOS := $(shell uname -s | tr '[:upper:]' '[:lower:]' | \
	    sed -e 's/\(cygwin\).*/cygwin/')

export	HOSTARCH HOSTOS

# Deal with colliding definitions from tcsh etc.
VENDOR=

#########################################################################
#
# U-boot build supports producing a object files to the separate external
# directory. Two use cases are supported:
#
# 1) Add O= to the make command line
# 'make O=/tmp/build all'
#
# 2) Set environement variable BUILD_DIR to point to the desired location
# 'export BUILD_DIR=/tmp/build'
# 'make'
#
# The second approach can also be used with a MAKEALL script
# 'export BUILD_DIR=/tmp/build'
# './MAKEALL'
#
# Command line 'O=' setting overrides BUILD_DIR environent variable.
#
# When none of the above methods is used the local build is performed and
# the object files are placed in the source directory.
#

ifdef O
ifeq ("$(origin O)", "command line")
BUILD_DIR := $(O)
endif
endif

ifneq ($(BUILD_DIR),)
saved-output := $(BUILD_DIR)

# Attempt to create a output directory.
$(shell [ -d ${BUILD_DIR} ] || mkdir -p ${BUILD_DIR})

# Verify if it was successful.
BUILD_DIR := $(shell cd $(BUILD_DIR) && /bin/pwd)
$(if $(BUILD_DIR),,$(error output directory "$(saved-output)" does not exist))
endif # ifneq ($(BUILD_DIR),)

OBJTREE		:= $(if $(BUILD_DIR),$(BUILD_DIR),$(CURDIR))
SRCTREE		:= $(CURDIR)
TOPDIR		:= $(SRCTREE)
LNDIR		:= $(OBJTREE)
export	TOPDIR SRCTREE OBJTREE

MKCONFIG	:= $(SRCTREE)/mkconfig
export MKCONFIG

ifneq ($(OBJTREE),$(SRCTREE))
REMOTE_BUILD	:= 1
export REMOTE_BUILD
endif

# $(obj) and (src) are defined in config.mk but here in main Makefile
# we also need them before config.mk is included which is the case for
# some targets like unconfig, clean, clobber, distclean, etc.
ifneq ($(OBJTREE),$(SRCTREE))
obj := $(OBJTREE)/
src := $(SRCTREE)/
else
obj :=
src :=
endif
export obj src

#########################################################################

ifeq ($(OBJTREE)/include/config.mk,$(wildcard $(OBJTREE)/include/config.mk))

# load ARCH, BOARD, and CPU configuration
include $(OBJTREE)/include/config.mk
export	ARCH CPU BOARD VENDOR SOC

ifndef CROSS_COMPILE
ifeq ($(HOSTARCH),ppc)
CROSS_COMPILE =
else
ifeq ($(ARCH),ppc)
CROSS_COMPILE = powerpc-linux-
endif
ifeq ($(ARCH),arm)
CROSS_COMPILE = arm-linux-
endif
ifeq ($(ARCH),i386)
ifeq ($(HOSTARCH),i386)
CROSS_COMPILE =
else
CROSS_COMPILE = i386-linux-
endif
endif
ifeq ($(ARCH),mips)
CROSS_COMPILE = mips_4KC-
endif
ifeq ($(ARCH),nios)
CROSS_COMPILE = nios-elf-
endif
ifeq ($(ARCH),nios2)
CROSS_COMPILE = nios2-elf-
endif
ifeq ($(ARCH),m68k)
CROSS_COMPILE = m68k-elf-
endif
ifeq ($(ARCH),microblaze)
CROSS_COMPILE = mb-
endif
ifeq ($(ARCH),blackfin)
CROSS_COMPILE = bfin-elf-
endif
ifeq ($(ARCH),avr32)
CROSS_COMPILE = avr32-
endif
endif
endif

CROSS_COMPILE = arm-linux-
export	CROSS_COMPILE

# load other configuration
include $(TOPDIR)/config.mk

#########################################################################
# U-Boot objects....order is important (i.e. start must be first)

OBJS  = cpu/$(CPU)/start.o
ifeq ($(CPU),i386)
OBJS += cpu/$(CPU)/start16.o
OBJS += cpu/$(CPU)/reset.o
endif
ifeq ($(CPU),ppc4xx)
OBJS += cpu/$(CPU)/resetvec.o
endif
ifeq ($(CPU),mpc85xx)
OBJS += cpu/$(CPU)/resetvec.o
endif
ifeq ($(CPU),mpc86xx)
OBJS += cpu/$(CPU)/resetvec.o
endif
ifeq ($(CPU),bf533)
OBJS += cpu/$(CPU)/start1.o	cpu/$(CPU)/interrupt.o	cpu/$(CPU)/cache.o
OBJS += cpu/$(CPU)/cplbhdlr.o	cpu/$(CPU)/cplbmgr.o	cpu/$(CPU)/flush.o
endif

OBJS := $(addprefix $(obj),$(OBJS))

LIBS  = lib_generic/libgeneric.a
LIBS += board/$(BOARDDIR)/lib$(BOARD).a
LIBS += cpu/$(CPU)/lib$(CPU).a
ifdef SOC
LIBS += cpu/$(CPU)/$(SOC)/lib$(SOC).a
endif
LIBS += lib_$(ARCH)/lib$(ARCH).a
LIBS += fs/cramfs/libcramfs.a fs/fat/libfat.a fs/fdos/libfdos.a fs/jffs2/libjffs2.a \
	fs/reiserfs/libreiserfs.a fs/ext2/libext2fs.a
LIBS += net/libnet.a
LIBS += disk/libdisk.a
LIBS += rtc/librtc.a
LIBS += dtt/libdtt.a
LIBS += drivers/libdrivers.a
LIBS += drivers/nand/libnand.a
LIBS += drivers/nand_legacy/libnand_legacy.a
# add to support onenand. by scsuh
LIBS += drivers/onenand/libonenand.a
ifeq ($(CPU),mpc83xx)
LIBS += drivers/qe/qe.a
endif
LIBS += drivers/sk98lin/libsk98lin.a
LIBS += post/libpost.a post/cpu/libcpu.a
LIBS += common/libcommon.a
LIBS += $(BOARDLIBS)

LIBS := $(addprefix $(obj),$(LIBS))
.PHONY : $(LIBS)

# Add GCC lib
PLATFORM_LIBS += -L $(shell dirname `$(CC) $(CFLAGS) -print-libgcc-file-name`) -lgcc

# The "tools" are needed early, so put this first
# Don't include stuff already done in $(LIBS)
SUBDIRS	= tools \
	  examples \
	  post \
	  post/cpu
.PHONY : $(SUBDIRS)

ifeq ($(CONFIG_NAND_U_BOOT),y)
NAND_SPL = nand_spl
U_BOOT_NAND = $(obj)u-boot-nand.bin
endif

__OBJS := $(subst $(obj),,$(OBJS))
__LIBS := $(subst $(obj),,$(LIBS))

#########################################################################
#########################################################################

ALL = $(obj)u-boot.srec $(obj)u-boot.bin $(obj)System.map $(U_BOOT_NAND)

all:		$(ALL)

$(obj)u-boot.hex:	$(obj)u-boot
		$(OBJCOPY) ${OBJCFLAGS} -O ihex $< $@

$(obj)u-boot.srec:	$(obj)u-boot
		$(OBJCOPY) ${OBJCFLAGS} -O srec $< $@

$(obj)u-boot.bin:	$(obj)u-boot
		$(OBJCOPY) ${OBJCFLAGS} -O binary $< $@
		$(OBJDUMP) -d $< > $<.dis
		cp $@ /tftp

$(obj)u-boot.img:	$(obj)u-boot.bin
		./tools/mkimage -A $(ARCH) -T firmware -C none \
		-a $(TEXT_BASE) -e 0 \
		-n $(shell sed -n -e 's/.*U_BOOT_VERSION//p' $(VERSION_FILE) | \
			sed -e 's/"[	 ]*$$/ for $(BOARD) board"/') \
		-d $< $@

$(obj)u-boot.dis:	$(obj)u-boot
		$(OBJDUMP) -d $< > $@

$(obj)u-boot:		depend version $(SUBDIRS) $(OBJS) $(LIBS) $(LDSCRIPT)
		UNDEF_SYM=`$(OBJDUMP) -x $(LIBS) |sed  -n -e 's/.*\(__u_boot_cmd_.*\)/-u\1/p'|sort|uniq`;\
		cd $(LNDIR) && $(LD) $(LDFLAGS) $$UNDEF_SYM $(__OBJS) \
			--start-group $(__LIBS) --end-group $(PLATFORM_LIBS) \
			-Map u-boot.map -o u-boot

$(OBJS):
		$(MAKE) -C cpu/$(CPU) $(if $(REMOTE_BUILD),$@,$(notdir $@))

$(LIBS):
		$(MAKE) -C $(dir $(subst $(obj),,$@))

$(SUBDIRS):
		$(MAKE) -C $@ all

$(NAND_SPL):	version
		$(MAKE) -C nand_spl/board/$(BOARDDIR) all

$(U_BOOT_NAND):	$(NAND_SPL) $(obj)u-boot.bin
		cat $(obj)nand_spl/u-boot-spl-16k.bin $(obj)u-boot.bin > $(obj)u-boot-nand.bin

version:
		@echo -n "#define U_BOOT_VERSION \"U-Boot " > $(VERSION_FILE); \
		echo -n "$(U_BOOT_VERSION)" >> $(VERSION_FILE); \
		echo -n $(shell $(CONFIG_SHELL) $(TOPDIR)/tools/setlocalversion \
			 $(TOPDIR)) >> $(VERSION_FILE); \
		echo "\"" >> $(VERSION_FILE)

gdbtools:
		$(MAKE) -C tools/gdb all || exit 1

updater:
		$(MAKE) -C tools/updater all || exit 1

env:
		$(MAKE) -C tools/env all || exit 1

depend dep:
		for dir in $(SUBDIRS) ; do $(MAKE) -C $$dir _depend ; done

tags ctags:
		ctags -w -o $(OBJTREE)/ctags `find $(SUBDIRS) include \
				lib_generic board/$(BOARDDIR) cpu/$(CPU) lib_$(ARCH) \
				fs/cramfs fs/fat fs/fdos fs/jffs2 \
				net disk rtc dtt drivers drivers/sk98lin common \
			\( -name CVS -prune \) -o \( -name '*.[ch]' -print \)`

etags:
		etags -a -o $(OBJTREE)/etags `find $(SUBDIRS) include \
				lib_generic board/$(BOARDDIR) cpu/$(CPU) lib_$(ARCH) \
				fs/cramfs fs/fat fs/fdos fs/jffs2 \
				net disk rtc dtt drivers drivers/sk98lin common \
			\( -name CVS -prune \) -o \( -name '*.[ch]' -print \)`

$(obj)System.map:	$(obj)u-boot
		@$(NM) $< | \
		grep -v '\(compiled\)\|\(\.o$$\)\|\( [aUw] \)\|\(\.\.ng$$\)\|\(LASH[RL]DI\)' | \
		sort > $(obj)System.map

#########################################################################
else
all $(obj)u-boot.hex $(obj)u-boot.srec $(obj)u-boot.bin \
$(obj)u-boot.img $(obj)u-boot.dis $(obj)u-boot \
$(SUBDIRS) version gdbtools updater env depend \
dep tags ctags etags $(obj)System.map:
	@echo "System not configured - see README" >&2
	@ exit 1
endif

.PHONY : CHANGELOG
CHANGELOG:
	git log --no-merges U-Boot-1_1_5.. | \
	unexpand -a | sed -e 's/\s\s*$$//' > $@

#########################################################################

unconfig:
	@rm -f $(obj)include/config.h $(obj)include/config.mk \
		$(obj)board/*/config.tmp $(obj)board/*/*/config.tmp
#========================================================================
# ARM
#========================================================================
smdk6400_config	:	unconfig
	@$(MKCONFIG) $(@:_config=) arm s3c64xx smdk6400 samsung s3c6400 

smdk6410_config	:	unconfig
	@$(MKCONFIG) $(@:_config=) arm s3c64xx smdk6410 samsung s3c6410 

mini6410_nand_config-ram128 :  unconfig
	@$(MKCONFIG) mini6410 arm s3c64xx mini6410 samsung s3c6410 NAND ram128

mini6410_sd_config-ram128 :    unconfig
	@$(MKCONFIG) mini6410 arm s3c64xx mini6410 samsung s3c6410 SD ram128

mini6410_nand_config-ram256 :  unconfig
	@$(MKCONFIG) mini6410 arm s3c64xx mini6410 samsung s3c6410 NAND ram256

mini6410_sd_config-ram256 :    unconfig
	@$(MKCONFIG) mini6410 arm s3c64xx mini6410 samsung s3c6410 SD ram256
#########################################################################
#########################################################################

clean:
	find $(OBJTREE) -type f \
		\( -name 'core' -o -name '*.bak' -o -name '*~' \
		-o -name '*~' -o -name '.depend*' \
		-o -name '*.o'  -o -name '*.a'  \) -print \
		| xargs rm -f
	rm -f u-boot*
	rm -f $(obj)examples/hello_world $(obj)examples/timer \
	      $(obj)examples/eepro100_eeprom $(obj)examples/sched \
	      $(obj)examples/mem_to_mem_idma2intr $(obj)examples/82559_eeprom \
	      $(obj)examples/smc91111_eeprom $(obj)examples/interrupt \
	      $(obj)examples/test_burst $(obj)examples/hello_world.srec
	rm -f $(obj)tools/img2srec $(obj)tools/mkimage $(obj)tools/envcrc \
		$(obj)tools/gen_eth_addr
	rm -f $(obj)tools/mpc86x_clk $(obj)tools/ncb
	rm -f $(obj)tools/easylogo/easylogo $(obj)tools/bmp_logo
	rm -f $(obj)tools/gdb/astest $(obj)tools/gdb/gdbcont $(obj)tools/gdb/gdbsend
	rm -f $(obj)tools/env/fw_printenv $(obj)tools/env/fw_setenv
	rm -f $(obj)board/cray/L1/bootscript.c $(obj)board/cray/L1/bootscript.image
	rm -f $(obj)board/netstar/eeprom $(obj)board/netstar/crcek $(obj)board/netstar/crcit
	rm -f $(obj)board/netstar/*.srec $(obj)board/netstar/*.bin
	rm -f $(obj)board/trab/trab_fkt $(obj)board/voiceblue/eeprom
	rm -f $(obj)board/integratorap/u-boot.lds $(obj)board/integratorcp/u-boot.lds
	rm -f $(obj)include/bmp_logo.h $(obj)include/asm-arm/arch
	rm -f $(obj)include/asm-arm/proc $(obj)include/config.h
	rm -f $(obj)include/config.mk $(obj)include/version_autogenerated.h
	rm -f $(obj)nand_spl/u-boot-spl $(obj)nand_spl/u-boot-spl.map
	rm -f $(obj)System.map

clobber:	clean
	find $(OBJTREE) -type f \( -name .depend \
		-o -name '*.srec' -o -name '*.bin' -o -name u-boot.img \) \
		-print0 \
		| xargs -0 rm -f
	rm -f $(OBJS) $(obj)*.bak $(obj)ctags $(obj)etags $(obj)TAGS $(obj)include/version_autogenerated.h
	rm -fr $(obj)*.*~
	rm -f $(obj)u-boot $(obj)u-boot.map $(obj)u-boot.hex $(ALL)
	rm -f $(obj)tools/crc32.c $(obj)tools/environment.c $(obj)tools/env/crc32.c
	rm -f $(obj)tools/inca-swap-bytes $(obj)cpu/mpc824x/bedbug_603e.c
	rm -f $(obj)include/asm/proc $(obj)include/asm/arch $(obj)include/asm
	[ ! -d $(OBJTREE)/nand_spl ] || find $(obj)nand_spl -lname "*" -print | xargs rm -f

ifeq ($(OBJTREE),$(SRCTREE))
mrproper \
distclean:	clobber unconfig
else
mrproper \
distclean:	clobber unconfig
	rm -rf $(OBJTREE)/*
endif

backup:
	F=`basename $(TOPDIR)` ; cd .. ; \
	gtar --force-local -zcvf `date "+$$F-%Y-%m-%d-%T.tar.gz"` $$F

#########################################################################

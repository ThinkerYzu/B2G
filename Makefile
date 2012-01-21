# To support gonk's build/envsetup.sh
SHELL = bash

-include local.mk
-include .config.mk

.DEFAULT: build

MAKE_FLAGS ?= -j16
GONK_MAKE_FLAGS ?=

FASTBOOT ?= fastboot
HEIMDALL ?= heimdall
TOOLCHAIN_HOST = linux-x86
TOOLCHAIN_PATH = ./glue/gonk/prebuilt/$(TOOLCHAIN_HOST)/toolchain/arm-eabi-4.4.3/bin

GONK_PATH = $(abspath glue/gonk)
GONK_TARGET ?= full_$(GONK)-eng

# This path includes tools to simulate JDK tools.  Gonk would check
# version of JDK.  These fake tools do nothing but print out version
# number to stop gonk from error.
FAKE_JDK_PATH ?= $(abspath $(GONK_PATH)/device/gonk-build-hack/fake-jdk-tools)

define GONK_CMD # $(call GONK_CMD,cmd)
	cd $(GONK_PATH) && \
	. build/envsetup.sh && \
	lunch $(GONK_TARGET) && \
	export USE_CCACHE="yes" && \
	export PATH=$$PATH:$(FAKE_JDK_PATH) && \
	$(1)
endef

GECKO_PATH ?= $(abspath gecko)

ANDROID_SDK_PLATFORM ?= android-13
GECKO_CONFIGURE_ARGS ?=

CCACHE ?= $(shell which ccache)
ADB ?= $(abspath glue/gonk/out/host/linux-x86/bin/adb)

.PHONY: build
build: gecko gecko-install-hack gonk

ifeq (qemu,$(KERNEL))
build: kernel bootimg-hack
endif

KERNEL_DIR = boot/kernel-android-$(KERNEL)
GECKO_OBJDIR = $(GECKO_PATH)/objdir-prof-gonk

.PHONY: gecko
# XXX Hard-coded for prof-android target.  It would also be nice if
# client.mk understood the |package| target.
gecko:
	@export MAKE_FLAGS=$(MAKE_FLAGS) && \
	export CONFIGURE_ARGS="$(GECKO_CONFIGURE_ARGS)" && \
	export GONK_PRODUCT="$(GONK)" && \
	export GONK_PATH="$(GONK_PATH)" && \
	ulimit -n 4096 && \
	$(MAKE) -C $(GECKO_PATH) -f client.mk -s $(MAKE_FLAGS) && \
	$(MAKE) -C $(GECKO_OBJDIR) package

.PHONY: gonk
gonk: gaia-hack
	@$(call GONK_CMD,$(MAKE) $(MAKE_FLAGS) $(GONK_MAKE_FLAGS))
ifeq (qemu,$(KERNEL))
	@cp glue/gonk/system/core/rootdir/init.rc.gonk $(GONK_PATH)/out/target/product/$(GONK)/root/init.rc
endif

.PHONY: kernel
# XXX Hard-coded for nexuss4g target
# XXX Hard-coded for gonk tool support
kernel:
ifeq (galaxy-s2,$(KERNEL))
	@PATH="$$PATH:$(abspath $(TOOLCHAIN_PATH))" $(MAKE) -C $(KERNEL_PATH) $(MAKE_FLAGS) ARCH=arm CROSS_COMPILE="$(CCACHE) arm-eabi-" modules
	(rm -rf boot/initramfs && cd boot/clockworkmod_galaxys2_initramfs && git checkout-index -a -f --prefix ../initramfs/)
	find "$(KERNEL_DIR)" -name "*.ko" | xargs -I MOD cp MOD "$(PWD)/boot/initramfs/lib/modules"
endif
	@PATH="$$PATH:$(abspath $(TOOLCHAIN_PATH))" $(MAKE) -C $(KERNEL_PATH) $(MAKE_FLAGS) ARCH=arm CROSS_COMPILE="$(CCACHE) arm-eabi-"

.PHONY: clean
clean: clean-gecko clean-gonk clean-kernel

.PHONY: clean-gecko
clean-gecko:
	rm -rf $(GECKO_OBJDIR)

.PHONY: clean-gonk
clean-gonk:
	@$(call GONK_CMD,$(MAKE) clean)

.PHONY: clean-kernel
clean-kernel:
	@PATH="$$PATH:$(abspath $(TOOLCHAIN_PATH))" $(MAKE) -C $(KERNEL_PATH) ARCH=arm CROSS_COMPILE=arm-eabi- clean

.PHONY: mrproper
# NB: this is a VERY DANGEROUS command that will BLOW AWAY ALL
# outstanding changes you have.  It's mostly intended for "clean room"
# builds.
mrproper:
	git submodule foreach 'git clean -dfx' && \
	git submodule foreach 'git reset --hard' && \
	git clean -dfx && \
	git reset --hard

.PHONY: config-galaxy-s2
config-galaxy-s2: config-gecko $(ADB)
	@echo "KERNEL = galaxy-s2" > .config.mk && \
        echo "KERNEL_PATH = ./boot/kernel-android-galaxy-s2" >> .config.mk && \
	echo "GONK = galaxys2" >> .config.mk && \
	export PATH=$$PATH:$$(dirname $(ADB)) && \
	cp -p config/kernel-galaxy-s2 boot/kernel-android-galaxy-s2/.config && \
	cd $(GONK_PATH)/device/samsung/galaxys2/ && \
	echo Extracting binary blobs from device, which should be plugged in! ... && \
	./extract-files.sh && \
	echo OK

.PHONY: config-maguro
config-maguro: config-gecko
	@echo "KERNEL = msm" > .config.mk && \
        echo "KERNEL_PATH = ./boot/msm" >> .config.mk && \
	echo "GONK = maguro" >> .config.mk && \
	cd $(GONK_PATH)/device/toro/maguro && \
	echo Extracting binary blobs from device, which should be plugged in! ... && \
	./extract-files.sh && \
	echo OK

.PHONY: config-gecko
config-gecko:
	@ln -sf $(PWD)/config/gecko-prof-gonk $(GECKO_PATH)/mozconfig

%.tgz:
	wget https://dl.google.com/dl/android/aosp/$@

NEXUS_S_BUILD = grj90
extract-broadcom-crespo4g.sh: broadcom-crespo4g-$(NEXUS_S_BUILD)-c4ec9a38.tgz
	tar zxvf $< && ./$@
extract-imgtec-crespo4g.sh: imgtec-crespo4g-$(NEXUS_S_BUILD)-a8e2ce86.tgz
	tar zxvf $< && ./$@
extract-nxp-crespo4g.sh: nxp-crespo4g-$(NEXUS_S_BUILD)-9abcae18.tgz
	tar zxvf $< && ./$@
extract-samsung-crespo4g.sh: samsung-crespo4g-$(NEXUS_S_BUILD)-9474e48f.tgz
	tar zxvf $< && ./$@

.PHONY: blobs-nexuss4g
blobs-nexuss4g: extract-broadcom-crespo4g.sh extract-imgtec-crespo4g.sh extract-nxp-crespo4g.sh extract-samsung-crespo4g.sh

.PHONY: config-nexuss4g
config-nexuss4g: blobs-nexuss4g config-gecko
	@echo "KERNEL = samsung" > .config.mk && \
        echo "KERNEL_PATH = ./boot/kernel-android-samsung" >> .config.mk && \
	echo "GONK = crespo4g" >> .config.mk && \
	cp -p config/kernel-nexuss4g boot/kernel-android-samsung/.config && \
	$(MAKE) -C $(CURDIR) nexuss4g-postconfig

.PHONY: nexuss4g-postconfig
nexuss4g-postconfig:
	$(call GONK_CMD,$(MAKE) signapk && vendor/samsung/crespo4g/reassemble-apks.sh)

.PHONY: config-qemu
config-qemu: config-gecko
	@echo "KERNEL = qemu" > .config.mk && \
        echo "KERNEL_PATH = ./boot/kernel-android-qemu" >> .config.mk && \
	echo "GONK = generic" >> .config.mk && \
	echo "GONK_TARGET = generic-eng" >> .config.mk && \
	echo "GONK_MAKE_FLAGS = TARGET_ARCH_VARIANT=armv7-a" >> .config.mk && \
	$(MAKE) -C boot/kernel-android-qemu ARCH=arm goldfish_armv7_defconfig && \
	( [ -e $(GONK_PATH)/device/qemu ] || \
		mkdir $(GONK_PATH)/device/qemu ) && \
	echo OK

.PHONY: flash
# XXX Using target-specific targets for the time being.  fastboot is
# great, but the sgs2 doesn't support it.  Eventually we should find a
# lowest-common-denominator solution.
flash: flash-$(GONK)

# flash-only targets are the same as flash targets, except that they don't
# depend on building the image.

.PHONY: flash-only
flash-only: flash-only-$(GONK)

.PHONY: flash-crespo4g
flash-crespo4g: image $(ADB)
	@$(call GONK_CMD,$(ADB) reboot bootloader && fastboot flashall -w)

.PHONY: flash-only-crespo4g
flash-only-crespo4g: $(ADB)
	@$(call GONK_CMD,$(ADB) reboot bootloader && fastboot flashall -w)

define FLASH_GALAXYS2_CMD
$(ADB) reboot download 
sleep 20
$(HEIMDALL) flash --factoryfs $(GONK_PATH)/out/target/product/galaxys2/system.img
$(FLASH_GALAXYS2_CMD_CHMOD_HACK)
endef

.PHONY: flash-galaxys2
flash-galaxys2: image $(ADB)
	$(FLASH_GALAXYS2_CMD)

.PHONY: flash-only-galaxys2
flash-only-galaxys2: $(ADB)
	$(FLASH_GALAXYS2_CMD)

.PHONY: flash-maguro
flash-maguro: image flash-only-maguro

.PHONY: flash-only-maguro
flash-only-maguro:
	@$(call GONK_CMD, \
	adb reboot bootloader && \
	$(FASTBOOT) devices && \
	$(FASTBOOT) erase userdata && \
	$(FASTBOOT) flash userdata ./out/target/product/maguro/userdata.img && \
	$(FASTBOOT) flashall)

.PHONY: bootimg-hack
bootimg-hack: kernel-$(KERNEL)

.PHONY: kernel-samsung
kernel-samsung:
	cp -p boot/kernel-android-samsung/arch/arm/boot/zImage $(GONK_PATH)/device/samsung/crespo/kernel && \
	cp -p boot/kernel-android-samsung/drivers/net/wireless/bcm4329/bcm4329.ko $(GONK_PATH)/device/samsung/crespo/bcm4329.ko

.PHONY: kernel-qemu
kernel-qemu:
	cp -p boot/kernel-android-qemu/arch/arm/boot/zImage \
		$(GONK_PATH)/device/qemu/kernel

kernel-%:
	@

OUT_DIR := $(GONK_PATH)/out/target/product/$(GONK)/system
APP_OUT_DIR := $(OUT_DIR)/app

$(APP_OUT_DIR):
	mkdir -p $(APP_OUT_DIR)

.PHONY: gecko-install-hack
gecko-install-hack: gecko
	rm -rf $(OUT_DIR)/b2g
	mkdir -p $(OUT_DIR)/lib
	# Extract the newest tarball in the gecko objdir.
	( cd $(OUT_DIR) && \
	  tar xvfz `ls -t $(GECKO_OBJDIR)/dist/b2g-*.tar.gz | head -n1` )
	find glue/gonk/out -iname "*.img" | xargs rm -f

.PHONY: gaia-hack
gaia-hack: gaia
	rm -rf $(OUT_DIR)/home
	mkdir -p $(OUT_DIR)/home
	cp -r gaia/* $(OUT_DIR)/home
	rm -rf $(OUT_DIR)/b2g/defaults/profile
	mkdir -p $(OUT_DIR)/b2g/defaults
	cp -r gaia/profile $(OUT_DIR)/b2g/defaults

.PHONY: install-gecko
install-gecko: gecko-install-hack $(ADB)
	@$(ADB) shell mount -o remount,rw /system && \
	$(ADB) push $(OUT_DIR)/b2g /system/b2g

# The sad hacks keep piling up...  We can't set this up to be
# installed as part of the data partition because we can't flash that
# on the sgs2.
PROFILE := `$(ADB) shell ls -d /data/b2g/mozilla/*.default | tr -d '\r'`
PROFILE_DATA := gaia/profile
.PHONY: install-gaia
install-gaia: $(ADB)
	@for file in `ls $(PROFILE_DATA)`; \
	do \
		data=$${file##*/}; \
		echo Copying $$data; \
		$(ADB) shell rm -r $(PROFILE)/$$data; \
		$(ADB) push gaia/profile/$$data $(PROFILE)/$$data; \
	done
	@for i in `ls gaia`; do $(ADB) push gaia/$$i /data/local/$$i; done

.PHONY: image
image: build
	@echo XXX stop overwriting the prebuilt nexuss4g kernel

.PHONY: unlock-bootloader
unlock-bootloader: $(ADB)
	@$(call GONK_CMD,$(ADB) reboot bootloader && fastboot oem unlock)

# Kill the b2g process on the device.
.PHONY: kill-b2g
kill-b2g: $(ADB)
	$(ADB) shell killall b2g

.PHONY: sync
sync:
	git pull origin master
	git submodule sync
	git submodule update --init

PKG_DIR := package

.PHONY: package
package:
	rm -rf $(PKG_DIR)
	mkdir -p $(PKG_DIR)/qemu/bin
	cp glue/gonk/out/host/linux-x86/bin/emulator $(PKG_DIR)/qemu/bin
	cp glue/gonk/out/host/linux-x86/bin/emulator-arm $(PKG_DIR)/qemu/bin
	cp glue/gonk/out/host/linux-x86/bin/adb $(PKG_DIR)/qemu/bin
	cp boot/kernel-android-qemu/arch/arm/boot/zImage $(PKG_DIR)/qemu
	cp -R glue/gonk/out/target/product/generic $(PKG_DIR)/qemu
	cd $(PKG_DIR) && tar -czvf qemu_package.tar.gz qemu

$(ADB):
	@$(call GONK_CMD,make adb)

.PHONY: adb
adb: $(ADB)

.PHONY: build-jni-list
build-jni-list: gonk
	$(call GONK_CMD,$(MAKE) build-jni-list)

.PHONY: find-dependants
# Find all modules they depend on FIND_MODULE.
#
# FIND_MODULE is a variable given by user through command line or
# environment variable.  For example,
#
# 	make FIND_MODULE=libdvm find-dependants
#
find-dependants:
	$(call GONK_CMD,$(MAKE) FIND_MODULE="$(FIND_MODULE)" find-dependants)

.PHONY: find-depends
# Find all modules that FIND_MODULE depends on.
#
# FIND_MODULE is a variable given by user through command line or
# environment variable.  For example,
#
# 	make FIND_MODULE=libdvm find-depends
#
find-depends:
	$(call GONK_CMD,$(MAKE) FIND_MODULE="$(FIND_MODULE)" find-depends)


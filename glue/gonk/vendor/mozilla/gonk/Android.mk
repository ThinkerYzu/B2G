############################################################
# Integrate Gecko to the building process of gonk.
############################################################
LOCAL_PATH:= $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := gecko-gonk
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_PATH := $(TARGET_OUT)/b2g
LOCAL_MODULE_TAGS := optional

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

# XXX: Add all modules depended by gecko here.  This list is not
# complete.  Add all ncessary modules if you find some ones been
# missed.
$(LOCAL_BUILT_MODULE): libc libstdc++ libm libdl libthread_db
$(LOCAL_BUILT_MODULE): $(OUT_DIR)/.gecko-chg
	$(hide) $(MAKE) -C $(B2G_PATH) gecko-gonk-install && \
	mkdir -p $$(dirname $@) && \
	touch $@

############################################################
# Integrate Gaia to the building process of gonk.
############################################################
include $(CLEAR_VARS)

LOCAL_MODULE := gaia-gonk
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_PATH := $(TARGET_OUT)/home
LOCAL_MODULE_TAGS := optional

#######################################
include $(BUILD_SYSTEM)/base_rules.mk
#######################################

$(LOCAL_BUILT_MODULE): $(OUT_DIR)/.gaia-chg
	$(hide) $(MAKE) -C $(B2G_PATH) gaia-gonk-install && \
	mkdir -p $$(dirname $@) && \
	touch $@


# Use glue/gonk/system/core/rootdir/init.rc.gonk instead of
# glue/gonk/system/core/rootdir/init.rc.
#
# See the rules in glue/gonk/system/core/rootdir/Android.mk for copying
# init.rc to initrd. (search TARGET_PROVIDES_INIT_RC)
file := $(TARGET_ROOT_OUT)/init.rc
$(file) : $(TOPDIR)system/core/rootdir/init.rc.gonk | $(ACP)
	$(transform-prebuilt-to-target)
ALL_PREBUILT += $(file)
$(INSTALLED_RAMDISK_TARGET): $(file)

JNI_MODULE_LIST := $(TOPDIR)frameworks/policies/base/jni-module-list.mk

-include $(JNI_MODULE_LIST)

DALVIK_MODULES := \
	dalvikvm \
	dexdeps \
	dexdump \
	dexlist \
	dexopt \
	dmtracedump \
	dvz \
	dx \
	gdbjithelper \
	hprof-conv \
	jasmin \
	jasmin.jar \
	libdex \
	libdvm \
	libdvm_assert \
	libdvm_interp \
	libdvm_sv \
	libnativehelper

LIBDVM_DEPENDANTS := \
	libFFTEm \
	libandroid \
	libandroid_runtime \
	libaudioeffect_jni \
	libjnigraphics \
	libmedia_jni \
	libmediaplayerservice \
	librs_jni \
	libsoundpool \
	libsystem_server

# The list of modules that should not be built
REMOVE_MODULES ?=
REMOVE_MODULES := \
	$(REMOVE_MODULES) \
	$(DALVIK_MODULES) \
	$(ALL_JNI_MODULES) \
	$(LIBDVM_DEPENDANTS) \
	libclearsilver-jni \
	$(NULL)
# All modules with one of these classes are also not built.
REMOVE_CLASSES := APPS JAVA_LIBRARIES

# Make a list of all modules with one of given classes.
#
# $(1): a list of classes.
#
define make-list-of-all-modules-of-classes
$(foreach m, $(ALL_MODULES), $(if $(filter $(1), $(ALL_MODULES.$(m).CLASS)), $(m)))
endef

REMOVE_MODULES := $(REMOVE_MODULES) \
	$(call make-list-of-all-modules-of-classes, $(REMOVE_CLASSES))

REMOVE_TARGETS :=

# Remove a given module from tag lists.
#
# The given module would be removed from coressonding tag lists.
# The built targets of the module would be added to REMOVE_TARGETS.
#
# $(1): the name of the moulde being removed.
#
define remove-module
$(foreach t,$(ALL_MODULES.$(1).TAGS),
ALL_MODULE_TAGS.$(t) := $(filter-out $(ALL_MODULES.$(1).INSTALLED), \
	$(ALL_MODULE_TAGS.$(t))))
REMOVE_TARGETS := \
	$(REMOVE_TARGETS) \
	$(ALL_MODULES.$(1).BUILT)
ALL_MODULES.$(1).TAGS :=
ALL_MODULES.$(1).CHECKED :=
ALL_MODULES.$(1).BUILT :=
endef

# Remove all modules from tag lists.
$(foreach m, $(REMOVE_MODULES), \
	$(eval $(call remove-module,$(m))))

# Remove all modules from the CHECKED list of every module.
$(foreach mod, $(ALL_MODULES), \
	$(eval ALL_MODULES.$(mod).CHECKED := \
		$(filter-out $(REMOVE_TARGETS), \
			$(ALL_MODULES.$(mod).CHECKED))))

# Remove built targets of removed modules from the BUILT list of every module.
$(foreach mod, $(ALL_MODULES), \
	$(eval ALL_MODULES.$(mod).BUILT := \
		$(filter-out $(REMOVE_TARGETS), \
			$(ALL_MODULES.$(mod).BUILT))))

# Remove removed modulest from all products.
$(foreach p, $(ALL_PRODUCTS), \
	$(eval PRODUCTS.$(p).PRODUCT_PACKAGES := \
		$(filter-out $(REMOVE_MODULES), \
			$(PRODUCTS.$(p).PRODUCT_PACKAGES))))

define find-so-modules
$(foreach mod, $(sort $(ALL_MODULES)), \
	$(if $(strip $(filter %.so,$(ALL_MODULES.$(mod).INSTALLED))), $(mod)))
endef

define find-jni-modules
echo "# All modules that implements JNI" > $(JNI_MODULE_LIST); \
echo "ALL_JNI_MODULES := \\" >> $(JNI_MODULE_LIST); \
$(foreach mod, $(call find-so-modules), \
$(foreach so, $(filter %.so,$(ALL_MODULES.$(mod).INSTALLED)), \
	if [ -e "$(so)" ]; then \
		if readelf -a "$(so)" \
			| grep -e 'jniRegisterNativeMethods' -e 'JNI_OnLoad' \
			> /dev/null 2>&1; then \
			echo "	$(mod) \\" >> $(JNI_MODULE_LIST); \
		fi; \
	fi; \
)) \
echo "	\$$(NULL)" >> $(JNI_MODULE_LIST)
endef

.PHONY: build-jni-list
build-jni-list:
	$(hide) echo "Building JNI list .........."
	$(hide) $(call find-jni-modules)


############################################################
# Implements finding all modules that depend on a module.
#
# The modules, here, are to build shared objects.
############################################################

# Get all required SO of given SO.
#
# $(1): the name of an SO file.
define _so-deps
$(shell if [ -e "$(strip $(1))" ]; then readelf -a "$(strip $(1))" | \
	grep '(NEEDED)'| \
	awk -v FS="Shared library: \[" -- '{gsub("]", "", $$2); print $$2;}'; \
	fi)
endef

# Get all required SO of given SO.
#
# $(1): the name of an SO file.
# Return all shared objects they are linked by give shared object.
define so-deps
$(foreach so,$(call _so-deps,$(1)), $(dir $(1))$(so))
endef

# Remember linking between two modules.
#
# $(1): the module name of supporter.
# $(2): the module name of dependant.
define remember-linking
$(eval ALL_MODULES.$(1).DEPENDANTS := $(ALL_MODULES.$(1).DEPENDANTS) $(2))
$(eval ALL_MODULES.$(2).DEPENDS := $(ALL_MODULES.$(2).DEPENDS) $(1))
endef

# Find corresponding module for a so file.
#
# $(1): so file name
define find-so-owner-module
$(strip $(INSTALLABLE_FILES.$(strip $(1)).MODULE))
endef

# Collects linking relationship between modules.
# Let all other modules that given module depend on remember that.
#
# $(1): the name of the module waiting for creating dep.
# $(2): the name of a so file.
define collect-so-link-dep
$(foreach dep, $(call so-deps,$(2)), \
	$(call remember-linking,$(call find-so-owner-module,$(dep)),$(1)))
endef

# Collects linking relationships for given module.
#
# $(1): the name of the module waiting for creating dependencies.
define collect-module-link-dep
$(foreach so, $(filter %.so,$(ALL_MODULES.$(1).INSTALLED)), \
	$(call collect-so-link-dep,$(1),$(so)))
endef

# Collects linking relationship for modules
#
# $(1): a list of module names.
define collect-dep-for-modules
$(foreach mod, $(1), \
	$(call collect-module-link-dep,$(mod)))
endef

# Collects linking relationship for all learnt modules.
define collect-dep-for-all-modules
$(if $(GEN_DEP_FOR_ALL_MODULES_FLAGS),, \
$(call collect-dep-for-modules,$(call find-so-modules)) \
$(eval GEN_DEP_FOR_ALL_MODULES_FLAGS := true))
endef

define _find-module-dependants
$(call collect-dep-for-all-modules) \
$(ALL_MODULES.$(1).DEPENDANTS) \
$(foreach dep, $(ALL_MODULES.$(1).DEPENDANTS), \
	$(call _find-module-dependants,$(dep)))
endef

# Find all modules that depend on given module.
#
# You can use this function to search all modules they are linked with
# the shared objects generated by the given module.  For example,
# finds all modules they depend on libdvm.
#
# $(1): module name.
# return a list of modules that depend on the given module.
define find-module-dependants
$(strip $(call _find-module-dependants,$(1)))
endef

define _find-module-depends
$(call collect-dep-for-all-modules) \
$(ALL_MODULES.$(1).DEPENDS) \
$(foreach dep, $(ALL_MODULES.$(1).DEPENDS), \
	$(call _find-module-depends,$(dep)))
endef

# Find all modules they are depended by given module.
#
# You can use this function to search all modules they are linked by
# the shared objects generated by the given module.
#
# $(1): module name.
# return a list of modules they are depended by the given module.
define find-module-depends
$(strip $(call _find-module-depends,$(1)))
endef

find-dependants:
	$(hide) echo -n "Dependants: "; \
	echo $(sort $(call find-module-dependants,$(FIND_MODULE)))

find-depends:
	$(hide) echo -n "Depends: "; \
	echo $(sort $(call find-module-depends,$(FIND_MODULE)))

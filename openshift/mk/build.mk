BUILDDIR_NAME := os-build
BUILDDIR_PATH = $(THISDIR_PATH)/$(BUILDDIR_NAME)

.PHONY: rm-build-dir new-build-dir build-dir

rm-build-dir:
	rm -rf $(shell readlink -e $(BUILDDIR_PATH)) $(BUILDDIR_PATH)

new-build-dir: rm-build-dir
	ln -s $(shell mktemp -d) $(BUILDDIR_PATH)

build-dir: # Generate a clean export of the source code for building
	if test ! -d $(BUILDDIR_PATH); then $(MAKE) -f $(MKFILE_PATH) new-build-dir; fi
	$(call git-export-sources,$(PROJECT_PATH),$(BUILDDIR_PATH),$(GIT_DIRTY_CHECK))
	touch $(BUILDDIR_PATH)/ready

# flag file to *assume* whatever is in a build dir is trusted to generate the image
$(BUILDDIR_NAME)/ready:
	$(MAKE) -f $(MKFILE_PATH) build-dir

define _build_target
.PHONY: $(1)
$(1): $(BUILDDIR_NAME)/ready
	$(MAKE) -f $(MKFILE_PATH) $(2) ; \
	  EXITVAL=$$? ; \
	  test "$(BUILD_CLEANUP)x" = "0x" || $(MAKE) -f $(MKFILE_PATH) rm-build-dir ; \
	  exit $${EXITVAL}
endef

# Arguments:
# 1. New target to create handling the build.
# 2. Existing target to be wrapped by the new target.
define build_target
$(eval $(call _build_target,$(1),$(2)))
endef

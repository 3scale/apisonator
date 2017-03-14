# docker_build definition
#
# Please set BUILDDIR_PATH and PROJECT_PATH.
#
# Arguments:
#
# 1. Dockerfile (must be within PROJECT_PATH).
# 2. Image tag.
# 3. Optional build arguments.
#

define docker_build
	docker build -f $(BUILDDIR_PATH)/dist/$(shell realpath --relative-to \
	  $(PROJECT_PATH) $(1)) --pull -t $(2) \
	  $(BUILDDIR_PATH)/dist $(3)
endef

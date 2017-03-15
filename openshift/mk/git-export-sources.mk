# The variables below can be redefined:
#
# GIT - git binary
# PATCH - patch binary
#
# The only definition to be used is export-sources, which receives a parameter:
#   $1 - Project root path (containing .git folder)
#   $2 - Build directory path (will export under "dist")
#   $3 - value 0 to disable dirty index/worktree check
#      - anything else to enable the check
#

GIT := git
PATCH := patch

# Private definitions

# 1: project path
define _git-export-sources-git-dirty-check
	(cd $(1) && $(GIT) diff-index --quiet --cached HEAD && \
          $(GIT) diff-files --quiet && \
          $(GIT) diff-index --quiet HEAD)
endef

# 1: project path
# 2: build path
define _git-export-sources-patch-sources
        cd $(1) && $(GIT) diff --cached | $(PATCH) -p1 -d $(2)/dist
        cd $(1) && $(GIT) diff | $(PATCH) -p1 -d $(2)/dist
endef

# 1: project path
# 2: build path
define _git-export-sources
        (cd $(1) && \
          git archive --worktree-attributes --format=tar --prefix=dist/ HEAD) | \
          (rm -rf $(2)/* && tar xf - -C $(2))
endef

# Public definitions
define git-export-sources
	test "$(3)x" = "0x" || \
	  ($(call _git-export-sources-git-dirty-check,$(1)) || \
	  (echo -e "\n*** ERROR: dirty git state - ensure all diffs are committed or set GIT_DIRTY_CHECK=0\n" >&2; false))
	$(call _git-export-sources,$(1),$(2))
	test "$(3)x" != "0x" || \
	  $(call _git-export-sources-patch-sources,$(1),$(2))
endef

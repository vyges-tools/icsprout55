# =============================================================================
# Compress blocks
# =============================================================================
COMP_DIR_LIB   := $(shell find IP/STD_cell -type d -name liberty)
COMP_DIR_LIB_P := $(patsubst %/liberty, %, $(COMP_DIR_LIB))
COMP_BZ2_LIB   := $(addsuffix _liberty.tar.bz2, $(COMP_DIR_LIB_P))

COMP_DIR_GDS   := $(shell find IP -type d -name gds)
COMP_DIR_GDS_P := $(patsubst %/gds, %, $(COMP_DIR_GDS))
COMP_BZ2_GDS   := $(addsuffix _gds.tar.bz2, $(COMP_DIR_GDS_P))

COMP_BZ2 := $(COMP_BZ2_LIB) $(COMP_BZ2_GDS)

RELEASE_VERSION ?=
RELEASE_TITLE   ?= $(RELEASE_VERSION)
RELEASE_NOTES   ?= "ICsprout55 Open Source PDK Large Files"

.PHONY: start zip zip-bz2 check upload clean

$(COMP_BZ2_LIB): %_liberty.tar.bz2: %/liberty
	@echo "\n[zip] compressing $< -> $@..."
	@tar -cjvf $@ -C $(dir $<) $(notdir $<)

$(COMP_BZ2_GDS): %_gds.tar.bz2: %/gds
	@echo "\n[zip] compressing $< -> $@..."
	@tar -cjvf $@ -C $(dir $<) $(notdir $<)

zip: start zip-bz2 upload clean
	@echo "\n[zip] done!"

start:
	@echo "[zip] start..."

zip-bz2: $(COMP_BZ2)
	@echo "\n[zip] compress done!"

check:
	@if ! gh auth status >/dev/null 2>&1; then \
		echo "\n[check] gitHub release status check failed!"; \
		exit 1; \
	fi

upload: check
	@echo "\n[upload] creating gitHub release $(RELEASE_VERSION)..."
	gh release create $(RELEASE_VERSION) $(COMP_BZ2) --title $(RELEASE_TITLE) --notes $(RELEASE_NOTES)
	@echo "\n[upload] done!"

clean:
	@echo "\n[clean] delete compressed files"
	@find ./ -name "*.tar.bz2" -exec rm -fv {} \; || true

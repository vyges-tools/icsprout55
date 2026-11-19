# Large IP views are distributed as Release archives.
ORGS_NAME := openecos-projects
REPO_NAME := icsprout55-pdk

PROXY_URL ?= https://gh-proxy.org/
PROXY_USE ?= false
TOOL ?= curl
BZIP2_TOOL ?= bzip2

RELEASE_FILE_LIB := ics55_LLSC_H7CH_liberty.tar.bz2 \
                    ics55_LLSC_H7CL_liberty.tar.bz2 \
                    ics55_LLSC_H7CR_liberty.tar.bz2

STD_VARIANTS := HVT LVT SVT
LIB_PARTS := nldm ccs_ff ccs_ss ccs_tt
STD_LIBRARIES := $(addprefix ICsprout55_SC9T_BASIC_,$(STD_VARIANTS))
RELEASE_FILE_LIB := $(foreach lib,$(STD_LIBRARIES),$(foreach part,$(LIB_PARTS),$(lib)_liberty_$(part).tar.bz2))
RELEASE_FILE_GDS_STD := $(addsuffix _gds.tar.bz2,$(STD_LIBRARIES))
RELEASE_FILE_GDS_IO := ICsprout_55LLULP1225_IO_0901_gds.tar.bz2
RELEASE_FILE := $(RELEASE_FILE_LIB) $(RELEASE_FILE_GDS_STD) $(RELEASE_FILE_GDS_IO)
DOC_ARCHIVE := v2-docs.tar.bz2
MANAGED_DIRS := $(foreach lib,$(STD_LIBRARIES),IP/STD_cell/$(lib)/liberty IP/STD_cell/$(lib)/gds) IP/IO/gds

.DEFAULT_GOAL := unzip
.PHONY: download verify unzip download-docs verify-docs docs clean-bz2 clean-dir

DECOMP_DIR_GDS_STD_P := IP/STD_cell/ics55_LLSC_H7C_V1p10C100
DECOMP_DIR_GDS_IO_P  := IP/IO
DECOMP_DIR_GDS       := $(patsubst %_gds.tar.bz2, $(DECOMP_DIR_GDS_STD_P)/%/gds, $(RELEASE_FILE_GDS_STD)) \
                        $(patsubst %_gds.tar.bz2, $(DECOMP_DIR_GDS_IO_P)/%/gds, $(RELEASE_FILE_GDS_IO))

DECOMP_DIR := $(DECOMP_DIR_LIB) $(DECOMP_DIR_GDS)

.PHONY: start download unzip clean-bz2 clean-dir

$(RELEASE_FILE):
	@echo "\n[download] getting the latest release info"
	@RELEASE_URL=$$(curl -s "https://api.github.com/repos/$(ORGS_NAME)/$(REPO_NAME)/releases/latest" | \
		grep -E "browser_download_url.*$(@)" | \
		cut -d '"' -f 4); \
	if [ -z "$$RELEASE_URL" ]; then \
		echo "[download] file not found $(@)"; \
		echo "[download] please check whether the Release contains the following files: "; \
		echo "$(RELEASE_FILE)"; \
		exit 1; \
	fi; \
	echo "[download] getting $(@)..."; \
	if [ "$(PROXY_USE)" = "true" ]; then \
		RELEASE_URL="$(PROXY_URL)$$RELEASE_URL"; \
	fi; \
	if [ "$(TOOL)" = "wget" ]; then \
		wget --no-verbose --tries=3 --timeout=30 -O "$@.part" "$$url"; \
	else \
		curl --fail --location --silent --show-error --retry 3 --connect-timeout 30 -o "$@.part" "$$url"; \
	fi || { rm -f "$@.part"; exit 1; }; \
	mv "$@.part" "$@"

download: $(RELEASE_FILE)

verify: download
	@sha256sum --check release-assets.sha256

# Extract and verify every archive before replacing the installed views.
unzip: verify
	@set -eu; \
	stage=$$(mktemp -d .release-unzip.XXXXXX); \
	trap 'rm -rf "$$stage"' 0; \
	trap 'exit 1' 1 2 15; \
	for vt in $(STD_VARIANTS); do \
		base="ICsprout55_SC9T_BASIC_$$vt"; \
		target="$$stage/IP/STD_cell/$$base"; \
		mkdir -p "$$target"; \
		for part in $(LIB_PARTS); do \
			archive=$$(printf '%s_liberty_%s.tar.bz2' "$$base" "$$part"); \
			echo "[unzip] $$archive"; \
			tar --use-compress-program="$(BZIP2_TOOL)" -xf "$$archive" -C "$$target"; \
		done; \
		tar --use-compress-program="$(BZIP2_TOOL)" -xf "$$base"_gds.tar.bz2 -C "$$target"; \
	done; \
	mkdir -p "$$stage/IP/IO"; \
	tar --use-compress-program="$(BZIP2_TOOL)" -xf "$(RELEASE_FILE_GDS_IO)" -C "$$stage/IP/IO"; \
	(cd "$$stage" && sha256sum --check "$(CURDIR)/release-files.sha256"); \
	for target in $(MANAGED_DIRS); do \
		mkdir -p "$$(dirname "$$target")"; \
		rm -rf "$$target"; \
		mv "$$stage/$$target" "$$target"; \
	done
	@$(MAKE) --no-print-directory clean-bz2
	@echo "[unzip] complete: $(RELEASE_TAG)"

# PDF manuals are optional and are not dependencies of download or unzip.
download-docs: $(DOC_ARCHIVE)

verify-docs: download-docs
	@sha256sum --check release-docs.sha256

docs: verify-docs
	@set -eu; \
	stage=$$(mktemp -d .release-docs.XXXXXX); \
	trap 'rm -rf "$$stage"' 0; \
	trap 'exit 1' 1 2 15; \
	tar --use-compress-program="$(BZIP2_TOOL)" -xf "$(DOC_ARCHIVE)" -C "$$stage"; \
	(cd "$$stage" && sha256sum --check "$(CURDIR)/release-doc-files.sha256"); \
	while read -r checksum path; do \
		mkdir -p "$$(dirname "$$path")"; \
		mv -- "$$stage/$$path" "$$path"; \
	done < release-doc-files.sha256
	@rm -f -- "$(DOC_ARCHIVE)" "$(DOC_ARCHIVE).part"
	@echo "[docs] complete: $(RELEASE_TAG)"

clean-bz2:
	@rm -f -- $(RELEASE_FILE) $(addsuffix .part,$(RELEASE_FILE))

clean-dir:
	@rm -rf -- $(MANAGED_DIRS)

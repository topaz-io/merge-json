SHELL              := $(shell which bash)

NO_COLOR           := \033[0m
OK_COLOR           := \033[32;01m
ERR_COLOR          := \033[31;01m
WARN_COLOR         := \033[36;01m
ATTN_COLOR         := \033[33;01m

GOOS               := $(shell go env GOOS)
GOARCH             := $(shell go env GOARCH)

EXT_DIR            := ${PWD}/.ext
EXT_BIN_DIR        := ${EXT_DIR}/bin
EXT_TMP_DIR        := ${EXT_DIR}/tmp

GO_VER             := 1.27
SVU_VER 	         := 3.4.4
GOTESTSUM_VER      := 1.13.0
GOLANGCI-LINT_VER  := 2.15.0
GORELEASER_VER     := 2.20.0
GOFUMPT_VER        := latest

RELEASE_TAG        := $$(${EXT_BIN_DIR}/svu current)

.DEFAULT_GOAL      := build

.PHONY: deps
deps: info install-svu install-goreleaser install-golangci-lint install-gotestsum
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"

.PHONY: gover
gover:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@(go env GOVERSION | grep "go${GO_VER}") || (echo "go version check failed expected go${GO_VER} got $$(go env GOVERSION)"; exit 1)

PHONY: go-fmt
go-fmt: 
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@${EXT_BIN_DIR}/gofumpt -l -w .

PHONY: go-work-sync
go-work-sync:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@go work sync

PHONY: go-mod-tidy
go-mod-tidy: go-fmt go-work-sync
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@exit_code=0; \
	modules=$$(go work edit -json | jq -r '.Use[].DiskPath // empty'); \
	for mod in $$modules; do \
		if [ "$$mod" = "." ]; then \
			mod_dir=$$(pwd); \
		else \
			mod_dir=$$(realpath "$$mod" 2>/dev/null || echo "$$mod"); \
		fi; \
		echo -e "$(ATTN_COLOR)==> $@ $$mod_dir$(NO_COLOR)"; \
		(cd "$$mod_dir" && go mod tidy) || exit_code=$$?; \
	done; \
	exit $$exit_code

.PHONY: lint
lint: gover
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@${EXT_BIN_DIR}/golangci-lint config path
	@${EXT_BIN_DIR}/golangci-lint config verify
	@exit_code=0; \
	config=${PWD}/.golangci.yaml; \
	modules=$$(go work edit -json | jq -r '.Use[].DiskPath // empty'); \
	for mod in $$modules; do \
		if [ "$$mod" = "." ]; then \
			mod_dir=$$(pwd); \
		else \
			mod_dir=$$(realpath "$$mod" 2>/dev/null || echo "$$mod"); \
		fi; \
		echo -e "$(ATTN_COLOR)==> $@ $$mod_dir$(NO_COLOR)"; \
		(cd "$$mod_dir" && ${EXT_BIN_DIR}/golangci-lint run --config $$config ./...) || exit_code=$$?; \
	done; \
	exit $$exit_code

.PHONY: lint-clean
lint-clean: gover
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@${EXT_BIN_DIR}/golangci-lint cache clean

.PHONY: test
test: gover test-snapshot
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@exit_code=0; \
	modules=$$(go work edit -json | jq -r '.Use[].DiskPath // empty'); \
	for mod in $$modules; do \
		if [ "$$mod" = "." ]; then \
			mod_dir=$$(pwd); \
		else \
			mod_dir=$$(realpath "$$mod" 2>/dev/null || echo "$$mod"); \
		fi; \
		echo -e "$(ATTN_COLOR)==> $@ $$mod_dir$(NO_COLOR)"; \
		(cd "$$mod_dir" && ${EXT_BIN_DIR}/gotestsum --format short-verbose -- -count=1 -v ./... -coverprofile=cover.out -coverpkg=./... ./...) || exit_code=$$?; \
	done; \
	exit $$exit_code

.PHONY: build
build: gover
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@${EXT_BIN_DIR}/goreleaser build --clean --snapshot --single-target

.PHONY: release
release:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@${EXT_BIN_DIR}/goreleaser release --clean

.PHONY: snapshot
snapshot:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@${EXT_BIN_DIR}/goreleaser release --clean --snapshot

.PHONY: generate
generate:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@GOBIN=${EXT_BIN_DIR} go generate ./...

.PHONY: tag
tag:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@-git push --delete origin latest
	@-git tag -d latest
	@git tag $$(svu patch)
	@git tag latest
	@git push --tags

.PHONY: info
info:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@echo "GOOS:        ${GOOS}"
	@echo "GOARCH:      ${GOARCH}"
	@echo "EXT_DIR:     ${EXT_DIR}"
	@echo "EXT_BIN_DIR: ${EXT_BIN_DIR}"
	@echo "EXT_TMP_DIR: ${EXT_TMP_DIR}"
	@echo "RELEASE_TAG: ${RELEASE_TAG}"
	
.PHONY: install-svu
install-svu: ${EXT_BIN_DIR} ${EXT_TMP_DIR}
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@GOBIN=${EXT_BIN_DIR} go install github.com/caarlos0/svu/v3@v${SVU_VER}
	@${EXT_BIN_DIR}/svu --version

.PHONY: install-gotestsum
install-gotestsum: ${EXT_TMP_DIR} ${EXT_BIN_DIR}
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@gh release download v${GOTESTSUM_VER} --repo https://github.com/gotestyourself/gotestsum --pattern "gotestsum_${GOTESTSUM_VER}_${GOOS}_${GOARCH}.tar.gz" --output "${EXT_TMP_DIR}/gotestsum.tar.gz" --clobber
	@tar -xvf ${EXT_TMP_DIR}/gotestsum.tar.gz --directory ${EXT_BIN_DIR} gotestsum &> /dev/null
	@chmod +x ${EXT_BIN_DIR}/gotestsum
	@${EXT_BIN_DIR}/gotestsum --version

.PHONY: install-golangci-lint
install-golangci-lint: ${EXT_TMP_DIR} ${EXT_BIN_DIR}
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@gh release download v${GOLANGCI-LINT_VER} --repo https://github.com/golangci/golangci-lint --pattern "golangci-lint-${GOLANGCI-LINT_VER}-${GOOS}-${GOARCH}.tar.gz" --output "${EXT_TMP_DIR}/golangci-lint.tar.gz" --clobber
	@tar --strip=1 -xvf ${EXT_TMP_DIR}/golangci-lint.tar.gz --strip-components=1 --directory ${EXT_TMP_DIR} &> /dev/null
	@mv ${EXT_TMP_DIR}/golangci-lint ${EXT_BIN_DIR}/golangci-lint
	@chmod +x ${EXT_BIN_DIR}/golangci-lint
	@${EXT_BIN_DIR}/golangci-lint --version

.PHONY: install-goreleaser
install-goreleaser: ${EXT_TMP_DIR} ${EXT_BIN_DIR}
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@gh release download v${GORELEASER_VER} --repo https://github.com/goreleaser/goreleaser --pattern "goreleaser_$$(uname -s)_$$(uname -m).tar.gz" --output "${EXT_TMP_DIR}/goreleaser.tar.gz" --clobber
	@tar -xvf ${EXT_TMP_DIR}/goreleaser.tar.gz --directory ${EXT_BIN_DIR} goreleaser &> /dev/null
	@chmod +x ${EXT_BIN_DIR}/goreleaser
	@${EXT_BIN_DIR}/goreleaser --version

.PHONY: install-gofumpt
install-gofumpt: ${EXT_BIN_DIR}
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@GOBIN=${EXT_BIN_DIR} go install mvdan.cc/gofumpt@${GOFUMPT_VER}

.PHONY: clean
clean:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@rm -rf ${EXT_DIR}
	@rm -rf ${BIN_DIR}
	@rm -rf ./dist
	@rm -rf ./test

${BIN_DIR}:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@mkdir -p ${BIN_DIR}

${EXT_BIN_DIR}:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@mkdir -p ${EXT_BIN_DIR}

${EXT_TMP_DIR}:
	@echo -e "$(ATTN_COLOR)==> $@ $(NO_COLOR)"
	@mkdir -p ${EXT_TMP_DIR}

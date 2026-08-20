# Builds openvox-gui OS packages with nfpm. Run from the repo root:
#   make -f packaging/Makefile package PKG_ARCH=arm64
# Designed to run inside a build container (see packaging/build-in-docker.sh)
# or a CI runner with python3.12, node 20+, and nfpm available.

PKG_VERSION := $(shell cat VERSION)
PKG_ARCH    ?= amd64
PKG_FORMAT  ?= rpm
STAGE       := build/stage
OUT         := build/out

# pip wheel-platform tags for the target arch. The ladder accepts both
# older manylinux2014 (glibc 2.17) wheels and manylinux_2_28 wheels
# (e.g. Pillow >= 12.3 ships only the latter) — safe because the oldest
# supported target, EL8, is glibc 2.28.
ifeq ($(PKG_ARCH),arm64)
WHEEL_ARCH := aarch64
else
WHEEL_ARCH := x86_64
endif
WHEEL_PLATS := --platform manylinux_2_28_$(WHEEL_ARCH) \
  --platform manylinux2014_$(WHEEL_ARCH) \
  --platform manylinux_2_17_$(WHEEL_ARCH)

PYTHON ?= python3.12

.PHONY: package stage frontend wheels clean

package: stage
	mkdir -p $(OUT)
	PKG_VERSION=$(PKG_VERSION) PKG_ARCH=$(PKG_ARCH) \
	  nfpm package -f packaging/nfpm.yaml -p $(PKG_FORMAT) -t $(OUT)/
	@ls -lh $(OUT)/

stage: frontend wheels
	rm -rf $(STAGE)/opt
	mkdir -p $(STAGE)/opt/openvox-gui
	cp -R backend scripts maintenance share VERSION $(STAGE)/opt/openvox-gui/
	find $(STAGE)/opt/openvox-gui -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
	mkdir -p $(STAGE)/opt/openvox-gui/frontend
	cp -R frontend/dist $(STAGE)/opt/openvox-gui/frontend/dist

frontend: frontend/dist/index.html

frontend/dist/index.html:
	cd frontend && npm install --no-audit --no-fund && \
	  { [ "$$(uname -m)" != "aarch64" ] || npm install --no-audit --no-fund @rollup/rollup-linux-arm64-gnu; } && \
	  npm run build

# Wheels for the target platform plus pip/setuptools/wheel for the
# offline bootstrap, plus the ovox CLI built from source.
wheels:
	mkdir -p $(STAGE)/wheels
	$(PYTHON) -m pip download --quiet --only-binary=:all: \
	  $(WHEEL_PLATS) \
	  --python-version 312 --implementation cp \
	  -d $(STAGE)/wheels -r backend/requirements.txt
	$(PYTHON) -m pip download --quiet --only-binary=:all: \
	  $(WHEEL_PLATS) --python-version 312 \
	  -d $(STAGE)/wheels pip setuptools wheel
	$(PYTHON) -m pip wheel --quiet --no-deps -w $(STAGE)/wheels ./ovox

clean:
	rm -rf build frontend/dist

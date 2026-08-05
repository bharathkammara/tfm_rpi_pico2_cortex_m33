# --- Directories ---
ROOT_DIR         := $(CURDIR)

VENV             ?= venv
VENV_ACT         := $(VENV)/bin/activate
PYTHON           := $(ROOT_DIR)/$(VENV)/bin/python3
PIP              := $(ROOT_DIR)/$(VENV)/bin/pip
TFM_REQ          := trusted-firmware-m/tools/requirements.txt

# --- Flash Map (Must match MCUboot config) ---
BOOT_OFFSET      := 0x10000000
APP_SLOT0_OFFSET := 0x10011000

# --- Binaries ---
BOOT_BIN         := $(ROOT_DIR)/build/spe/bin/bl2.bin
APP_SIGNED_BIN   := $(ROOT_DIR)/build/nspe/tfm_s_ns_signed.bin

# --- OpenOCD Configuration ---
OPENOCD_DIR      := $(ROOT_DIR)/openocd
OPENOCD          := $(OPENOCD_DIR)/src/openocd
OCD_INTERFACE    := $(OPENOCD_DIR)/tcl/interface/cmsis-dap.cfg
OCD_TARGET       := $(OPENOCD_DIR)/tcl/target/rp2350.cfg
OCD_FLAGS        := -f $(OCD_INTERFACE) -f $(OCD_TARGET) -c "adapter speed 1000; after 1000"

.PHONY: all setup spe nspe flash clean reset openocd debug-all

all: setup spe nspe

# --- Core Build Targets ---

spe: setup
	@echo "--- Building SPE (Secure Processing Environment) ---"
	cmake -S $(ROOT_DIR)/trusted-firmware-m \
		-B $(ROOT_DIR)/build/spe \
		-DTFM_PLATFORM=rpi/rp2350 \
		-DTFM_PROFILE=profile_medium \
		-DMCUBOOT_IMAGE_NUMBER=1 \
		-DTFM_BL2_LOG_LEVEL=LOG_LEVEL_VERBOSE \
		-DLOG_LEVEL=LOG_LEVEL_DEBUG \
		-DPython3_EXECUTABLE=$(PYTHON)
	cmake --build $(ROOT_DIR)/build/spe -- install

nspe: setup spe
	@echo "--- Building NSPE (Non-Secure Processing Environment) ---"
	cmake -S $(ROOT_DIR)/tf-m-ns-app \
		-B $(ROOT_DIR)/build/nspe \
		-DCONFIG_SPE_PATH=$(ROOT_DIR)/build/spe/api_ns \
		-DPython3_EXECUTABLE=$(PYTHON) \
		-DFETCHCONTENT_SOURCE_DIR_PICO_SDK=$(ROOT_DIR)/pico-sdk
	cmake --build $(ROOT_DIR)/build/nspe

# --- Flashing and Debugging ---

flash:
	@echo "--- Flashing Bootloader and Signed App ---"
	$(OPENOCD) $(OCD_FLAGS) \
		-c "program $(BOOT_BIN) $(BOOT_OFFSET) verify;" \
		-c "program $(APP_SIGNED_BIN) $(APP_SLOT0_OFFSET) verify;" \
		-c "reset run; shutdown;"

clean:
	@echo "--- Cleaning All Projects ---"
	@rm -rf $(ROOT_DIR)/build

reset:
	@echo "--- Resetting Target ---"
	$(OPENOCD) $(OCD_FLAGS) -c "init; reset run; shutdown;"

openocd:
	$(OPENOCD) \
		-f $(OCD_INTERFACE) \
		-f $(OCD_TARGET) \
		-c "adapter speed 5000"

debug-all:
	@echo "Starting Dual-Target Debug Session..."
	arm-none-eabi-gdb \
		-ex "set logging file gdb_session.log" \
		-ex "set logging on" \
		-ex "target extended-remote :3333" \
		-ex "monitor reset init" \
		-ex "file $(ROOT_DIR)/build/spe/bin/bl2.elf" \
		-ex "break main" \
		-ex "continue" \
		-tui

# --- System Setup ---

setup:
	@echo "Checking trusted-firmware-m..."
	@if [ ! -d "trusted-firmware-m" ]; then \
		git clone https://github.com/TrustedFirmware-M/trusted-firmware-m.git; \
	else \
		echo "trusted-firmware-m already exists, skipping clone."; \
	fi

	@echo "Checking openocd..."
	@if [ ! -d "openocd" ]; then \
		git clone https://github.com/openocd-org/openocd.git && \
		cd openocd && \
		git submodule update --init && \
		./bootstrap && \
		./configure && \
		make -j4; \
	else \
		echo "openocd already exists, skipping clone."; \
	fi

	@echo "Checking pico-sdk..."
	@if [ ! -d "pico-sdk" ]; then \
		git clone -b 2.0.0 https://github.com/raspberrypi/pico-sdk.git && \
		cd pico-sdk && \
		git submodule update --init; \
	else \
		echo "pico-sdk already exists, skipping clone."; \
	fi

	@echo "Checking Python virtual environment in '$(VENV)'..."
	@if [ ! -d "$(VENV)" ]; then \
		python3.10 -m venv $(VENV) && \
		echo "Upgrading pip and installing core TF-M dependencies..." && \
		$(PIP) install --upgrade pip && \
		$(PIP) install cryptography cbor2 imgtool jinja2 pyyaml intelhex click && \
		touch $(VENV)/.venv_installed && \
		echo "Virtual environment successfully configured."; \
	else \
		echo "'$(VENV)' already exists, skipping venv setup."; \
	fi
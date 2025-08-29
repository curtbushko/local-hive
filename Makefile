OS ?= $(shell uname | tr '[:upper:]' '[:lower:]')
ARCH ?= $(shell uname -m)
KERNEL_VERSION ?= $(shell uname -r)
NOMAD_DATA = $(CURDIR)/.nomad-data
SRC_NOMAD_SERVER_CONF = $(CURDIR)/nomad/server.conf
DEST_NOMAD_SERVER_CONF = $(NOMAD_DATA)/server.conf
DEST_NOMAD_PLUGINS = $(NOMAD_DATA)/plugins
SRC_NOMAD_JOBS = $(CURDIR)/nomad/jobs
DEST_NOMAD_JOBS = $(NOMAD_DATA)/jobs
TMP_DIR = $(CURDIR)/.tmp
IMAGE_BUCKET_URL=https://s3.amazonaws.com/spec.ccfc.min/img/quickstart_guide/$(ARCH)
FIRECRACKER_DATA = $(CURDIR)/.firecracker
SRC_FIRECRACKER_CONF = $(CURDIR)/firecracker/vm_config.json
DEST_FIRECRACKER_CONF = $(FIRECRACKER_DATA)/vm_config.json
FIRECRACKER_SOCKET = $(FIRECRACKER_DATA)/firecracker.socket
SRC_KERNEL = $(IMAGE_BUCKET_URL)/kernels/vmlinux.bin
DEST_KERNEL = $(FIRECRACKER_DATA)/vmlinux.bin
SRC_ROOTFS = $(IMAGE_BUCKET_URL)/rootfs/bionic.rootfs.ext4
DEST_ROOTFS = $(FIRECRACKER_DATA)/bionic.rootfs.ext4

SRC_CNI_DIR = $(CURDIR)/cni
CNI_BIN_DIR = /opt/cni/bin
CNI_NET_DIR = /etc/cni/conf.d

.PHONY: default
default: help

.PHONY: run-nomad
run-nomad: # Start nomad in dev mode
	@gum log --prefix local-hive --time RFC3339 --structured --level info "Starting nomad server" mode dev config $(DEST_NOMAD_SERVER_CONF)
	sudo nomad agent -dev --config=$(DEST_NOMAD_SERVER_CONF)

.PHONY: setup-nomad
setup-nomad: # Setup temporary directory and plugins
	@gum log --prefix local-hive --time RFC3339 --structured --level info "Setting up nomad config" dest $(DEST_NOMAD_SERVER_CONF)
	mkdir -p $(NOMAD_DATA)
	cat $(SRC_NOMAD_SERVER_CONF) | sed -e 's|NOMAD_DATA|$(NOMAD_DATA)|g' > $(DEST_NOMAD_SERVER_CONF)
	mkdir -p $(TMP_DIR)
	@gum log --prefix local-hive --time RFC3339 --structured --level info "Setting up nomad plugins" dir $(DEST_NOMAD_PLUGINS)
	mkdir -p $(DEST_NOMAD_PLUGINS)
	# hack - do not error if clone already exists
	git clone https://github.com/cneira/firecracker-task-driver.git $(TMP_DIR)/firecracker-task-driver ||true
	cd $(TMP_DIR)/firecracker-task-driver && go build -mod=mod -o ./firecracker-task-driver ./main.go
	cp $(TMP_DIR)/firecracker-task-driver/firecracker-task-driver $(DEST_NOMAD_PLUGINS)
	@gum log --prefix local-hive --time RFC3339 --structured --level info "Setting up nomad jobs" dir $(DEST_NOMAD_JOBS)
	mkdir -p $(DEST_NOMAD_JOBS)
	cat $(SRC_NOMAD_JOBS)/cell.nomad | sed -e 's|CELL_KERNEL|$(DEST_KERNEL)|g' | sed -e 's|CELL_ROOTFS|$(DEST_ROOTFS)|g' > $(DEST_NOMAD_JOBS)/cell.nomad

.PHONY: plan
plan: # Plan for cell.nomad
	sudo nomad job plan $(DEST_NOMAD_JOBS)/cell.nomad

.PHONY: run
run: # Run nomad cell.nomad job
	sudo nomad job run $(DEST_NOMAD_JOBS)/cell.nomad

.PHONY: setup-cni
setup-cni: # setup box cni config
	git clone https://github.com/awslabs/tc-redirect-tap.git $(TMP_DIR)/tc-redirect-tap || true
	cd $(TMP_DIR)/tc-redirect-tap && make all
	mkdir -p $(CNI_BIN_DIR)
	sudo cp $(TMP_DIR)/tc-redirect-tap/tc-redirect-tap $(CNI_BIN_DIR)
	sudo mkdir -p $(CNI_NET_DIR)
	sudo cp $(SRC_CNI_DIR)/* $(CNI_NET_DIR)

.PHONY: setup-firecracker
setup-firecracker: # Setup the firecracker vm
	@gum log --prefix local-hive --time RFC3339 --structured --level info "Setting up firecracker vm"
	mkdir -p $(FIRECRACKER_DATA)
	@gum log --prefix local-hive --time RFC3339 --structured --level info "Downloading kernel" src $(SRC_KERNEL)
	curl -fsSL -o $(DEST_KERNEL) $(SRC_KERNEL)
	@gum log --prefix local-hive --time RFC3339 --structured --level info "Downloaded kernel" dest $(DEST_KERNEL)
	@gum log --prefix local-hive --time RFC3339 --structured --level info "Downloading rootfs" src $(SRC_ROOTFS)
	curl -fsSL -o $(DEST_ROOTFS) $(SRC_ROOTFS)
	@gum log --prefix local-hive --time RFC3339 --structured --level info "Downloaded rootfs" dest $(DEST_ROOTFS)
	@gum log --prefix local-hive --time RFC3339 --structured --level info "Creating firecracker config file" file $(DEST_FIRECRACKER_CONF)
	cat $(SRC_FIRECRACKER_CONF) | sed -e 's|DEST_KERNEL|$(DEST_KERNEL)|g' | sed -e 's|DEST_ROOTFS|$(DEST_ROOTFS)|g' > $(DEST_FIRECRACKER_CONF)

.PHONY: run-firecracker
run-firecracker: # Run firecracker
	@gum log --prefix local-hive --time RFC3339 --structured --level info "Running firecracker" socket $(FIRECRACKER_SOCKET)
	firecracker --no-api --config-file $(DEST_FIRECRACKER_CONF)

.PHONY: setup
setup: setup-nomad setup-firecracker setup-cni # Set up everything

.PHONY: kill-all
kill-all: # Shutdown nomad and firecracker-task-driver
	sudo kill -KILL $(shell pidof nomad) || true
	sudo kill -KILL $(shell pidof firecracker-task-driver) || true
	sudo rm -rf $(NOMAD_DATA)/server || true
	sudo rm -rf $(NOMAD_DATA)/client || true

.PHONY: help
help: ## Show this help
	@echo "Specify a command. The choices are:"
	@grep -hE '^[0-9a-zA-Z_-]+:.*?## .*$$' ${MAKEFILE_LIST} | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[0;36m%-20s\033[m %s\n", $$1, $$2}'
	@echo ""


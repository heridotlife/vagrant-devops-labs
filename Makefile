#############################################################################
# Kubernetes Lab - Makefile (MVP)
#############################################################################
# Primary interface for all cluster operations
#
# Usage:
#   make help          Show all available targets
#   make setup-macos   Install prerequisites on macOS
#   make init          Initialize environment
#   make up            Start the cluster
#   make cluster-init  Initialize Kubernetes
#   make test-all      Run all validation tests
#
#############################################################################

.DEFAULT_GOAL := help
.PHONY: help

# Load environment variables from .env if it exists
-include .env
export

#############################################################################
# Color Output
#############################################################################

RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
CYAN := \033[0;36m
NC := \033[0m # No Color

#############################################################################
# Variables
#############################################################################

CLUSTER_NAME ?= k8s-lab
K8S_VERSION ?= 1.31.0
VAGRANT := vagrant
ANSIBLE := ansible-playbook
KUBECTL := kubectl

# Directories
ANSIBLE_DIR := ansible
PLAYBOOKS_DIR := $(ANSIBLE_DIR)/playbooks
INVENTORY := $(ANSIBLE_DIR)/inventory/hosts.ini
SCRIPTS_DIR := scripts
CONFIGS_DIR := configs
LOGS_DIR := logs

# Timestamp for logs
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)

#############################################################################
# Helper Functions
#############################################################################

define print_header
	@echo ""
	@echo "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║$(NC)  $(1)"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
endef

define print_success
	@echo "$(GREEN)✓$(NC) $(1)"
endef

define print_error
	@echo "$(RED)✗$(NC) $(1)"
endef

define print_info
	@echo "$(BLUE)ℹ$(NC) $(1)"
endef

define print_warning
	@echo "$(YELLOW)⚠$(NC) $(1)"
endef

#############################################################################
# Self-Documenting Help
#############################################################################

help: ## Show this help message
	@echo ""
	@echo "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║$(NC)          Kubernetes Lab - Available Commands                $(CYAN)║$(NC)"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)Setup & Initialization:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		sed 's/^[^:]*://g' | \
		awk 'BEGIN {FS = ":.*?## "}; /^(setup-macos|init|validate-env|check-prereqs):/ {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)VM Lifecycle:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		sed 's/^[^:]*://g' | \
		awk 'BEGIN {FS = ":.*?## "}; /^(up|halt|destroy|reload|provision|status|ssh-[a-z]+):/ {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Cluster Operations:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		sed 's/^[^:]*://g' | \
		awk 'BEGIN {FS = ":.*?## "}; /^(cluster-|deploy-|kubeconfig|quickstart):/ {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Validation & Testing:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		sed 's/^[^:]*://g' | \
		awk 'BEGIN {FS = ":.*?## "}; /^test-/ {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Utilities:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		sed 's/^[^:]*://g' | \
		awk 'BEGIN {FS = ":.*?## "}; /^(logs|clean|version|info):/ {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(CYAN)Examples:$(NC)"
	@echo "  make setup-macos          # Install all prerequisites"
	@echo "  make init                 # Initialize .env file"
	@echo "  make up                   # Start all VMs"
	@echo "  make cluster-init         # Initialize Kubernetes cluster"
	@echo "  make test-all             # Run all validation tests"
	@echo "  make ssh-master           # SSH to master node"
	@echo "  make ssh-worker NODE=1    # SSH to worker-01"
	@echo ""

#############################################################################
# Setup & Initialization
#############################################################################

.PHONY: setup-macos init validate-env check-prereqs

setup-macos: ## Install macOS prerequisites (Homebrew, VirtualBox, Vagrant, Ansible)
	$(call print_header,Installing macOS Prerequisites)
	@chmod +x setup-macos.sh
	@./setup-macos.sh
	$(call print_success,Prerequisites installed successfully)

init: ## Initialize environment (copy .env.example to .env)
	@echo ""
	@echo "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║$(NC)  Initializing Environment"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@if [ -f .env ]; then \
		echo "$(YELLOW)⚠$(NC) .env file already exists"; \
		read -p "Overwrite? [y/N] " response; \
		if [ "$$response" = "y" ] || [ "$$response" = "Y" ]; then \
			cp .env.example .env; \
			echo "$(GREEN)✓$(NC) Created .env from .env.example"; \
		else \
			echo "$(BLUE)ℹ$(NC) Keeping existing .env"; \
		fi; \
	else \
		cp .env.example .env; \
		echo "$(GREEN)✓$(NC) Created .env from .env.example"; \
	fi
	@echo "$(BLUE)ℹ$(NC) Review and customize .env as needed"
	@echo "$(BLUE)ℹ$(NC) Next step: make validate-env"

validate-env: ## Validate .env configuration
	@if [ ! -f .env ]; then \
		echo "$(RED)✗$(NC) .env file not found"; \
		echo "$(BLUE)ℹ$(NC) Run: make init"; \
		exit 1; \
	fi
	@chmod +x $(SCRIPTS_DIR)/utils/validate-env.sh
	@$(SCRIPTS_DIR)/utils/validate-env.sh

check-prereqs: ## Check if all prerequisites are installed
	@echo ""
	@echo "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║$(NC)  Checking Prerequisites"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "Checking required tools..."
	@command -v brew >/dev/null 2>&1 && echo "$(GREEN)✓$(NC) Homebrew installed" || echo "$(RED)✗$(NC) Homebrew not found"
	@command -v VBoxManage >/dev/null 2>&1 && echo "$(GREEN)✓$(NC) VirtualBox installed" || echo "$(RED)✗$(NC) VirtualBox not found"
	@command -v vagrant >/dev/null 2>&1 && echo "$(GREEN)✓$(NC) Vagrant installed" || echo "$(RED)✗$(NC) Vagrant not found"
	@command -v ansible >/dev/null 2>&1 && echo "$(GREEN)✓$(NC) Ansible installed" || echo "$(RED)✗$(NC) Ansible not found"
	@vagrant plugin list | grep -q vagrant-hostmanager && echo "$(GREEN)✓$(NC) vagrant-hostmanager plugin installed" || echo "$(YELLOW)⚠$(NC) vagrant-hostmanager plugin not found"
	@vagrant plugin list | grep -q vagrant-vbguest && echo "$(GREEN)✓$(NC) vagrant-vbguest plugin installed" || echo "$(YELLOW)⚠$(NC) vagrant-vbguest plugin not found"

#############################################################################
# VM Lifecycle
#############################################################################

.PHONY: up halt destroy reload provision status ssh-master ssh-worker

up: validate-env ## Start all VMs
	$(call print_header,Starting Kubernetes Cluster VMs)
	@mkdir -p $(LOGS_DIR)
	$(VAGRANT) up 2>&1 | tee $(LOGS_DIR)/vagrant-up-$(TIMESTAMP).log
	$(call print_success,All VMs started)
	@echo "$(BLUE)ℹ$(NC) Next step: make cluster-init"

halt: ## Stop all VMs
	$(call print_header,Stopping All VMs)
	$(VAGRANT) halt
	$(call print_success,All VMs stopped)

destroy: ## Destroy all VMs and clean up
	$(call print_header,Destroying All VMs)
	@read -p "This will destroy all VMs. Continue? [y/N] " response; \
	if [ "$$response" = "y" ] || [ "$$response" = "Y" ]; then \
		$(VAGRANT) destroy -f; \
		echo "$(GREEN)✓$(NC) All VMs destroyed"; \
	else \
		echo "$(BLUE)ℹ$(NC) Operation cancelled"; \
	fi

reload: ## Reload all VMs (restart with provisioning)
	$(call print_header,Reloading All VMs)
	$(VAGRANT) reload --provision
	$(call print_success,All VMs reloaded)

provision: ## Re-run provisioning on all VMs
	$(call print_header,Re-provisioning All VMs)
	$(VAGRANT) provision
	$(call print_success,Provisioning complete)

status: ## Show status of all VMs
	$(call print_header,VM Status)
	@$(VAGRANT) status

ssh-master: ## SSH to master node
	@$(VAGRANT) ssh master-01

ssh-worker: ## SSH to worker node (requires NODE=1 or NODE=2)
	@if [ -z "$(NODE)" ]; then \
		echo "$(RED)✗$(NC) NODE parameter required"; \
		echo "$(BLUE)ℹ$(NC) Usage: make ssh-worker NODE=1"; \
		exit 1; \
	fi
	@$(VAGRANT) ssh worker-0$(NODE)

#############################################################################
# Cluster Operations
#############################################################################

.PHONY: cluster-init cluster-info cluster-reset deploy-cni deploy-dns deploy-metallb deploy-storage kubeconfig

cluster-init: ## Initialize Kubernetes cluster (run after VMs are up)
	$(call print_header,Initializing Kubernetes Cluster)
	@echo "$(BLUE)ℹ$(NC) Running Ansible playbooks to set up Kubernetes"
	@if [ ! -f $(INVENTORY) ]; then \
		echo "$(RED)✗$(NC) Inventory file not found: $(INVENTORY)"; \
		echo "$(BLUE)ℹ$(NC) Run: make up"; \
		exit 1; \
	fi
	$(ANSIBLE) -i $(INVENTORY) $(PLAYBOOKS_DIR)/site.yml 2>&1 | tee $(LOGS_DIR)/cluster-init-$(TIMESTAMP).log
	$(call print_success,Kubernetes cluster initialized)
	@echo "$(BLUE)ℹ$(NC) Next step: make kubeconfig"

cluster-info: ## Display cluster information
	$(call print_header,Cluster Information)
	@if [ -f $(HOME)/.kube/config ]; then \
		$(KUBECTL) cluster-info; \
		echo ""; \
		$(KUBECTL) get nodes -o wide; \
	else \
		echo "$(RED)✗$(NC) kubeconfig not found"; \
		echo "$(BLUE)ℹ$(NC) Run: make kubeconfig"; \
	fi

cluster-reset: ## Reset cluster to fresh state (destroy certificates, etc.)
	$(call print_header,Resetting Cluster)
	@read -p "This will reset the cluster. Continue? [y/N] " response; \
	if [ "$$response" = "y" ] || [ "$$response" = "Y" ]; then \
		$(ANSIBLE) -i $(INVENTORY) $(PLAYBOOKS_DIR)/cleanup.yml; \
		echo "$(GREEN)✓$(NC) Cluster reset complete"; \
		echo "$(BLUE)ℹ$(NC) Run: make cluster-init to reinitialize"; \
	else \
		echo "$(BLUE)ℹ$(NC) Operation cancelled"; \
	fi

deploy-cni: ## Deploy Calico CNI
	$(call print_header,Deploying Calico CNI)
	@$(ANSIBLE) -i $(INVENTORY) $(PLAYBOOKS_DIR)/network.yml --tags cni
	$(call print_success,Calico CNI deployed)

deploy-dns: ## Deploy CoreDNS
	$(call print_header,Deploying CoreDNS)
	@$(ANSIBLE) -i $(INVENTORY) $(PLAYBOOKS_DIR)/dns.yml
	$(call print_success,CoreDNS deployed)

deploy-metallb: ## Deploy MetalLB LoadBalancer
	$(call print_header,Deploying MetalLB)
	@$(ANSIBLE) -i $(INVENTORY) $(PLAYBOOKS_DIR)/loadbalancer.yml
	$(call print_success,MetalLB deployed)

deploy-storage: ## Deploy local-path-provisioner
	$(call print_header,Deploying Storage Provisioner)
	@$(ANSIBLE) -i $(INVENTORY) $(PLAYBOOKS_DIR)/storage.yml
	$(call print_success,Storage provisioner deployed)

kubeconfig: ## Generate and merge kubeconfig
	$(call print_header,Generating Kubeconfig)
	@chmod +x $(SCRIPTS_DIR)/utils/kubeconfig-merge.sh
	@$(SCRIPTS_DIR)/utils/kubeconfig-merge.sh
	$(call print_success,Kubeconfig merged to ~/.kube/config)
	@echo "$(BLUE)ℹ$(NC) Try: kubectl get nodes"

#############################################################################
# Validation & Testing
#############################################################################

.PHONY: test-all test-infra test-cluster test-network test-storage test-e2e

test-all: ## Run all validation tests
	$(call print_header,Running All Validation Tests)
	@$(MAKE) test-infra
	@$(MAKE) test-cluster
	@$(MAKE) test-network
	@$(MAKE) test-storage
	@$(MAKE) test-e2e
	$(call print_success,All validation tests complete)

test-infra: ## Test infrastructure (VMs, network, SSH)
	$(call print_header,Testing Infrastructure)
	@chmod +x $(SCRIPTS_DIR)/validation/01-infrastructure.sh
	@$(SCRIPTS_DIR)/validation/01-infrastructure.sh

test-cluster: ## Test cluster health (etcd, control plane, nodes)
	$(call print_header,Testing Cluster Health)
	@chmod +x $(SCRIPTS_DIR)/validation/02-cluster-health.sh
	@$(SCRIPTS_DIR)/validation/02-cluster-health.sh

test-network: ## Test networking (CNI, DNS, connectivity)
	$(call print_header,Testing Networking)
	@chmod +x $(SCRIPTS_DIR)/validation/03-networking.sh
	@$(SCRIPTS_DIR)/validation/03-networking.sh

test-storage: ## Test storage provisioning
	$(call print_header,Testing Storage)
	@chmod +x $(SCRIPTS_DIR)/validation/04-storage.sh
	@$(SCRIPTS_DIR)/validation/04-storage.sh

test-e2e: ## Run end-to-end application test
	$(call print_header,Running End-to-End Test)
	@chmod +x $(SCRIPTS_DIR)/validation/05-e2e-app.sh
	@$(SCRIPTS_DIR)/validation/05-e2e-app.sh

#############################################################################
# Utilities
#############################################################################

.PHONY: logs clean clean-all version info

logs: ## View logs (requires COMPONENT=apiserver|etcd|kubelet|etc)
	@if [ -z "$(COMPONENT)" ]; then \
		echo "$(RED)✗$(NC) COMPONENT parameter required"; \
		echo "$(BLUE)ℹ$(NC) Usage: make logs COMPONENT=apiserver"; \
		echo "$(BLUE)ℹ$(NC) Available: apiserver etcd controller-manager scheduler kubelet kube-proxy"; \
		exit 1; \
	fi
	@echo "$(BLUE)ℹ$(NC) Viewing logs for: $(COMPONENT)"
	@$(VAGRANT) ssh master-01 -c "sudo journalctl -u kube-$(COMPONENT) -f"

clean: ## Clean temporary files and logs
	$(call print_header,Cleaning Temporary Files)
	@rm -rf $(LOGS_DIR)/*.log
	@rm -rf $(CONFIGS_DIR)/pki/*.pem
	@rm -rf $(CONFIGS_DIR)/pki/*.key
	@rm -rf $(ANSIBLE_DIR)/inventory/hosts.ini
	$(call print_success,Temporary files cleaned)

clean-all: destroy clean ## Nuclear clean (destroy VMs and clean all files)
	$(call print_header,Nuclear Clean)
	@rm -rf .vagrant/
	@rm -f .env
	$(call print_success,Complete cleanup finished)

version: ## Show versions of all components
	$(call print_header,Component Versions)
	@echo "Cluster Configuration:"
	@if [ -f .env ]; then \
		echo "  • Cluster Name: $$(grep CLUSTER_NAME .env | cut -d= -f2)"; \
		echo "  • Kubernetes: $$(grep K8S_VERSION .env | cut -d= -f2)"; \
		echo "  • Container Runtime: $$(grep CONTAINER_RUNTIME .env | cut -d= -f2)"; \
		echo "  • CNI: $$(grep CNI_PLUGIN .env | cut -d= -f2)"; \
	fi
	@echo ""
	@echo "Local Tools:"
	@command -v vagrant >/dev/null 2>&1 && echo "  • $$(vagrant --version)" || echo "  • Vagrant: not installed"
	@command -v VBoxManage >/dev/null 2>&1 && echo "  • VirtualBox: $$(VBoxManage --version)" || echo "  • VirtualBox: not installed"
	@command -v ansible >/dev/null 2>&1 && echo "  • $$(ansible --version | head -n1)" || echo "  • Ansible: not installed"
	@echo ""
	@if command -v $(KUBECTL) >/dev/null 2>&1 && [ -f $(HOME)/.kube/config ]; then \
		echo "Cluster (from kubectl):"; \
		$(KUBECTL) version --short 2>/dev/null || $(KUBECTL) version; \
	fi

info: ## Display comprehensive cluster information
	$(call print_header,Cluster Information)
	@echo "$(YELLOW)Configuration:$(NC)"
	@if [ -f .env ]; then \
		echo "  • Cluster: $$(grep CLUSTER_NAME .env | cut -d= -f2)"; \
		echo "  • K8s Version: $$(grep K8S_VERSION .env | cut -d= -f2)"; \
		echo "  • Masters: $$(grep VM_COUNT_MASTERS .env | cut -d= -f2)"; \
		echo "  • Workers: $$(grep VM_COUNT_WORKERS .env | cut -d= -f2)"; \
		echo "  • Network: $$(grep NETWORK_CIDR .env | cut -d= -f2)"; \
	fi
	@echo ""
	@echo "$(YELLOW)VM Status:$(NC)"
	@$(VAGRANT) status --machine-readable 2>/dev/null | grep "state," | awk -F, '{printf "  • %-15s %s\n", $$2, $$4}' || $(VAGRANT) status
	@echo ""
	@if [ -f $(HOME)/.kube/config ]; then \
		echo "$(YELLOW)Cluster Status:$(NC)"; \
		$(KUBECTL) get nodes 2>/dev/null || echo "  Cluster not initialized"; \
		echo ""; \
		echo "$(YELLOW)System Pods:$(NC)"; \
		$(KUBECTL) get pods -n kube-system 2>/dev/null || echo "  Cluster not initialized"; \
	fi

#############################################################################
# Quick Start Workflow
#############################################################################

.PHONY: quickstart

quickstart: ## Complete setup from scratch (setup -> init -> up -> cluster-init)
	$(call print_header,Kubernetes Lab - Quick Start)
	@echo "$(BLUE)ℹ$(NC) This will set up the entire cluster from scratch"
	@echo "$(BLUE)ℹ$(NC) This may take 20-30 minutes"
	@read -p "Continue? [y/N] " response; \
	if [ "$$response" = "y" ] || [ "$$response" = "Y" ]; then \
		$(MAKE) check-prereqs || $(MAKE) setup-macos; \
		$(MAKE) init; \
		$(MAKE) validate-env; \
		$(MAKE) up; \
		$(MAKE) cluster-init; \
		$(MAKE) kubeconfig; \
		$(MAKE) info; \
		echo "$(GREEN)✓$(NC) Quick start complete!"; \
	else \
		echo "$(BLUE)ℹ$(NC) Operation cancelled"; \
	fi

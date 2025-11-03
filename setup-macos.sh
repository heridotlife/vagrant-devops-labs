#!/usr/bin/env bash

#############################################################################
# Kubernetes Lab - macOS Prerequisites Setup Script
#############################################################################
# This script automates the installation of all prerequisites needed to run
# the Kubernetes lab environment on macOS.
#
# Prerequisites installed:
#   - Homebrew (package manager)
#   - VirtualBox (hypervisor)
#   - Vagrant (VM orchestration)
#   - Ansible (configuration management)
#   - Required Vagrant plugins
#
# Usage:
#   ./setup-macos.sh [--force] [--skip-prompts]
#
# Options:
#   --force         Force reinstall even if packages exist
#   --skip-prompts  Skip confirmation prompts (use defaults)
#
#############################################################################

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Version requirements
readonly MIN_MACOS_VERSION="11.0"
readonly VIRTUALBOX_VERSION="7.0"
readonly VAGRANT_MIN_VERSION="2.3.0"
readonly ANSIBLE_MIN_VERSION="2.15.0"

# Flags
FORCE_INSTALL=false
SKIP_PROMPTS=false

# Log file
readonly LOG_FILE="$(pwd)/logs/setup-$(date +%Y%m%d-%H%M%S).log"
readonly LOG_DIR="$(dirname "$LOG_FILE")"

#############################################################################
# Utility Functions
#############################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    case "$level" in
        INFO)
            echo -e "${BLUE}ℹ${NC}  $message"
            ;;
        SUCCESS)
            echo -e "${GREEN}✓${NC}  $message"
            ;;
        WARNING)
            echo -e "${YELLOW}⚠${NC}  $message"
            ;;
        ERROR)
            echo -e "${RED}✗${NC}  $message"
            ;;
        *)
            echo "   $message"
            ;;
    esac
}

error_exit() {
    log ERROR "$1"
    echo ""
    log ERROR "Setup failed. Check log file: $LOG_FILE"
    exit 1
}

confirm() {
    if [ "$SKIP_PROMPTS" = true ]; then
        return 0
    fi

    local prompt="$1"
    local response

    read -p "$prompt [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

version_compare() {
    # Returns 0 if $1 >= $2
    local v1=$1
    local v2=$2

    if [ "$(printf '%s\n' "$v2" "$v1" | sort -V | head -n1)" = "$v2" ]; then
        return 0
    else
        return 1
    fi
}

#############################################################################
# Check Functions
#############################################################################

check_macos_version() {
    log INFO "Checking macOS version..."

    local macos_version=$(sw_vers -productVersion)
    log INFO "Detected macOS version: $macos_version"

    if ! version_compare "$macos_version" "$MIN_MACOS_VERSION"; then
        error_exit "macOS $MIN_MACOS_VERSION or higher is required. You have $macos_version"
    fi

    log SUCCESS "macOS version $macos_version is compatible"
}

check_architecture() {
    log INFO "Checking system architecture..."

    local arch=$(uname -m)
    log INFO "Detected architecture: $arch"

    if [ "$arch" = "arm64" ]; then
        log WARNING "Apple Silicon detected. VirtualBox may run under Rosetta 2"
        log WARNING "Performance may be reduced. Consider using native alternatives"
    elif [ "$arch" = "x86_64" ]; then
        log SUCCESS "Intel architecture detected - fully compatible"
    else
        error_exit "Unsupported architecture: $arch"
    fi
}

check_disk_space() {
    log INFO "Checking available disk space..."

    local available_gb=$(df -g . | awk 'NR==2 {print $4}')
    local required_gb=50

    log INFO "Available disk space: ${available_gb}GB"

    if [ "$available_gb" -lt "$required_gb" ]; then
        log WARNING "Less than ${required_gb}GB available. Recommended: ${required_gb}GB or more"
        if ! confirm "Continue anyway?"; then
            exit 0
        fi
    else
        log SUCCESS "Sufficient disk space available: ${available_gb}GB"
    fi
}

#############################################################################
# Installation Functions
#############################################################################

install_homebrew() {
    log INFO "Checking Homebrew installation..."

    if command -v brew &> /dev/null; then
        local brew_version=$(brew --version | head -n1)
        log SUCCESS "Homebrew is already installed: $brew_version"

        if [ "$FORCE_INSTALL" = false ]; then
            log INFO "Updating Homebrew..."
            brew update >> "$LOG_FILE" 2>&1 || log WARNING "Failed to update Homebrew"
            return 0
        fi
    fi

    log INFO "Installing Homebrew..."

    if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >> "$LOG_FILE" 2>&1; then
        error_exit "Failed to install Homebrew"
    fi

    # Add Homebrew to PATH for Apple Silicon
    if [ -d "/opt/homebrew/bin" ]; then
        export PATH="/opt/homebrew/bin:$PATH"
    fi

    log SUCCESS "Homebrew installed successfully"
}

install_virtualbox() {
    log INFO "Checking VirtualBox installation..."

    if command -v VBoxManage &> /dev/null && [ "$FORCE_INSTALL" = false ]; then
        local vbox_version=$(VBoxManage --version | cut -d'r' -f1)
        log SUCCESS "VirtualBox is already installed: $vbox_version"
        return 0
    fi

    log INFO "Installing VirtualBox..."
    log INFO "Note: You may need to allow Oracle in System Preferences > Security & Privacy"

    if ! brew install --cask virtualbox >> "$LOG_FILE" 2>&1; then
        log ERROR "VirtualBox installation failed"
        log INFO "This is often due to security restrictions. Please:"
        log INFO "  1. Open System Preferences > Security & Privacy"
        log INFO "  2. Click 'Allow' for Oracle software"
        log INFO "  3. Re-run this script"
        error_exit "VirtualBox installation failed - check security settings"
    fi

    # Install VirtualBox Extension Pack
    log INFO "Installing VirtualBox Extension Pack..."
    local vbox_version=$(VBoxManage --version | cut -d'r' -f1)
    local ext_pack_url="https://download.virtualbox.org/virtualbox/${vbox_version}/Oracle_VM_VirtualBox_Extension_Pack-${vbox_version}.vbox-extpack"

    if ! curl -fsSL "$ext_pack_url" -o /tmp/vbox-extpack.vbox-extpack >> "$LOG_FILE" 2>&1; then
        log WARNING "Failed to download VirtualBox Extension Pack"
    else
        if VBoxManage extpack install --replace /tmp/vbox-extpack.vbox-extpack --accept-license=56be48f923303c8cababb0bb4c478284b688ed23f16d775d729b89a2e8e5f9eb >> "$LOG_FILE" 2>&1; then
            log SUCCESS "VirtualBox Extension Pack installed"
        else
            log WARNING "Failed to install VirtualBox Extension Pack"
        fi
        rm -f /tmp/vbox-extpack.vbox-extpack
    fi

    log SUCCESS "VirtualBox installed successfully"
}

install_vagrant() {
    log INFO "Checking Vagrant installation..."

    if command -v vagrant &> /dev/null && [ "$FORCE_INSTALL" = false ]; then
        local vagrant_version=$(vagrant --version | awk '{print $2}')
        log SUCCESS "Vagrant is already installed: $vagrant_version"

        if ! version_compare "$vagrant_version" "$VAGRANT_MIN_VERSION"; then
            log WARNING "Vagrant version $vagrant_version is below recommended $VAGRANT_MIN_VERSION"
            if confirm "Upgrade Vagrant?"; then
                FORCE_INSTALL=true
            else
                return 0
            fi
        else
            return 0
        fi
    fi

    log INFO "Installing Vagrant..."

    if ! brew install --cask vagrant >> "$LOG_FILE" 2>&1; then
        error_exit "Failed to install Vagrant"
    fi

    log SUCCESS "Vagrant installed successfully"
}

install_vagrant_plugins() {
    log INFO "Checking Vagrant plugins..."

    local plugins=(
        "vagrant-vbguest"
        "vagrant-hostmanager"
    )

    for plugin in "${plugins[@]}"; do
        if vagrant plugin list | grep -q "^$plugin"; then
            log SUCCESS "Vagrant plugin '$plugin' is already installed"
        else
            log INFO "Installing Vagrant plugin: $plugin"
            if ! vagrant plugin install "$plugin" >> "$LOG_FILE" 2>&1; then
                log WARNING "Failed to install Vagrant plugin: $plugin"
            else
                log SUCCESS "Installed Vagrant plugin: $plugin"
            fi
        fi
    done
}

install_ansible() {
    log INFO "Checking Ansible installation..."

    if command -v ansible &> /dev/null && [ "$FORCE_INSTALL" = false ]; then
        local ansible_version=$(ansible --version | head -n1 | awk '{print $2}' | sed 's/\[.*\]//')
        log SUCCESS "Ansible is already installed: $ansible_version"

        if ! version_compare "$ansible_version" "$ANSIBLE_MIN_VERSION"; then
            log WARNING "Ansible version $ansible_version is below recommended $ANSIBLE_MIN_VERSION"
            if confirm "Upgrade Ansible?"; then
                FORCE_INSTALL=true
            else
                return 0
            fi
        else
            return 0
        fi
    fi

    log INFO "Installing Ansible..."

    if ! brew install ansible >> "$LOG_FILE" 2>&1; then
        error_exit "Failed to install Ansible"
    fi

    log SUCCESS "Ansible installed successfully"
}

#############################################################################
# Verification Functions
#############################################################################

verify_installations() {
    log INFO "Verifying all installations..."
    echo ""

    local all_good=true

    # Check Homebrew
    if command -v brew &> /dev/null; then
        local brew_version=$(brew --version | head -n1)
        log SUCCESS "Homebrew: $brew_version"
    else
        log ERROR "Homebrew: NOT FOUND"
        all_good=false
    fi

    # Check VirtualBox
    if command -v VBoxManage &> /dev/null; then
        local vbox_version=$(VBoxManage --version)
        log SUCCESS "VirtualBox: $vbox_version"
    else
        log ERROR "VirtualBox: NOT FOUND"
        all_good=false
    fi

    # Check Vagrant
    if command -v vagrant &> /dev/null; then
        local vagrant_version=$(vagrant --version)
        log SUCCESS "Vagrant: $vagrant_version"
    else
        log ERROR "Vagrant: NOT FOUND"
        all_good=false
    fi

    # Check Ansible
    if command -v ansible &> /dev/null; then
        local ansible_version=$(ansible --version | head -n1)
        log SUCCESS "Ansible: $ansible_version"
    else
        log ERROR "Ansible: NOT FOUND"
        all_good=false
    fi

    echo ""

    if [ "$all_good" = true ]; then
        return 0
    else
        return 1
    fi
}

#############################################################################
# Main Script
#############################################################################

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║        Kubernetes Lab - macOS Prerequisites Setup              ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                     Setup Complete!                            ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    log SUCCESS "All prerequisites have been installed successfully"
    echo ""
    echo "Next steps:"
    echo "  1. Initialize the environment:"
    echo "     ${BLUE}make init${NC}"
    echo ""
    echo "  2. Review and edit .env file with your preferences"
    echo ""
    echo "  3. Start the Kubernetes cluster:"
    echo "     ${BLUE}make up${NC}"
    echo ""
    echo "  4. Initialize the cluster:"
    echo "     ${BLUE}make cluster-init${NC}"
    echo ""
    echo "For more information, see README.md"
    echo ""
    log INFO "Setup log saved to: $LOG_FILE"
    echo ""
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --skip-prompts)
                SKIP_PROMPTS=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --force         Force reinstall even if packages exist"
                echo "  --skip-prompts  Skip confirmation prompts"
                echo "  --help, -h      Show this help message"
                exit 0
                ;;
            *)
                error_exit "Unknown option: $1"
                ;;
        esac
    done
}

main() {
    parse_arguments "$@"

    # Create log directory
    mkdir -p "$LOG_DIR"

    print_header

    log INFO "Starting macOS prerequisites setup"
    log INFO "Log file: $LOG_FILE"
    echo ""

    # Pre-flight checks
    check_macos_version
    check_architecture
    check_disk_space
    echo ""

    # Installations
    install_homebrew
    install_virtualbox
    install_vagrant
    install_vagrant_plugins
    install_ansible
    echo ""

    # Verification
    if ! verify_installations; then
        error_exit "Some installations failed. Please review the log file"
    fi

    print_summary
}

# Run main function
main "$@"

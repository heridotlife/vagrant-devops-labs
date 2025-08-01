# Project Folder Structure

## Overview
This document describes the organized folder structure of the vagrant-devops-labs project.

## Root Directory
```
vagrant-devops-labs/
├── Vagrantfile                    # Main Vagrant configuration
├── README.md                      # Project documentation
├── LICENSE                        # License file
├── .gitignore                     # Git ignore rules
├── .plans/                        # Development plans
│   └── DEVELOPMENT_PLAN.md       # Current development plan
├── ansible/                       # Ansible automation
│   ├── inventory                  # Host inventory
│   ├── group_vars/               # Group variables
│   │   └── all.yml              # Global variables
│   ├── roles/                    # Ansible roles (future)
│   ├── k8s-master.yml           # Master node setup
│   ├── k8s-worker.yml           # Worker node setup
│   ├── monitoring-setup.yml      # Monitoring VM setup
│   └── k8s-monitoring-config.yml # K8s monitoring config
├── configs/                       # Configuration files
│   ├── kubernetes/               # K8s configurations
│   ├── monitoring/               # Monitoring configs
│   │   └── docker-compose-monitoring.yml.j2
│   └── network/                  # Network configurations
├── docs/                         # Documentation
│   ├── setup/                    # Setup guides
│   ├── monitoring/               # Monitoring docs
│   └── troubleshooting/          # Troubleshooting guides
├── scripts/                      # Utility scripts
│   ├── deployment/               # Deployment scripts
│   ├── monitoring/               # Monitoring scripts
│   └── utils/                    # Utility scripts
│       ├── test_network.sh      # Network testing
│       └── add_known_host.sh    # SSH host management
├── monitoring/                    # Monitoring configurations
│   ├── grafana/                  # Grafana configs
│   ├── prometheus/               # Prometheus configs
│   │   └── prometheus.yml.j2    # Prometheus config template
│   └── loki/                     # Loki configs
└── .vagrant/                     # Vagrant metadata (auto-generated)
```

## Directory Purposes

### `/ansible/`
- **inventory**: Defines all hosts (masters, workers, monitoring)
- **group_vars/**: Global variables and configurations
- **roles/**: Reusable Ansible roles (for future use)
- **k8s-*.yml**: Kubernetes cluster setup playbooks
- **monitoring-*.yml**: Monitoring stack setup playbooks

### `/configs/`
- **kubernetes/**: Kubernetes-specific configurations
- **monitoring/**: Monitoring stack configurations
- **network/**: Network and firewall configurations

### `/docs/`
- **setup/**: Installation and setup guides
- **monitoring/**: Monitoring stack documentation
- **troubleshooting/**: Common issues and solutions

### `/scripts/`
- **deployment/**: Automated deployment scripts
- **monitoring/**: Monitoring-related scripts
- **utils/**: General utility scripts

### `/monitoring/`
- **grafana/**: Grafana dashboard configurations
- **prometheus/**: Prometheus configuration templates
- **loki/**: Loki log aggregation configurations

## File Organization Rules

1. **Configuration Files**: Place in `/configs/` with appropriate subdirectories
2. **Documentation**: Place in `/docs/` with topic-based subdirectories
3. **Scripts**: Place in `/scripts/` with purpose-based subdirectories
4. **Templates**: Place in `/monitoring/` for monitoring templates
5. **Ansible**: Keep playbooks in `/ansible/` root, roles in `/ansible/roles/`

## Best Practices

- Keep related files together in appropriate directories
- Use descriptive names for files and directories
- Maintain separation between configuration, documentation, and automation
- Follow consistent naming conventions
- Document any new directories or file organization changes 
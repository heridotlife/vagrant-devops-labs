# Documentation

This directory contains comprehensive documentation for the Kubernetes lab environment.

## Structure

```
docs/
├── architecture/            # Architecture documentation
│   ├── network-design.md   # Network topology and design
│   ├── security-model.md   # Security architecture
│   └── ha-design.md        # High availability considerations
├── guides/                  # User guides
│   ├── quick-start.md      # Getting started guide
│   ├── version-upgrade.md  # Kubernetes version upgrade guide
│   ├── cni-selection.md    # CNI comparison and selection
│   └── storage-guide.md    # Storage usage and management
└── reference/               # Reference documentation
    ├── makefile-targets.md # Complete Makefile target reference
    ├── environment-vars.md # Environment variable reference
    └── troubleshooting.md  # Common issues and solutions
```

## Core Documentation

The main documentation files are in the project root:

- **README.md** - Main project documentation
  - Quick start guide
  - Installation instructions
  - Basic usage
  - Common operations

- **ARCHITECTURE.md** - System architecture
  - Component overview
  - Network design
  - Security model
  - Design decisions

- **TROUBLESHOOTING.md** - Troubleshooting guide
  - Common issues
  - Diagnostic procedures
  - Recovery steps
  - Known limitations

## Documentation Standards

When writing documentation:
- Use clear, concise language
- Include code examples
- Provide context and rationale
- Keep information up-to-date
- Link to related documentation
- Use consistent formatting
- Include diagrams where helpful

## Contributing

To contribute to documentation:
1. Ensure accuracy of information
2. Follow existing structure and style
3. Test all commands and examples
4. Update related documentation
5. Review for clarity and completeness

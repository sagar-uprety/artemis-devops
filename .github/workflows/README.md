# GitHub Actions Workflows - DISABLED

> **Note:** This project was originally developed and built using **GitLab CI/CD** (see `.gitlab-ci.yml` in each repository). The source code has been migrated to GitHub for **showcase purposes only**. All GitHub Actions workflows from the original Artemis codebase have been disabled and are not intended to run.

The actual CI/CD pipeline for this project runs on GitLab. The `.gitlab-ci.yml` files contain the active pipeline definitions for:
- Hadolint (Dockerfile linting)
- Conftest/OPA (Dockerfile policy validation)
- Trivy (vulnerability scanning)
- Kaniko (rootless container builds)
- Cosign (image signing)
- Dockle (container image linting - Online IDE)

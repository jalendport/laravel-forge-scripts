# Atomic Deployment Script for Laravel Forge

## Overview

This script enables atomic deployments for PHP applications in Laravel Forge environments. It creates a robust deployment process that allows for zero-downtime deployments with the ability to quickly rollback if needed. Though designed primarily for Craft CMS projects, it can be adapted for other PHP platforms with minimal modifications.

## Requirements

- **Laravel Forge**: This script replaces Forge's default deployment script
- **Web Directory Configuration**: You must set your site's Web Directory to `/current/web` in Forge

## Installation

1. Copy the [entire script](atomic-deployment.sh)
2. In Laravel Forge, go to your site's management page
3. Navigate to the "Deployments" tab
4. Replace the default deployment script with this script
5. Save changes

## CI/CD Integration

For optimal use with the **`partial`** deployment type (more on that below), configure your CI/CD pipeline to:

1. Clone your repository
2. Run build steps (composer install, npm build, etc.)
3. Rsync the built files to your server's `deploy-cache` directory
4. Trigger the Forge deployment script

> [!NOTE]
> You can trigger the Forge script by making a `GET` or `POST` request to the "**Deployment Trigger URL**", found on the "Deployments" tab on the site management page in Forge.

> [!IMPORTANT]
> You will want to ensure "**Quick Deploy**" is disabled for the site as we only want the Forge deployment script being triggered once the CI/CD pipeline is finished.

## How It Works

The script establishes a directory structure that enables atomic deployments:

```
your-site/
├── current -> releases/[commit-hash]-[deployment-id] (symlink to current release)
├── deploy-cache/ (where your code is initially deployed)
├── persistent/ (persistent files and directories)
└── releases/ (contains all your deployments)
    ├── [commit-hash]-[deployment-id]/
    ├── [commit-hash]-[deployment-id]/
    └── ...
```

### Deployment Process

1. Creates necessary directories if they don't exist
2. Pulls latest files from the repo (if using "complete" deployment type)
3. Creates a new release directory with a unique identifier
4. Copies files from deploy-cache to the new release directory
5. Symlinks persistent files and directories
6. Runs composer install (if using "complete" deployment type)
7. Updates the "current" symlink to point to the new release
8. Executes post-deployment script if specified
9. Restarts PHP-FPM
10. Cleans up old releases

## Configuration Options

### `CONFIG_DEPLOYMENT_TYPE`

```bash
# CONFIG_DEPLOYMENT_TYPE: Sets deployment strategy
#   'partial'  - External CI/CD handles build steps, final files rsync'd to `deploy-cache`
#   'complete' - Server performs git pull to `deploy-cache` and runs composer install locally
CONFIG_DEPLOYMENT_TYPE="partial"
```

#### Complete vs Partial Deployment Types

- **Partial Deployment (`partial`)**:
  - Designed to work with external CI/CD pipelines (GitHub Actions, Buddy, GitLab CI, etc.)
  - Your CI/CD pipeline handles build steps (composer install, npm build, etc.)
  - Final built files are rsync'd to the `deploy-cache` folder
  - Better for complex builds with frontend assets
  - More powerful but requires additional CI/CD configuration

- **Complete Deployment (`complete`)**:
  - Simpler setup requiring only Laravel Forge
  - Performs `git pull` directly on the server
  - Runs `composer install` on the server
  - Best for simpler projects or when you don't have CI/CD pipelines
  - Limitations: Doesn't handle frontend builds (npm, webpack, etc.) without customization

### Other Options

There are some other configuration options defined at the top of the script with some simple documentation for each.

## Adapting for Other Platforms

While designed for Craft CMS, this script can be adapted for other PHP platforms:

1. Modify `CONFIG_PERSISTENT_FILES` and `CONFIG_PERSISTENT_DIRECTORIES` to match your platform's needs
2. Change `CONFIG_POST_DEPLOYMENT_COMPOSER_SCRIPT` to match your script name, or leave blank if unneeded.
3. Adjust the Web Directory path if your platform doesn't use `/web` as the public directory


# Silverblue Backup Preparation

A bash script designed to prepare the state of a **Fedora Silverblue** system for backup. This script aggregates configuration files, package lists, and toolbox metadata into a single directory, facilitating easy backup with tools like **Pika Backup** or **Restic**.

## 🚀 Features

This script automatically backs up the following components:

### 1. Shell Data
*   **History:** Backs up `.bash_history` and `.zsh_history`.
*   **Configuration:** Copies `.bashrc`, `.zshrc`, and `.p10k.zsh` (Powerlevel10k config).

### 2. System Configuration
*   **GNOME Settings:** Exports all dconf settings to `gnome-settings.dconf`.
*   **Layered Packages:** Lists all packages layered via `rpm-ostree`.
*   **Flatpaks:** Generates a list of all installed Flatpak applications.

### 3. Toolbox Containers
For each toolbox container found, the script creates a dedicated directory containing:
*   **Metadata:** Image name and detected shells (Bash/Zsh).
*   **Repositories:** Backs up `/etc/yum.repos.d/`.
*   **User Packages:** Lists packages installed by the user (`dnf repoquery --userinstalled`).
*   **Manual Binaries:** Lists files in `/usr/local/bin`.

## 🛠 Usage

1.  **Download the script:**
    Clone this repository or download `prepare-backup.sh` directly.

2.  **Make executable:**
    ```bash
    chmod +x prepare-backup.sh
    ```

3.  **Run the script:**
    ```bash
    ./prepare-backup.sh
    ```

The script will create a directory at `~/Documents/Silverblue-State-Backup` containing all exported data. It will also provide a colorful summary of what was backed up.

## 📂 Output Structure

After running the script, your backup directory will look like this:

```
~/Documents/Silverblue-State-Backup/
├── bash_history_backup
├── zsh_history_backup
├── .bashrc
├── .zshrc
├── .p10k.zsh
├── gnome-settings.dconf
├── layered-packages.txt
├── flatpaks.txt
└── toolboxes/
    └── [toolbox-name]/
        ├── recipe.txt        # Metadata, shells, package list
        └── yum.repos.d/      # Repository configurations
```

## 🔒 Security Note

This script has been checked for hardcoded secrets and none were found. However, please be aware that the **generated backup files** may contain sensitive information:

*   **Shell History:** May contain commands with passwords or API keys if you typed them directly into the terminal.
*   **Dconf Dump:** May contain sensitive GNOME settings or extension configurations.
*   **Config Files:** Your `.bashrc` or `.zshrc` might contain exported tokens or secrets.

**Recommendation:** Always encrypt your backups (e.g., using Pika Backup with a password or Restic) to protect your data.

#!/bin/bash

# --- Configuration ---
BACKUP_DIR="$HOME/Documents/Silverblue-State-Backup"
mkdir -p "$BACKUP_DIR"

# --- Colors ---
NC='\033[1;34m'           # No Color
TITLE_COL='\033[1;32m' # Blue (Kept for headers)

# Two-Tone Palette (Muted)
C1='\033[0;33m' # Muted Yellow
C2='\033[0;36m' # Muted Teal

echo -e "${TITLE_COL}Starting State Export to:${NC} $BACKUP_DIR"

# ---------------------------------------------------------
# 1. Shell Data (History & Configs)
# ---------------------------------------------------------
# History
if [ -f "$HOME/.bash_history" ]; then cp "$HOME/.bash_history" "$BACKUP_DIR/bash_history_backup"; fi
if [ -f "$HOME/.zsh_history" ]; then cp "$HOME/.zsh_history" "$BACKUP_DIR/zsh_history_backup"; fi

# Configs (OhMyZsh, Bashrc, Powerlevel10k)
cp "$HOME/.zshrc" "$BACKUP_DIR/" 2>/dev/null
cp "$HOME/.bashrc" "$BACKUP_DIR/" 2>/dev/null
cp "$HOME/.p10k.zsh" "$BACKUP_DIR/" 2>/dev/null

# ---------------------------------------------------------
# 2. System Config
# ---------------------------------------------------------
dconf dump / > "$BACKUP_DIR/gnome-settings.dconf"
rpm-ostree status --json | jq -r '.deployments[0].packages[]' > "$BACKUP_DIR/layered-packages.txt" 2>/dev/null
flatpak list --app --columns=application > "$BACKUP_DIR/flatpaks.txt"

# ---------------------------------------------------------
# 3. Toolbox Recipe Enumeration
# ---------------------------------------------------------
mkdir -p "$BACKUP_DIR/toolboxes"
TOOLBOX_NAMES=$(podman ps -a --filter label=com.github.containers.toolbox="true" --format "{{.Names}}")

for tbox in $TOOLBOX_NAMES; do
    TBOX_DIR="$BACKUP_DIR/toolboxes/$tbox"
    mkdir -p "$TBOX_DIR"
    RECIPE_FILE="$TBOX_DIR/recipe.txt"
    
    echo "### TOOLBOX METADATA ###" > "$RECIPE_FILE"
    podman inspect --format 'Image: {{.ImageName}}' "$tbox" >> "$RECIPE_FILE"
    
    echo -e "\n### DETECTED SHELLS ###" >> "$RECIPE_FILE"
    HAS_BASH=$(toolbox run --container "$tbox" command -v bash > /dev/null && echo "YES" || echo "NO")
    HAS_ZSH=$(toolbox run --container "$tbox" command -v zsh > /dev/null && echo "YES" || echo "NO")
    echo "Bash: $HAS_BASH" >> "$RECIPE_FILE"
    echo "Zsh:  $HAS_ZSH" >> "$RECIPE_FILE"

    mkdir -p "$TBOX_DIR/yum.repos.d"
    podman cp "$tbox":/etc/yum.repos.d/. "$TBOX_DIR/yum.repos.d/"

    echo -e "\n### USER INSTALLED PACKAGES ###" >> "$RECIPE_FILE"
    if toolbox run --container "$tbox" command -v dnf &> /dev/null; then
        toolbox run --container "$tbox" dnf repoquery --userinstalled --qf "%{name}" >> "$RECIPE_FILE" 2>/dev/null
    fi

    echo -e "\n### MANUAL BINARIES (/usr/local/bin) ###" >> "$RECIPE_FILE"
    toolbox run --container "$tbox" ls -1 /usr/local/bin >> "$RECIPE_FILE" 2>/dev/null
done

# ---------------------------------------------------------
# 4. Interactive Summary
# ---------------------------------------------------------

print_list() {
    local items=("$@")
    if [ ${#items[@]} -eq 0 ]; then echo -e "${NC}None"; return; fi

    local count=0
    local output=""
    for item in "${items[@]}"; do
        if [ -z "$item" ]; then continue; fi
        
        # Cycle between Yellow and Teal
        mod=$((count % 2))
        case $mod in
            0) color=$C1 ;; # Yellow
            1) color=$C2 ;; # Teal
        esac
        
        if [ $count -gt 0 ]; then output+="${NC}, "; fi
        output+="${color}${item}"
        ((count++))
    done
    echo -e "$output${NC}"
}

if [ -t 1 ]; then
    echo -e "\n${NC}========================================${NC}"
    echo -e "${TITLE_COL}      BACKUP PREPARATION COMPLETE       ${NC}"
    echo -e "${NC}========================================${NC}"
    
    echo -e "\n${TITLE_COL}📂 HOST SYSTEM STATE${NC}"
    
    echo -ne "  ${TITLE_COL}➜ GNOME Extensions:${NC} "
    mapfile -t host_exts < <(gnome-extensions list --enabled 2>/dev/null)
    print_list "${host_exts[@]}"

    echo -ne "  ${TITLE_COL}➜ Layered PKGs:${NC}     "
    mapfile -t host_layers < <(cat "$BACKUP_DIR/layered-packages.txt" 2>/dev/null)
    print_list "${host_layers[@]}"

    echo -ne "  ${TITLE_COL}➜ Flatpaks:${NC}         "
    mapfile -t host_flats < <(cat "$BACKUP_DIR/flatpaks.txt" 2>/dev/null)
    print_list "${host_flats[@]}"
    
    echo -e "  ${TITLE_COL}➜ Shell Data:${NC}"
    if [ -f "$BACKUP_DIR/.zshrc" ]; then zsh_status="${C2}Config & History${NC}"; else zsh_status="${NC}History Only${NC}"; fi
    if [ -f "$BACKUP_DIR/.bashrc" ]; then bash_status="${C2}Config & History${NC}"; else bash_status="${NC}History Only${NC}"; fi
    
    echo -e "      - Bash: $bash_status"
    echo -e "      - Zsh:  $zsh_status"

    echo -e "\n${TITLE_COL}📦 TOOLBOXES PROCESSED${NC}"
    
    if [ -z "$(ls -A $BACKUP_DIR/toolboxes)" ]; then
         echo -e "  ${NC}No toolboxes found."
    else
        for d in "$BACKUP_DIR/toolboxes/"*; do
            if [ -d "$d" ]; then
                tname=$(basename "$d")
                recipe="$d/recipe.txt"
                
                shells=""
                grep -q "Bash: YES" "$recipe" && shells+="Bash "
                grep -q "Zsh: YES" "$recipe" && shells+="Zsh"
                [ -z "$shells" ] && shells="None"
                
                repo_count=$(ls -1 "$d/yum.repos.d" | wc -l)

                echo -e "  ${TITLE_COL}➜ $tname${NC}"
                echo -e "      Shells:   $shells"
                echo -e "      Repos:    $repo_count exported"
                echo -ne "      Packages: "
                
                mapfile -t box_pkgs < <(sed -n '/### USER INSTALLED PACKAGES ###/,/### MANUAL BINARIES/p' "$recipe" | grep -v "###" | grep -v '^\s*$')
                
                print_list "${box_pkgs[@]}"
            fi
        done
    fi

    echo -e "\n${TITLE_COL}Next Step:${NC} Run Pika Backup now."
fi

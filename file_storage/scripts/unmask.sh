#!/bin/bash
# Virtual Server Unmasking Script for file_storage
# This script removes masks from Virtual Server resources in main.tf

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MAIN_TF="$PROJECT_DIR/main.tf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Virtual Server Unmasking Script${NC}"
echo -e "${CYAN}File Storage Environment${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Check if main.tf exists
if [[ ! -f "$MAIN_TF" ]]; then
    echo -e "${RED}Error: main.tf not found at $MAIN_TF${NC}"
    exit 1
fi

# Function to check if there are any masked lines
check_for_masks() {
    local mask_count=$(grep -c "^#resource\|^#[[:space:]]*[a-zA-Z]" "$MAIN_TF" 2>/dev/null || echo "0")
    if [[ "$mask_count" -eq 0 ]]; then
        echo -e "${YELLOW}No masked resources found in main.tf${NC}"
        echo "The file appears to already be unmasked or was never masked."
        return 1
    fi
    echo -e "${CYAN}Found $mask_count masked lines to unmask${NC}"
    return 0
}

# Function to restore from backup
restore_from_backup() {
    echo -e "${YELLOW}Looking for backup files...${NC}"
    
    local backup_files=($(ls -1t "$PROJECT_DIR"/main.tf.backup.* 2>/dev/null | head -5))
    
    if [[ ${#backup_files[@]} -eq 0 ]]; then
        echo -e "${RED}No backup files found!${NC}"
        echo "Cannot restore original main.tf"
        return 1
    fi
    
    echo -e "${CYAN}Available backup files:${NC}"
    local i=1
    for backup in "${backup_files[@]}"; do
        local backup_name=$(basename "$backup")
        local backup_time=$(echo "$backup_name" | sed 's/main.tf.backup.//' | sed 's/_/ /')
        echo -e "  $i) $backup_name (created: $backup_time)"
        ((i++))
    done
    
    echo ""
    echo -e "${YELLOW}Choose restore method:${NC}"
    echo -e "  ${GREEN}A${NC}) Auto-restore from latest backup"
    echo -e "  ${GREEN}S${NC}) Select specific backup file"
    echo -e "  ${GREEN}M${NC}) Manual unmask (remove # from masked lines)"
    echo -e "  ${RED}C${NC}) Cancel operation"
    echo ""
    
    while true; do
        read -p "Select option [A/S/M/C]: " choice
        case ${choice^^} in
            A)
                echo -e "${YELLOW}Restoring from latest backup: ${backup_files[0]}${NC}"
                cp "${backup_files[0]}" "$MAIN_TF"
                echo -e "${GREEN}✅ Successfully restored from backup!${NC}"
                return 0
                ;;
            S)
                echo "Select backup file (1-${#backup_files[@]}):"
                read -p "Enter number: " selection
                if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#backup_files[@]} ]]; then
                    local selected_backup="${backup_files[$((selection-1))]}"
                    echo -e "${YELLOW}Restoring from: $selected_backup${NC}"
                    cp "$selected_backup" "$MAIN_TF"
                    echo -e "${GREEN}✅ Successfully restored from selected backup!${NC}"
                    return 0
                else
                    echo -e "${RED}Invalid selection. Please try again.${NC}"
                fi
                ;;
            M)
                manual_unmask
                return $?
                ;;
            C)
                echo -e "${YELLOW}Operation cancelled by user${NC}"
                return 1
                ;;
            *)
                echo -e "${RED}Invalid option. Please enter A, S, M, or C.${NC}"
                ;;
        esac
    done
}

# Function to manually unmask lines
manual_unmask() {
    echo -e "${YELLOW}Performing manual unmask...${NC}"
    
    # Create a temporary backup
    local temp_backup="$MAIN_TF.temp.$(date +%s)"
    cp "$MAIN_TF" "$temp_backup"
    
    # Remove masks from lines that start with #
    # But be careful to only unmask lines that were actually masked resources/attributes
    sed -i 's/^#\(resource\|[[:space:]]*[a-zA-Z][a-zA-Z0-9_]*[[:space:]]*=\|[[:space:]]*depends_on\|[[:space:]]*}\)/\1/g' "$MAIN_TF"
    
    # Count how many lines were unmasked
    local unmasked_count=$(diff "$temp_backup" "$MAIN_TF" | grep -c "^<" 2>/dev/null || echo "0")
    
    if [[ "$unmasked_count" -gt 0 ]]; then
        echo -e "${GREEN}✅ Successfully unmasked $unmasked_count lines!${NC}"
        rm -f "$temp_backup"
        return 0
    else
        echo -e "${YELLOW}No changes made - no masked resources found${NC}"
        rm -f "$temp_backup"
        return 1
    fi
}

# Main execution
main() {
    if ! check_for_masks; then
        # No masks found, check if we should restore from backup
        echo ""
        read -p "Would you like to restore from a backup file instead? [y/N]: " restore_choice
        if [[ ${restore_choice^^} == "Y" ]]; then
            restore_from_backup
        fi
        return
    fi
    
    restore_from_backup
    
    echo ""
    echo -e "${CYAN}Summary:${NC}"
    echo -e "  • Virtual Server resources: Unmasked"
    echo -e "  • Dependent resources: Unmasked" 
    echo -e "  • Syntax: Restored to working state"
    echo ""
    echo -e "${YELLOW}Note: Run terraform plan to verify the configuration${NC}"
}

main "$@"
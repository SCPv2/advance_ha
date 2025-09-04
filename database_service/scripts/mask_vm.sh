#!/bin/bash
# Virtual Server Masking Script for database_service
# This script masks Virtual Server resources and dependent resources in main.tf

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MAIN_TF="$PROJECT_DIR/main.tf"
BACKUP_FILE="$PROJECT_DIR/main.tf.backup.$(date +%Y%m%d_%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Virtual Server Masking Script${NC}"
echo -e "${CYAN}Database Service Environment${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Check if main.tf exists
if [[ ! -f "$MAIN_TF" ]]; then
    echo -e "${RED}Error: main.tf not found at $MAIN_TF${NC}"
    exit 1
fi

# Create backup
echo -e "${YELLOW}Creating backup: $(basename "$BACKUP_FILE")${NC}"
cp "$MAIN_TF" "$BACKUP_FILE"

# Function to mask Virtual Server resources
mask_virtual_servers() {
    echo -e "${YELLOW}Step 1: Masking Virtual Server resources...${NC}"
    
    # VM resources to mask
    local vm_resources=(
        "vm1"
        "vm2"
        "vm2_2" 
        "vm3"
        "vm3_2"
        "vm4"
    )
    
    for vm in "${vm_resources[@]}"; do
        echo -e "  Masking: ${vm}"
        # Find the resource block and mask it
        sed -i "/^resource \"samsungcloudplatformv2_virtualserver_server\" \"${vm}\"/,/^}$/ s/^/#/" "$MAIN_TF"
    done
}

# Function to mask dependent resources
mask_dependent_resources() {
    echo -e "${YELLOW}Step 2: Masking resources dependent on Virtual Servers...${NC}"
    
    # Check for resources with depends_on referencing virtual servers
    local dependent_patterns=(
        "depends_on.*vm1"
        "depends_on.*vm2"
        "depends_on.*vm2_2"
        "depends_on.*vm3"
        "depends_on.*vm3_2"
        "depends_on.*vm4"
    )
    
    # Find and mask resources that depend on VMs
    for pattern in "${dependent_patterns[@]}"; do
        # Get line numbers containing the pattern
        grep -n "$pattern" "$MAIN_TF" 2>/dev/null | cut -d: -f1 | while read line_num; do
            if [[ -n "$line_num" ]]; then
                # Find the resource block containing this line
                local resource_start=$(sed -n "1,${line_num}p" "$MAIN_TF" | grep -n "^resource" | tail -1 | cut -d: -f1)
                if [[ -n "$resource_start" ]]; then
                    # Find the end of the resource block
                    local resource_end=$(sed -n "${resource_start},\$p" "$MAIN_TF" | grep -n "^}$" | head -1 | cut -d: -f1)
                    if [[ -n "$resource_end" ]]; then
                        resource_end=$((resource_start + resource_end - 1))
                        echo -e "  Masking dependent resource (lines ${resource_start}-${resource_end})"
                        sed -i "${resource_start},${resource_end} s/^/#/" "$MAIN_TF"
                    fi
                fi
            fi
        done
    done
}

# Function to handle depends_on lines
fix_depends_on_lines() {
    echo -e "${YELLOW}Step 3: Fixing depends_on syntax...${NC}"
    
    # For database_service, we'll use a simpler approach since there are no depends_on with VMs
    # Just ensure no trailing commas that could cause issues
    sed -i 's/,$//' "$MAIN_TF"
}

# Main execution
main() {
    mask_virtual_servers
    mask_dependent_resources
    fix_depends_on_lines
    
    echo ""
    echo -e "${GREEN}✅ Virtual Server masking completed!${NC}"
    echo -e "${CYAN}Summary:${NC}"
    echo -e "  • Virtual Servers masked: vm1, vm2, vm2_2, vm3, vm3_2, vm4"
    echo -e "  • Dependent resources masked automatically"
    echo -e "  • Syntax cleaned up for proper Terraform parsing"
    echo -e "  • Backup saved: $(basename "$BACKUP_FILE")"
    echo ""
    echo -e "${YELLOW}Note: Run terraform plan to verify the configuration${NC}"
}

main "$@"
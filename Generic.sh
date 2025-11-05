#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ROM_NAME="${ROM_NAME:-derp}"
DRY_RUN=0

# Logging functions
log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Print banner
echo ""
echo "════════════════════════════════════════════════"
echo "🚀 Nothing Phone Setup Script for ${ROM_NAME^^}"
echo "════════════════════════════════════════════════"
echo ""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --rom-name)
            ROM_NAME="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --rom-name NAME    Set ROM name (default: derp)"
            echo "  --dry-run          Show what would be done without executing"
            echo "  --help             Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ "$DRY_RUN" -eq 1 ]; then
    log_warning "Running in DRY RUN mode - no changes will be made"
    echo ""
fi

# ============================================================================
# Git Clone
# ============================================================================
echo ""
echo "════════════════════════════════════════════════"
echo "📥 Cloning repositories"
echo "════════════════════════════════════════════════"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would clone device, kernel, vendor, hardware, and camera repositories"
else
    git clone -b derp16 https://github.com/DaViDev985/device_nothing_Spacewar.git device/nothing/Spacewar
    git clone -b derp16 https://github.com/DaViDev985/kernel_nothing_sm7325.git kernel/nothing/sm7325
    GIT_LFS_SKIP_SMUDGE=1 git clone -b derp16 https://github.com/DaViDev985/vendor_nothing_Spacewar.git vendor/nothing/Spacewar
    git clone -b derp16 https://github.com/DaViDev985/android_hardware_nothing.git hardware/nothing
    git clone -b derp16 https://github.com/DaViDev985/proprietary_vendor_nothing_camera.git vendor/nothing/camera
    log_success "All repositories cloned"
fi

# ============================================================================
# Apply Commits
# ============================================================================
echo ""
echo "════════════════════════════════════════════════"
echo "🔀 Applying commits"
echo "════════════════════════════════════════════════"
echo ""

# Commit 1: vendor/nothing/Spacewar from muppets
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would apply commit b69b9f09 from TheMuppets to vendor/nothing/Spacewar"
else
    cd vendor/nothing/Spacewar || exit
    git stash push -m "Temp stash before cherry-pick"
    git remote add muppets https://github.com/TheMuppets/proprietary_vendor_nothing_Spacewar.git 2>/dev/null
    git fetch muppets
    git cherry-pick -X theirs --allow-empty b69b9f09c77bb53f43666e6cadde57ab601c15a4
    log_success "Applied commit from muppets"
    cd - >/dev/null || exit
fi

# Commit 2: device/nothing/Spacewar from lineage
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would apply commit aae038e4 from LineageOS to device/nothing/Spacewar"
else
    cd device/nothing/Spacewar || exit
    git stash push -m "Temp stash before cherry-pick"
    git remote add lineage https://github.com/LineageOS/android_device_nothing_Spacewar.git 2>/dev/null
    git fetch lineage
    git cherry-pick -X theirs --allow-empty aae038e48a7cfe60805d37663555258c50e38f55
    log_success "Applied commit from lineage"
    cd - >/dev/null || exit
fi

# Commit 3: vendor/nothing/Spacewar from davidev
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would apply commit af074591 from davidev to vendor/nothing/Spacewar"
else
    cd vendor/nothing/Spacewar || exit
    git stash push -m "Temp stash before cherry-pick"
    git remote add davidev https://github.com/DaViDev985/vendor_nothing_Spacewar.git 2>/dev/null
    git fetch davidev
    if ! git cherry-pick -X theirs --allow-empty af074591e9a880b9869b9aba49d2af658cb2dcf8; then
        log_warning "Cherry-pick failed, attempting to resolve"
        if git stash pop; then
            git commit --allow-empty -m "Cherry-pick commit af07459 from davidev"
        fi
    fi
    log_success "Applied commit from davidev"
    cd - >/dev/null || exit
fi

# ============================================================================
# Update Radio Files
# ============================================================================
echo ""
echo "════════════════════════════════════════════════"
echo "📻 Updating radio files"
echo "════════════════════════════════════════════════"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would clone radio files from lineage-23.0 branch"
else
    mkdir -p tmp
    cd tmp || exit
    git clone -b lineage-23.0 https://github.com/TheMuppets/proprietary_vendor_nothing_Spacewar.git
    cd .. || exit
    rm -rf vendor/nothing/Spacewar/radio
    cp -r tmp/proprietary_vendor_nothing_Spacewar/radio vendor/nothing/Spacewar/
    rm -rf tmp
    log_success "Radio files updated"
fi

# ============================================================================
# Fix Files and Rename
# ============================================================================
echo ""
echo "════════════════════════════════════════════════"
echo "🔄 Renaming files and replacing strings"
echo "════════════════════════════════════════════════"
echo ""

directories=(
    "device/nothing/Spacewar"
    "kernel/nothing/sm7325"
    "vendor/nothing/Spacewar"
    "hardware/nothing"
)

for folder in "${directories[@]}"; do
    if [ ! -d "$folder" ]; then
        log_warning "Directory $folder not found, skipping"
        continue
    fi

    echo "──────────────────────────────────────────────"
    echo "Processing directory: $folder"
    echo "──────────────────────────────────────────────"

    # Replace inside files
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would replace ROM prefixes with '${ROM_NAME}_Spacewar' in $folder"
    else
        grep -rl "lineage_Spacewar" "$folder" 2>/dev/null | xargs -r sed -i "s/lineage_Spacewar/${ROM_NAME}_Spacewar/g"
        grep -rl "aosp_Spacewar" "$folder" 2>/dev/null | xargs -r sed -i "s/aosp_Spacewar/${ROM_NAME}_Spacewar/g"
        grep -rl "mica_Spacewar" "$folder" 2>/dev/null | xargs -r sed -i "s/mica_Spacewar/${ROM_NAME}_Spacewar/g"
        grep -rl "clover_Spacewar" "$folder" 2>/dev/null | xargs -r sed -i "s/clover_Spacewar/${ROM_NAME}_Spacewar/g"
        log_success "Replaced ROM prefixes with '${ROM_NAME}_Spacewar' in $folder"
    fi

    # Rename files/folders
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would rename files/folders containing ROM prefixes in $folder"
    else
        for prefix in lineage aosp mica clover; do
            find "$folder" -depth -name "*${prefix}_Spacewar*" 2>/dev/null -exec bash -c '
                f="{}"
                rom_name="'"$ROM_NAME"'"
                prefix="'"$prefix"'"
                newname="$(dirname "$f")/$(basename "$f" | sed "s/${prefix}_Spacewar/${rom_name}_Spacewar/g")"
                if [ "$f" != "$newname" ]; then
                    mv "$f" "$newname"
                    echo "Renamed: $(basename "$f") → $(basename "$newname")"
                fi
            ' \;
        done
    fi

    # Replace ROM prefixes in mk files
    mk_files=$(find "$folder" -type f \( -name "*${ROM_NAME}_Spacewar.mk" -o -name "BoardConfig.mk" \) 2>/dev/null)
    if [ -n "$mk_files" ]; then
        for mk in $mk_files; do
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "Would replace ROM prefixes with '$ROM_NAME' in $mk"
            else
                sed -i -e "s/\blineage\b/$ROM_NAME/g" \
                       -e "s/\baosp\b/$ROM_NAME/g" \
                       -e "s/\bmica\b/$ROM_NAME/g" \
                       -e "s/\bclover\b/$ROM_NAME/g" "$mk"
                log_success "Updated $(basename "$mk")"
            fi
        done
    fi
done

# ============================================================================
# Fix Vendor Files
# ============================================================================
echo ""
echo "════════════════════════════════════════════════"
echo "🔧 Fixing vendor-specific files"
echo "════════════════════════════════════════════════"
echo ""

vendor_android_mk="vendor/nothing/Spacewar/Android.mk"
if [ -f "$vendor_android_mk" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would fix radio file SHA1 checks in $vendor_android_mk"
    else
        if sed -i 's/add-radio-file-sha1-checked,\(radio\/[^,]*\),[^)>]*/add-radio-file,\1/g' "$vendor_android_mk"; then
            log_success "Fixed radio file SHA1 checks in Android.mk"
        else
            log_error "Failed to modify $vendor_android_mk"
        fi
    fi
else
    log_warning "$vendor_android_mk not found, skipping radio file fix"
fi

# ============================================================================
# Setup KernelSU
# ============================================================================
echo ""
echo "════════════════════════════════════════════════"
echo "🔧 Setting up KernelSU"
echo "════════════════════════════════════════════════"
echo ""

kernel_folder="kernel/nothing/sm7325"
if [ -d "$kernel_folder" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would set up KernelSU in $kernel_folder"
    else
        cd "$kernel_folder" || exit
        rm -rf KernelSU-Next
        if curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5; then
            log_success "KernelSU setup completed"
        else
            log_error "KernelSU setup failed"
        fi
        cd - >/dev/null || exit
    fi
else
    log_warning "$kernel_folder not found, skipping KernelSU setup"
fi

# ============================================================================
# Fix Package Allowed List
# ============================================================================
echo ""
echo "════════════════════════════════════════════════"
echo "📦 Fixing package allowed list"
echo "════════════════════════════════════════════════"
echo ""

pkg_file="build/soong/scripts/check_boot_jars/package_allowed_list.txt"
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would ensure $pkg_file contains com\\.nothing entries"
else
    mkdir -p "$(dirname "$pkg_file")"
    touch "$pkg_file"
    grep -qxF "com\\.nothing" "$pkg_file" || echo "com\\.nothing" >> "$pkg_file"
    grep -qxF "com\\.nothing\\..*" "$pkg_file" || echo "com\\.nothing\\..*" >> "$pkg_file"
    log_success "Updated $pkg_file"
fi

# ============================================================================
# Fix Android.bp References
# ============================================================================
echo ""
echo "════════════════════════════════════════════════"
echo "🔧 Fixing Android.bp references"
echo "════════════════════════════════════════════════"
echo ""

android_bp_file="hardware/interfaces/compatibility_matrices/Android.bp"
if [ -f "$android_bp_file" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would replace 'vendor/lineage' with 'vendor/$ROM_NAME' in $android_bp_file"
    else
        if grep -q "vendor/lineage" "$android_bp_file"; then
            sed -i "s|vendor/lineage|vendor/$ROM_NAME|g" "$android_bp_file"
            log_success "Fixed vendor paths in $android_bp_file"
        else
            log_info "No vendor/lineage references found."
        fi
    fi
else
    log_warning "$android_bp_file not found, skipping fix"
fi

# ============================================================================
# Update Device Framework Matrix
# ============================================================================
echo ""
echo "════════════════════════════════════════════════"
echo "📋 Updating device framework matrix"
echo "════════════════════════════════════════════════"
echo ""

config_dir="vendor/${ROM_NAME}/config"
matrix_file="device_framework_matrix.xml"
matrix_url="https://raw.githubusercontent.com/zetamins/Nothing_Script_Spacewar/refs/heads/main/device_framework_matrix.xml"

if [ -d "$config_dir" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would download $matrix_file if missing in $config_dir"
    else
        cd "$config_dir" || exit
        if [ ! -f "$matrix_file" ]; then
            if curl -LSs -o "$matrix_file" "$matrix_url"; then
                log_success "Downloaded $matrix_file"
            else
                log_error "Failed to download $matrix_file"
            fi
        else
            log_success "$matrix_file already exists, skipping download"
        fi
        cd - >/dev/null || exit
    fi
else
    log_warning "$config_dir not found, skipping matrix update"
fi

# ============================================================================
# Completion
# ============================================================================
echo ""
echo "════════════════════════════════════════════════"
echo "✅ Setup completed!"
echo "════════════════════════════════════════════════"
echo ""
echo "ROM Name: ${ROM_NAME}"
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Mode: DRY RUN (no changes made)"
fi
echo ""

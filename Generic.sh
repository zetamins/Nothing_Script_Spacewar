#!/bin/bash

# 🧪 Dry run mode: set to 0 to execute, 1 to preview commands
DRY_RUN=0

# 🎯 ROM name parameter - change this to your ROM name (e.g., "voltage", "lineage", "evolution")
ROM_NAME="${1:-euclid}"

echo "════════════════════════════════════════════════"
echo "🚀 ROM Setup Script"
echo "📱 ROM Name: $ROM_NAME"
echo "🧪 Dry Run: $DRY_RUN"
echo "════════════════════════════════════════════════"
echo ""

# 🧩 List of git clone commands
clones=(
"git clone -b derp16 https://github.com/DaViDev985/device_nothing_Spacewar.git device/nothing/Spacewar"
"git clone -b derp16-ksun https://github.com/DaViDev985/kernel_nothing_sm7325.git kernel/nothing/sm7325"
"git clone -b derp16 https://github.com/DaViDev985/vendor_nothing_Spacewar.git"
"git clone -b derp16 https://github.com/DaViDev985/android_hardware_nothing.git hardware/nothing"
)

for cmd in "${clones[@]}"; do
    folder=$(echo "$cmd" | awk '{print $NF}')

    echo "──────────────────────────────────────────────"
    echo "Processing repository: $folder"
    echo "──────────────────────────────────────────────"

    # 1️⃣ Delete folder if it exists
    if [ -d "$folder" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "Would delete folder: $folder"
        else
            echo "Deleting folder $folder..."
            rm -rf "$folder"
            echo "Deleted $folder."
        fi
    fi

    # 2️⃣ Clone the repository
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would run: $cmd"
    else
        echo "Cloning: $cmd"
        $cmd
        echo "Cloned $folder successfully."
    fi

    # 3️⃣ Replace text inside files
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would replace 'lineage_Spacewar' with '${ROM_NAME}_Spacewar' in $folder"
    else
        echo "Replacing 'lineage_Spacewar' with '${ROM_NAME}_Spacewar' in $folder..."
        grep -rl "lineage_Spacewar" "$folder" | xargs sed -i "s/lineage_Spacewar/${ROM_NAME}_Spacewar/g" 2>/dev/null
        echo "Replacements completed in $folder."
    fi

    # 4️⃣ Rename files/folders containing lineage_Spacewar
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would rename files/folders containing 'lineage_Spacewar' to '${ROM_NAME}_Spacewar' in $folder"
        find "$folder" -depth -name "*lineage_Spacewar*"
    else
        echo "Renaming files/folders containing 'lineage_Spacewar' to '${ROM_NAME}_Spacewar'..."
        find "$folder" -depth -name "*lineage_Spacewar*" -exec bash -c '
            f="{}"
            rom_name="'"$ROM_NAME"'"
            newname="$(dirname "$f")/$(basename "$f" | sed "s/lineage_Spacewar/${rom_name}_Spacewar/g")"
            mv "$f" "$newname"
            echo "Renamed $f → $newname"
        ' \;
        echo "Renaming done in $folder."
    fi

    mk_files=$(find "$folder" -type f \( -name "*${ROM_NAME}_Spacewar.mk" -o -name "BoardConfig.mk" \))
    if [ -n "$mk_files" ]; then
        for mk in $mk_files; do
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "Would replace 'lineage' with '$ROM_NAME' in $mk"
            else
                echo "Updating $mk..."
                sed -i "s/lineage/$ROM_NAME/g" "$mk"
                echo "Replaced all 'lineage' with '$ROM_NAME' in $mk."
            fi
        done
    fi

    # 6️⃣ Replace all 'lineage' with ROM_NAME in ${ROM_NAME}_Spacewar.mk
    mk_files=$(find "$folder" -type f -name "*${ROM_NAME}_Spacewar.mk")
    if [ -n "$mk_files" ]; then
        for mk in $mk_files; do
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "Would replace 'lineage' with '$ROM_NAME' in $mk"
            else
                echo "Updating $mk..."
                sed -i "s/lineage/$ROM_NAME/g" "$mk"
                echo "Replaced all 'lineage' with '$ROM_NAME' in $mk."
            fi
        done
    fi
done

# 7️⃣ Cherry-pick commits from upstream repositories
echo ""
echo "════════════════════════════════════════════════"
echo "🍒 Cherry-picking upstream commits"
echo "════════════════════════════════════════════════"
echo ""

# Cherry-pick function
cherry_pick_commit() {
    local LOCAL_DIR=$1
    local REMOTE_NAME=$2
    local REMOTE_REPO=$3
    local COMMIT_SHA=$4
    
    echo "──────────────────────────────────────────────"
    echo "Cherry-picking in $LOCAL_DIR"
    echo "──────────────────────────────────────────────"
    
    if [ ! -d "$LOCAL_DIR" ]; then
        echo "⚠️  Directory $LOCAL_DIR not found, skipping cherry-pick"
        return
    fi
    
    cd "$LOCAL_DIR" || { echo "Failed to enter $LOCAL_DIR"; return; }
    
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would add remote $REMOTE_NAME: $REMOTE_REPO"
        echo "Would fetch from $REMOTE_NAME"
        echo "Would cherry-pick commit $COMMIT_SHA"
    else
        # Add remote if not exists
        if git remote | grep -q "^${REMOTE_NAME}$"; then
            echo "Remote $REMOTE_NAME already exists"
        else
            echo "Adding remote $REMOTE_NAME..."
            git remote add "$REMOTE_NAME" "$REMOTE_REPO"
        fi
        
        # Fetch remote
        echo "Fetching from $REMOTE_NAME..."
        git fetch "$REMOTE_NAME" || { echo "Failed to fetch from $REMOTE_NAME"; cd - >/dev/null; return; }
        
        # Cherry-pick the commit
        echo "Cherry-picking commit $COMMIT_SHA..."
        if git cherry-pick "$COMMIT_SHA"; then
            echo "✅ Cherry-pick successful"
        else
            # Auto-resolve simple conflicts
            CONFLICT_FILES=$(git diff --name-only --diff-filter=U)
            if [ -n "$CONFLICT_FILES" ]; then
                echo "⚠️  Found conflicts in:"
                echo "$CONFLICT_FILES"
                echo "Attempting auto-resolution (keeping HEAD version)..."
                
                for file in $CONFLICT_FILES; do
                    echo "  Resolving $file..."
                    awk '/^<<<<<<< HEAD$/{skip=1; next} /^=======$/{skip=0; next} /^>>>>>>>/{next} !skip{print}' "$file" > "$file.tmp" \
                    && mv "$file.tmp" "$file"
                    git add "$file"
                done
                
                echo "Continuing cherry-pick..."
                if git cherry-pick --continue; then
                    echo "✅ Cherry-pick completed after conflict resolution"
                else
                    echo "❌ Failed to complete cherry-pick, aborting..."
                    git cherry-pick --abort
                fi
            else
                echo "❌ Cherry-pick failed"
            fi
        fi
    fi
    
    cd - >/dev/null
}

# Cherry-pick for vendor/nothing/Spacewar
cherry_pick_commit \
    "vendor/nothing/Spacewar" \
    "muppets" \
    "https://github.com/TheMuppets/proprietary_vendor_nothing_Spacewar.git" \
    "b69b9f09c77bb53f43666e6cadde57ab601c15a4"

# Cherry-pick for device/nothing/Spacewar
cherry_pick_commit \
    "device/nothing/Spacewar" \
    "lineage" \
    "https://github.com/LineageOS/android_device_nothing_Spacewar.git" \
    "aae038e48a7cfe60805d37663555258c50e38f55"

# 8️⃣ Update package_allowed_list.txt to include com\.nothing and com\.nothing\..*
pkg_file="build/soong/scripts/check_boot_jars/package_allowed_list.txt"
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would ensure $pkg_file contains com\\.nothing and com\\.nothing\\..*"
else
    echo "Ensuring $pkg_file contains com\\.nothing and com\\.nothing\\..*"
    mkdir -p "$(dirname "$pkg_file")"
    touch "$pkg_file"

    grep -qxF "com\\.nothing" "$pkg_file" || echo "com\\.nothing" >> "$pkg_file"
    grep -qxF "com\\.nothing\\..*" "$pkg_file" || echo "com\\.nothing\\..*" >> "$pkg_file"

    echo "Updated $pkg_file successfully."
fi

# 8️⃣.5 Fix vendor/lineage references in hardware/interfaces/compatibility_matrices/Android.bp
android_bp_file="hardware/interfaces/compatibility_matrices/Android.bp"
if [ -f "$android_bp_file" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would replace 'vendor/lineage' with 'vendor/$ROM_NAME' in $android_bp_file"
        grep -n "vendor/lineage" "$android_bp_file" 2>/dev/null || echo "No 'vendor/lineage' references found"
    else
        if grep -q "vendor/lineage" "$android_bp_file" 2>/dev/null; then
            echo "Fixing vendor path references in $android_bp_file..."
            sed -i "s|vendor/lineage|vendor/$ROM_NAME|g" "$android_bp_file"
            echo "✅ Replaced 'vendor/lineage' with 'vendor/$ROM_NAME' in $android_bp_file"
        else
            echo "ℹ️  No 'vendor/lineage' references found in $android_bp_file"
        fi
    fi
else
    echo "⚠️  $android_bp_file not found, skipping vendor path fix"
fi

# 9️⃣ Update device_framework_matrix.xml in vendor/${ROM_NAME}/config/
config_dir="vendor/${ROM_NAME}/config"
matrix_file="device_framework_matrix.xml"
matrix_url="https://raw.githubusercontent.com/zetamins/Nothing_Script_Spacewar/refs/heads/main/device_framework_matrix.xml"

if [ -d "$config_dir" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would cd into $config_dir"
        if [ ! -f "$config_dir/$matrix_file" ]; then
            echo "Would download $matrix_url"
        else
            echo "File $matrix_file already exists, would skip download"
        fi
    else
        cd "$config_dir" || { echo "Failed to cd into $config_dir"; }
        
        if [ -f "$matrix_file" ]; then
            echo "✅ $matrix_file already exists, skipping download"
        else
            echo "Downloading $matrix_file from GitHub..."
            curl -LSs -o "$matrix_file" "$matrix_url"
            
            if [ -f "$matrix_file" ]; then
                echo "✅ Successfully downloaded $matrix_file"
            else
                echo "❌ Failed to download $matrix_file"
            fi
        fi
        
        cd - >/dev/null
        echo "device_framework_matrix.xml check completed."
    fi
else
    echo "⚠️  $config_dir directory not found, skipping device_framework_matrix.xml update"
fi


echo ""
echo "════════════════════════════════════════════════"
echo "✅ Script completed"
echo "📱 ROM Name: $ROM_NAME"
echo "🧪 Dry Run: $DRY_RUN"
echo "════════════════════════════════════════════════"

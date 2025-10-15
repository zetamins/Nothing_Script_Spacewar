#!/bin/bash

# 🧪 Dry run mode: set to 0 to execute, 1 to preview commands
DRY_RUN=0

# 🎯 ROM name parameter - change this to your ROM name (e.g., "voltage", "lineage", "evolution")
ROM_NAME="${1:-voltage}"

echo "════════════════════════════════════════════════"
echo "🚀 ROM Setup Script"
echo "📱 ROM Name: $ROM_NAME"
echo "🧪 Dry Run: $DRY_RUN"
echo "════════════════════════════════════════════════"
echo ""

# 🧩 List of git clone commands
clones=(
"git clone -b bka https://github.com/Evolution-X-Devices/device_nothing_Spacewar.git device/nothing/Spacewar"
"git clone -b bka https://github.com/Evolution-X-Devices/kernel_nothing_sm7325.git kernel/nothing/sm7325"
"git clone -b bka https://github.com/nyxalune/vendor_nothing_Spacewar.git vendor/nothing/Spacewar"
"git clone -b bka https://github.com/Evolution-X-Devices/hardware_nothing.git hardware/nothing"
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

    # 5️⃣ KernelSU setup (only for kernel repo)
    if [ "$folder" == "kernel/nothing/sm7325" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "Would cd into $folder, remove KernelSU-Next, and run KernelSU setup script"
        else
            echo "Setting up KernelSU in $folder..."
            cd "$folder" || { echo "Failed to cd into $folder"; continue; }
            rm -rf KernelSU-Next
            curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
            cd - >/dev/null
            echo "KernelSU setup completed."
        fi
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

# 9️⃣ Update device_framework_matrix.xml in vendor/${ROM_NAME}/config/
config_dir="vendor/${ROM_NAME}/config"
matrix_file="device_framework_matrix.xml"
matrix_url="https://raw.githubusercontent.com/zetamins/Nothing_Script_Spacewar/refs/heads/main/device_framework_matrix.xml"

if [ -d "$config_dir" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would cd into $config_dir"
        echo "Would remove $matrix_file if it exists"
        echo "Would download $matrix_url"
    else
        echo "Updating device_framework_matrix.xml in $config_dir..."
        cd "$config_dir" || { echo "Failed to cd into $config_dir"; }
        
        if [ -f "$matrix_file" ]; then
            echo "Removing existing $matrix_file..."
            rm "$matrix_file"
        fi
        
        echo "Downloading $matrix_file from GitHub..."
        curl -LSs -o "$matrix_file" "$matrix_url"
        
        if [ -f "$matrix_file" ]; then
            echo "✅ Successfully downloaded $matrix_file"
        else
            echo "❌ Failed to download $matrix_file"
        fi
        
        cd - >/dev/null
        echo "device_framework_matrix.xml update completed."
    fi
else
    echo "⚠️  $config_dir directory not found, skipping device_framework_matrix.xml update"
fi

# 🔟 Run all vendor/*priv/keys/keys.sh scripts if they exist
if [ -d "vendor" ]; then
    key_scripts=$(find vendor -type f -path "*priv/keys/keys.sh" 2>/dev/null)
else
    key_scripts=""
    echo "⚠️  vendor directory not found, skipping keys.sh execution"
fi

if [ -n "$key_scripts" ]; then
    for key_script in $key_scripts; do
        key_dir=$(dirname "$key_script")
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "Would cd into $key_dir and run bash keys.sh"
        else
            echo "Running keys.sh in $key_dir..."
            cd "$key_dir" || { echo "Failed to cd into $key_dir"; continue; }
            bash keys.sh
            cd - >/dev/null
            echo "Executed $key_script successfully."
        fi
    done
else
    echo "No vendor/*-priv/keys/keys.sh files found."
fi

echo ""
echo "════════════════════════════════════════════════"
echo "✅ Script completed"
echo "📱 ROM Name: $ROM_NAME"
echo "🧪 Dry Run: $DRY_RUN"
echo "════════════════════════════════════════════════"

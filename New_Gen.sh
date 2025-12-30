#!/bin/bash
# ==============================================================
# 🚀 ROM Setup Script – Optimized Version
# 🧩 Cherry-pick now happens BEFORE renaming & replacements
# ==============================================================

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

# ==============================================================
# 1️⃣ CLONE REPOSITORIES
# ==============================================================

clones=(
  "git clone -b bka https://github.com/zetamins/device_nothing_Spacewar.git device/nothing/Spacewar"
  "git clone -b bka https://github.com/zetamins/kernel_nothing_sm7325.git kernel/nothing/sm7325"
  "git clone -b bka https://github.com/zetamins/proprietary_vendor_nothing_Spacewar.git vendor/nothing/Spacewar"
  "git clone -b bka https://github.com/zetamins/android_hardware_nothing.git hardware/nothing"
)

for cmd in "${clones[@]}"; do
  folder=$(echo "$cmd" | awk '{print $NF}')

  echo "──────────────────────────────────────────────"
  echo "Processing repository: $folder"
  echo "──────────────────────────────────────────────"

  # Delete old folder
  if [ -d "$folder" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "Would delete folder: $folder"
    else
      echo "Deleting folder $folder..."
      rm -rf "$folder"
      echo "Deleted $folder."
    fi
  fi

  # Clone repo
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would run: $cmd"
  else
    echo "Cloning: $cmd"
    $cmd
    echo "Cloned $folder successfully."
  fi
done
# ==============================================================
# 3️⃣ RENAME FILES AND REPLACE STRINGS
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "🔄 Renaming files and replacing strings"
echo "════════════════════════════════════════════════"
echo ""

# Define directories to process
directories=(
  "device/nothing/Spacewar"
  "kernel/nothing/sm7325"
  "vendor/nothing/Spacewar"
  "hardware/nothing"
)

for folder in "${directories[@]}"; do
  if [ ! -d "$folder" ]; then
    echo "⚠️  Directory $folder not found, skipping"
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
    grep -rl "statix_Spacewar" "$folder" 2>/dev/null | xargs -r sed -i "s/statix_Spacewar/${ROM_NAME}_Spacewar/g"
    grep -rl "clover_Spacewar" "$folder" 2>/dev/null | xargs -r sed -i "s/clover_Spacewar/${ROM_NAME}_Spacewar/g"
    echo "✅ Replaced ROM prefixes with '${ROM_NAME}_Spacewar' in files."
  fi

  # Rename files/folders
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would rename files/folders containing ROM prefixes in $folder"
  else
    for prefix in lineage aosp mica statix clover; do
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

  # Replace all ROM prefixes → ROM_NAME in mk files
  mk_files=$(find "$folder" -type f \( -name "*${ROM_NAME}_Spacewar.mk" -o -name "BoardConfig.mk" \) 2>/dev/null)
  if [ -n "$mk_files" ]; then
    for mk in $mk_files; do
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would replace ROM prefixes with '$ROM_NAME' in $mk"
      else
        sed -i -e "s/\blineage\b/$ROM_NAME/g" \
               -e "s/\baosp\b/$ROM_NAME/g" \
               -e "s/\bmica\b/$ROM_NAME/g" \
               -e "s/\bstatix\b/$ROM_NAME/g" \
               -e "s/\bclover\b/$ROM_NAME/g" "$mk"
        echo "✅ Updated $(basename $mk)"
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
            echo "Fixed radio file SHA1 checks in Android.mk"
        else
            echo "Failed to modify $vendor_android_mk"
        fi
    fi
else
    log_warning "$vendor_android_mk not found, skipping radio file fix"
fi

# ==============================================================
# 4️⃣ KERNELSU SETUP
# ==============================================================

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
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
    cd - >/dev/null
    echo "✅ KernelSU setup completed."
  fi
else
  echo "⚠️  $kernel_folder not found, skipping KernelSU setup"
fi

# ==============================================================
# 5️⃣ FIX PACKAGE ALLOWED LIST
# ==============================================================

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
  echo "✅ Updated $pkg_file successfully."
fi

# ==============================================================
# 6️⃣ FIX ANDROID.BP REFERENCES
# ==============================================================

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
      echo "✅ Fixed vendor paths in $android_bp_file"
    else
      echo "ℹ️  No vendor/lineage references found."
    fi
  fi
else
  echo "⚠️  $android_bp_file not found, skipping fix."
fi

# ==============================================================
# 7️⃣ UPDATE DEVICE FRAMEWORK MATRIX
# ==============================================================

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
      curl -LSs -o "$matrix_file" "$matrix_url" && echo "✅ Downloaded $matrix_file" || echo "❌ Failed to download $matrix_file"
    else
      echo "✅ $matrix_file already exists, skipping download"
    fi
    cd - >/dev/null
  fi
else
  echo "⚠️  $config_dir not found, skipping matrix update."
fi

# ==============================================================
# ✅ COMPLETION
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "✅ Script completed successfully"
echo "📱 ROM Name: $ROM_NAME"
echo "🧪 Dry Run: $DRY_RUN"
echo "════════════════════════════════════════════════"

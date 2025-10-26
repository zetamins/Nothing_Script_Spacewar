#!/bin/bash
# ==============================================================
# 🚀 ROM Setup Script – Optimized Version
# 🧩 Cherry-pick now happens BEFORE renaming & replacements
# 🔄 Handles both lineage and aosp naming patterns
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
  "git clone -b 15.2 https://github.com/adityayyy/device_nothing_Spacewar.git device/nothing/Spacewar"
  "git clone -b lineage-22.2 https://github.com/LineageOS/android_hardware_nothing.git hardware/nothing"
  "git clone -b 15.2 https://github.com/adityayyy/proprietary_vendor_nothing_Spacewar.git vendor/nothing/Spacewar"
  "git clone -b 15.2 https://github.com/adityayyy/axion_kernel_nothing_sm7325.git kernel/nothing/sm7325"
  "git clone https://github.com/adityayyy/proprietary_vendor_nothing_camera.git vendor/nothing/camera"
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
# 2️⃣ CHERRY-PICK COMMITS (Moved before renaming)
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "🍒 Cherry-picking upstream commits"
echo "════════════════════════════════════════════════"
echo ""

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
    if ! git remote | grep -q "^${REMOTE_NAME}$"; then
      echo "Adding remote $REMOTE_NAME..."
      git remote add "$REMOTE_NAME" "$REMOTE_REPO"
    else
      echo "Remote $REMOTE_NAME already exists"
    fi

    echo "Fetching from $REMOTE_NAME..."
    git fetch "$REMOTE_NAME" || { echo "Failed to fetch from $REMOTE_NAME"; cd - >/dev/null; return; }

    echo "Cherry-picking commit $COMMIT_SHA..."
    if git cherry-pick "$COMMIT_SHA"; then
      echo "✅ Cherry-pick successful"
    else
      CONFLICT_FILES=$(git diff --name-only --diff-filter=U)
      if [ -n "$CONFLICT_FILES" ]; then
        echo "⚠️  Found conflicts, resolving automatically..."
        for file in $CONFLICT_FILES; do
          awk '/^<<<<<<< HEAD$/{skip=1; next} /^=======$/{skip=0; next} /^>>>>>>>/{next} !skip{print}' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
          git add "$file"
        done
        if git cherry-pick --continue; then
          echo "✅ Cherry-pick completed after conflict resolution"
        else
          echo "❌ Cherry-pick failed, aborting..."
          git cherry-pick --abort
        fi
      else
        echo "❌ Cherry-pick failed"
      fi
    fi
  fi
  cd - >/dev/null
}

# Perform cherry-picks BEFORE renaming
cherry_pick_commit "vendor/nothing/Spacewar" "muppets" "https://github.com/TheMuppets/proprietary_vendor_nothing_Spacewar.git" "b69b9f09c77bb53f43666e6cadde57ab601c15a4"
cherry_pick_commit "device/nothing/Spacewar" "lineage" "https://github.com/LineageOS/android_device_nothing_Spacewar.git" "aae038e48a7cfe60805d37663555258c50e38f55"

# ==============================================================
# 3️⃣ RENAME FILES AND REPLACE STRINGS
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "🔄 Renaming files and replacing strings"
echo "════════════════════════════════════════════════"
echo ""

for folder in device/nothing/Spacewar kernel/nothing/sm7325 vendor/nothing/Spacewar hardware/nothing; do
  if [ ! -d "$folder" ]; then
    echo "⚠️  $folder not found, skipping rename & replacements."
    continue
  fi

  echo "──────────────────────────────────────────────"
  echo "Updating references in $folder"
  echo "──────────────────────────────────────────────"

  # Replace both lineage_Spacewar and aosp_Spacewar patterns
  for pattern in "lineage_Spacewar" "aosp_Spacewar"; do
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "Would replace '$pattern' with '${ROM_NAME}_Spacewar' in $folder"
    else
      if grep -rl "$pattern" "$folder" 2>/dev/null | grep -q .; then
        grep -rl "$pattern" "$folder" | xargs sed -i "s/$pattern/${ROM_NAME}_Spacewar/g" 2>/dev/null
        echo "✅ Replaced '$pattern' with '${ROM_NAME}_Spacewar' in files."
      else
        echo "ℹ️  No '$pattern' references found."
      fi
    fi
  done

  # Rename files/folders containing lineage_Spacewar or aosp_Spacewar
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would rename files/folders containing 'lineage_Spacewar' or 'aosp_Spacewar'"
  else
    for pattern in "lineage_Spacewar" "aosp_Spacewar"; do
      find "$folder" -depth -name "*${pattern}*" 2>/dev/null -exec bash -c '
        f="{}"
        rom_name="'"$ROM_NAME"'"
        pattern="'"$pattern"'"
        newname="$(dirname "$f")/$(basename "$f" | sed "s/${pattern}/${rom_name}_Spacewar/g")"
        if [ "$f" != "$newname" ]; then
          mv "$f" "$newname" 2>/dev/null && echo "Renamed $f → $newname"
        fi
      ' \;
    done
  fi

  # Replace 'lineage' or 'aosp' → ROM_NAME in mk files
  mk_files=$(find "$folder" -type f \( -name "*${ROM_NAME}_Spacewar.mk" -o -name "BoardConfig.mk" -o -name "*lineage*.mk" -o -name "*aosp*.mk" \) 2>/dev/null)
  if [ -n "$mk_files" ]; then
    for mk in $mk_files; do
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "Would replace 'lineage' and 'aosp' with '$ROM_NAME' in $mk"
      else
        # Replace both lineage and aosp with ROM_NAME, but preserve case sensitivity where needed
        sed -i -e "s/\blineage\b/$ROM_NAME/g" -e "s/\baosp\b/$ROM_NAME/g" "$mk" 2>/dev/null
        echo "✅ Updated $mk"
      fi
    done
  fi
done

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
  echo "⚠️  $kernel_folder not found, skipping KernelSU setup."
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
echo "🔧 Fixing Android.bp vendor references"
echo "════════════════════════════════════════════════"
echo ""

android_bp_file="hardware/interfaces/compatibility_matrices/Android.bp"
if [ -f "$android_bp_file" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would replace 'vendor/lineage' and 'vendor/aosp' with 'vendor/$ROM_NAME' in $android_bp_file"
  else
    modified=false
    if grep -q "vendor/lineage" "$android_bp_file"; then
      sed -i "s|vendor/lineage|vendor/$ROM_NAME|g" "$android_bp_file"
      echo "✅ Fixed vendor/lineage paths in $android_bp_file"
      modified=true
    fi
    if grep -q "vendor/aosp" "$android_bp_file"; then
      sed -i "s|vendor/aosp|vendor/$ROM_NAME|g" "$android_bp_file"
      echo "✅ Fixed vendor/aosp paths in $android_bp_file"
      modified=true
    fi
    if [ "$modified" = false ]; then
      echo "ℹ️  No vendor/lineage or vendor/aosp references found."
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
echo ""
echo "Next steps:"
echo "1. source build/envsetup.sh"
echo "2. lunch ${ROM_NAME}_Spacewar-userdebug"
echo "3. m bacon (or your ROM's build command)"
echo "════════════════════════════════════════════════"

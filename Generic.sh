#!/bin/bash
# ==============================================================
# 🚀 ROM Setup Script – Enhanced Version
# 🧩 Cherry-pick now happens BEFORE renaming & replacements
# ==============================================================

# 🧪 Dry run mode: set to 0 to execute, 1 to preview commands
DRY_RUN=0

# 🎯 ROM name parameter - change this to your ROM name (e.g., "voltage", "lineage", "evolution")
ROM_NAME="${1:-euclid}"

# 📊 Error tracking
declare -a ERRORS=()
declare -a WARNINGS=()
declare -a SUCCESS=()

log_error() {
  ERRORS+=("$1")
  echo "❌ ERROR: $1"
}

log_warning() {
  WARNINGS+=("$1")
  echo "⚠️  WARNING: $1"
}

log_success() {
  SUCCESS+=("$1")
  echo "✅ $1"
}

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
  "git clone -b derp16-ossaudio https://github.com/DaViDev985/device_nothing_Spacewar.git device/nothing/Spacewar"
  "git clone -b derp16-ksun https://github.com/DaViDev985/kernel_nothing_sm7325.git kernel/nothing/sm7325"
  "git clone -b bka https://github.com/nyxalune/vendor_nothing_Spacewar.git vendor/nothing/Spacewar"
  "git clone -b derp16 https://github.com/DaViDev985/android_hardware_nothing.git hardware/nothing"
  "git clone -b derp16 https://github.com/DaViDev985/proprietary_vendor_nothing_camera.git vendor/nothing/camera"
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
      log_success "Deleted $folder"
    fi
  fi

  # Clone repo
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would run: $cmd"
  else
    echo "Cloning: $cmd"
    if $cmd; then
      log_success "Cloned $folder successfully"
    else
      log_error "Failed to clone $folder"
    fi
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
  echo "Commit: $COMMIT_SHA"
  echo "──────────────────────────────────────────────"

  if [ ! -d "$LOCAL_DIR" ]; then
    log_warning "Directory $LOCAL_DIR not found, skipping cherry-pick"
    return 1
  fi

  cd "$LOCAL_DIR" || { log_error "Failed to enter $LOCAL_DIR"; return 1; }

  # Set git to use true (no-op) as editor to avoid opening nano/vim
  export GIT_EDITOR=true

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would add remote $REMOTE_NAME: $REMOTE_REPO"
    echo "Would fetch from $REMOTE_NAME"
    echo "Would cherry-pick commit $COMMIT_SHA"
  else
    if ! git remote | grep -q "^${REMOTE_NAME}$"; then
      echo "Adding remote $REMOTE_NAME..."
      if git remote add "$REMOTE_NAME" "$REMOTE_REPO"; then
        log_success "Added remote $REMOTE_NAME"
      else
        log_error "Failed to add remote $REMOTE_NAME in $LOCAL_DIR"
        cd - >/dev/null
        return 1
      fi
    else
      echo "Remote $REMOTE_NAME already exists"
    fi

    echo "Fetching from $REMOTE_NAME..."
    if ! git fetch "$REMOTE_NAME"; then
      log_error "Failed to fetch from $REMOTE_NAME in $LOCAL_DIR"
      cd - >/dev/null
      return 1
    fi

    echo "Cherry-picking commit $COMMIT_SHA..."
    if git cherry-pick --allow-empty "$COMMIT_SHA"; then
      log_success "Cherry-pick successful: $COMMIT_SHA in $LOCAL_DIR"
    else
      CONFLICT_FILES=$(git diff --name-only --diff-filter=U)
      if [ -n "$CONFLICT_FILES" ]; then
        log_warning "Found conflicts in $LOCAL_DIR, resolving automatically..."
        for file in $CONFLICT_FILES; do
          awk '/^<<<<<<< HEAD$/{skip=1; next} /^=======$/{skip=0; next} /^>>>>>>>/{next} !skip{print}' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
          git add "$file"
        done
        if git cherry-pick --continue --allow-empty; then
          log_success "Cherry-pick completed after conflict resolution: $COMMIT_SHA in $LOCAL_DIR"
        else
          log_error "Cherry-pick failed for $COMMIT_SHA in $LOCAL_DIR (conflict resolution failed)"
          git cherry-pick --abort
          cd - >/dev/null
          return 1
        fi
      else
        log_error "Cherry-pick failed for $COMMIT_SHA in $LOCAL_DIR (no conflicts detected)"
        git cherry-pick --abort
        cd - >/dev/null
        return 1
      fi
    fi
  fi
  cd - >/dev/null
  return 0
}

# Perform cherry-picks BEFORE renaming
cherry_pick_commit "vendor/nothing/Spacewar" "muppets" "https://github.com/TheMuppets/proprietary_vendor_nothing_Spacewar.git" "b69b9f09c77bb53f43666e6cadde57ab601c15a4"
cherry_pick_commit "device/nothing/Spacewar" "lineage" "https://github.com/LineageOS/android_device_nothing_Spacewar.git" "aae038e48a7cfe60805d37663555258c50e38f55"

# New cherry-picks
cherry_pick_commit "vendor/nothing/Spacewar" "davidev" "https://github.com/DaViDev985/vendor_nothing_Spacewar.git" "af074591e9a880b9869b9aba49d2af658cb2dcf8"

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
               -e "s/\bclover\b/$ROM_NAME/g" "$mk"
        log_success "Updated $(basename $mk)"
      fi
    done
  fi
done

# ==============================================================
# 3.5️⃣ FIX VENDOR FILES
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "🔧 Fixing vendor-specific files"
echo "════════════════════════════════════════════════"
echo ""

# Remove camera provider service reference from vendor.mk
vendor_mk_file="vendor/nothing/Spacewar/Spacewar-vendor.mk"
if [ -f "$vendor_mk_file" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would remove camera provider service reference from $vendor_mk_file"
  else
    if sed -i '/android\.hardware\.camera\.provider@2\.4-service_64\.rc/d' "$vendor_mk_file"; then
      log_success "Removed camera provider service reference from Spacewar-vendor.mk"
    else
      log_error "Failed to modify $vendor_mk_file"
    fi
  fi
else
  log_warning "$vendor_mk_file not found, skipping camera provider fix"
fi

# Fix radio file SHA1 checks in Android.mk
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
    if curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5; then
      log_success "KernelSU setup completed"
    else
      log_error "KernelSU setup failed"
    fi
    cd - >/dev/null
  fi
else
  log_warning "$kernel_folder not found, skipping KernelSU setup"
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
  log_success "Updated $pkg_file"
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
      log_success "Fixed vendor paths in $android_bp_file"
    else
      echo "ℹ️  No vendor/lineage references found."
    fi
  fi
else
  log_warning "$android_bp_file not found, skipping fix"
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
      if curl -LSs -o "$matrix_file" "$matrix_url"; then
        log_success "Downloaded $matrix_file"
      else
        log_error "Failed to download $matrix_file"
      fi
    else
      log_success "$matrix_file already exists, skipping download"
    fi
    cd - >/dev/null
  fi
else
  log_warning "$config_dir not found, skipping matrix update"
fi

# ==============================================================
# 📊 SUMMARY REPORT
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "📊 EXECUTION SUMMARY"
echo "════════════════════════════════════════════════"
echo ""

if [ ${#SUCCESS[@]} -gt 0 ]; then
  echo "✅ SUCCESSFUL OPERATIONS (${#SUCCESS[@]}):"
  for item in "${SUCCESS[@]}"; do
    echo "   • $item"
  done
  echo ""
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "⚠️  WARNINGS (${#WARNINGS[@]}):"
  for item in "${WARNINGS[@]}"; do
    echo "   • $item"
  done
  echo ""
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "❌ ERRORS (${#ERRORS[@]}):"
  for item in "${ERRORS[@]}"; do
    echo "   • $item"
  done
  echo ""
  echo "════════════════════════════════════════════════"
  echo "⚠️  Script completed with errors!"
  echo "════════════════════════════════════════════════"
  exit 1
else
  echo "════════════════════════════════════════════════"
  echo "✅ Script completed successfully!"
  echo "📱 ROM Name: $ROM_NAME"
  echo "🧪 Dry Run: $DRY_RUN"
  echo "════════════════════════════════════════════════"
  exit 0
fi

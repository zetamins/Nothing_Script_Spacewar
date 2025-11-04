#!/bin/bash
# ==============================================================
# 🚀 ROM Setup Script – Enhanced Conflict Resolution
# ==============================================================

# 🧪 Dry run mode: set to 0 to execute, 1 to preview commands
DRY_RUN=0

# 🎯 ROM name parameter
ROM_NAME="${1:-lineage}"

# 📊 Error tracking
declare -a ERRORS=()
declare -a WARNINGS=()
declare -a SUCCESS=()
declare -a FAILED_CLONES=()
declare -a CONFLICT_FILES=()

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
echo "🚀 ROM Setup Script - Enhanced Version"
echo "📱 ROM Name: $ROM_NAME"
echo "🧪 Dry Run: $DRY_RUN"
echo "════════════════════════════════════════════════"
echo ""

# ==============================================================
# 1️⃣ CLONE REPOSITORIES (WITH ERROR TOLERANCE)
# ==============================================================

clones=(
  "git clone --filter=blob:none --no-checkout -b derp16 https://github.com/DaViDev985/device_nothing_Spacewar.git device/nothing/Spacewar"
  "git clone --filter=blob:none --no-checkout -b derp16 https://github.com/DaViDev985/kernel_nothing_sm7325.git kernel/nothing/sm7325"
  "git clone --filter=blob:none --no-checkout -b derp16 https://github.com/DaViDev985/vendor_nothing_Spacewar.git vendor/nothing/Spacewar"
  "git clone --filter=blob:none --no-checkout -b derp16 https://github.com/DaViDev985/android_hardware_nothing.git hardware/nothing"
  "git clone --filter=blob:none --no-checkout -b derp16 https://github.com/DaViDev985/proprietary_vendor_nothing_camera.git vendor/nothing/camera"
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

  # Clone repo with error tolerance
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would run: $cmd"
  else
    echo "Cloning: $cmd"
    if $cmd 2>&1; then
      log_success "Cloned $folder successfully (metadata)"
      
      # Now checkout the files
      cd "$folder" || { log_warning "Failed to enter $folder"; continue; }
      
      echo "Checking out files..."
      git config advice.detachedHead false
      
      # Try sparse checkout first
      if git sparse-checkout init --cone 2>/dev/null; then
        git sparse-checkout set --no-cone "/*" 2>/dev/null || true
      fi
      
      # Checkout files
      if git checkout 2>&1 | tee /tmp/git_checkout.log; then
        log_success "Files checked out for $folder"
      else
        if grep -q "error:" /tmp/git_checkout.log && ! grep -q "pathspec\|reference" /tmp/git_checkout.log; then
          log_warning "Some files missing in $folder, but continuing"
        else
          log_success "Checked out $folder (some files may be missing)"
        fi
      fi
      rm -f /tmp/git_checkout.log
      
      cd - >/dev/null
    else
      clone_error=$?
      log_warning "Failed to clone $folder (exit code: $clone_error)"
      FAILED_CLONES+=("$folder")
      echo "ℹ️  Continuing with remaining repositories..."
    fi
  fi
done

# Report failed clones
if [ ${#FAILED_CLONES[@]} -gt 0 ]; then
  echo ""
  echo "⚠️  Some repositories failed to clone:"
  for repo in "${FAILED_CLONES[@]}"; do
    echo "   • $repo"
  done
  echo "ℹ️  Script will continue with available repositories"
  echo ""
fi

# ==============================================================
# 🛠️ ENHANCED CONFLICT RESOLUTION FUNCTION
# ==============================================================

resolve_conflict_smart() {
  local file=$1
  local strategy=${2:-theirs}  # Default: keep incoming changes
  
  echo "   🔍 Analyzing conflict in: $(basename "$file")"
  
  # Count conflict markers
  local conflict_count=$(grep -c "^<<<<<<<" "$file" 2>/dev/null || echo 0)
  echo "   📊 Found $conflict_count conflict(s)"
  
  # Create backup
  cp "$file" "${file}.conflict_backup"
  
  case $strategy in
    ours)
      # Keep our changes (HEAD)
      # Use awk for more reliable parsing
      awk '
        /^<<<<<<< HEAD$/ { in_ours=1; next }
        /^=======$/      { in_ours=0; in_theirs=1; next }
        /^>>>>>>>/       { in_theirs=0; next }
        in_ours          { print }
      ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
      echo "   ✅ Resolved: kept HEAD (ours)"
      ;;
      
    theirs)
      # Keep incoming changes (theirs)
      # Use awk for more reliable parsing
      awk '
        /^<<<<<<< HEAD$/ { in_ours=1; next }
        /^=======$/      { in_ours=0; in_theirs=1; next }
        /^>>>>>>>/       { in_theirs=0; next }
        !in_ours && in_theirs { print }
        !in_ours && !in_theirs { print }
      ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
      echo "   ✅ Resolved: kept incoming (theirs)"
      ;;
      
    both)
      # Keep both sections, remove markers
      sed -i '/^<<<<<<</d; /^=======/d; /^>>>>>>>/d' "$file"
      echo "   ✅ Resolved: kept both sections"
      ;;
      
    manual)
      echo "   ⚠️  Manual resolution needed"
      return 1
      ;;
  esac
  
  # Verify file is valid after resolution
  if grep -q "^<<<<<<<\|^=======\|^>>>>>>>" "$file"; then
    echo "   ❌ Resolution incomplete, restoring backup"
    mv "${file}.conflict_backup" "$file"
    return 1
  else
    rm -f "${file}.conflict_backup"
    return 0
  fi
}

# ==============================================================
# 2️⃣ ENHANCED CHERRY-PICK FUNCTION
# ==============================================================

cherry_pick_commit() {
  local LOCAL_DIR=$1
  local REMOTE_NAME=$2
  local REMOTE_REPO=$3
  local COMMIT_SHA=$4
  local CONFLICT_STRATEGY=${5:-ours}  # Default: keep our version

  echo "──────────────────────────────────────────────"
  echo "Cherry-picking in $LOCAL_DIR"
  echo "Commit: $COMMIT_SHA"
  echo "Strategy: $CONFLICT_STRATEGY"
  echo "──────────────────────────────────────────────"

  if [ ! -d "$LOCAL_DIR" ]; then
    log_warning "Directory $LOCAL_DIR not found, skipping cherry-pick"
    return 1
  fi

  cd "$LOCAL_DIR" || { log_error "Failed to enter $LOCAL_DIR"; return 1; }

  # Set git to use true (no-op) as editor
  export GIT_EDITOR=true

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would add remote $REMOTE_NAME: $REMOTE_REPO"
    echo "Would fetch from $REMOTE_NAME"
    echo "Would cherry-pick commit $COMMIT_SHA"
    cd - >/dev/null
    return 0
  fi

  # Check for uncommitted changes and commit them first
  if ! git diff-index --quiet HEAD 2>/dev/null; then
    log_warning "Found uncommitted changes in $LOCAL_DIR, committing before cherry-pick..."
    git add -A
    git commit -m "Pre-cherry-pick: Save local changes" --allow-empty
    log_success "Committed local changes"
  fi

  # Add remote
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

  # Fetch
  echo "Fetching from $REMOTE_NAME..."
  if ! git fetch "$REMOTE_NAME" 2>&1 | grep -v "^From\|^$"; then
    log_error "Failed to fetch from $REMOTE_NAME in $LOCAL_DIR"
    cd - >/dev/null
    return 1
  fi

  # Cherry-pick
  echo "Cherry-picking commit $COMMIT_SHA..."
  if git cherry-pick --allow-empty "$COMMIT_SHA" 2>&1 | tee /tmp/cherry_pick.log; then
    # Check if it resulted in empty commit
    if grep -q "The previous cherry-pick is now empty" /tmp/cherry_pick.log; then
      log_success "Cherry-pick resulted in empty commit (changes already present): $COMMIT_SHA"
      git cherry-pick --skip 2>/dev/null
    else
      log_success "Cherry-pick successful: $COMMIT_SHA in $LOCAL_DIR"
    fi
    rm -f /tmp/cherry_pick.log
    cd - >/dev/null
    return 0
  fi

  # Handle conflicts
  echo ""
  echo "🔧 Detected conflicts, attempting automatic resolution..."
  
  CONFLICT_FILES_LIST=$(git diff --name-only --diff-filter=U 2>/dev/null)
  
  if [ -z "$CONFLICT_FILES_LIST" ]; then
    # No conflicts, but cherry-pick failed for another reason
    if grep -q "The previous cherry-pick is now empty" /tmp/cherry_pick.log; then
      log_success "Cherry-pick resulted in empty commit: $COMMIT_SHA"
      git cherry-pick --skip 2>/dev/null
      rm -f /tmp/cherry_pick.log
      cd - >/dev/null
      return 0
    else
      log_error "Cherry-pick failed (no conflicts detected): $COMMIT_SHA in $LOCAL_DIR"
      git cherry-pick --abort 2>/dev/null
      rm -f /tmp/cherry_pick.log
      cd - >/dev/null
      return 1
    fi
  fi

  # Process each conflicted file
  local all_resolved=true
  for file in $CONFLICT_FILES_LIST; do
    if resolve_conflict_smart "$file" "$CONFLICT_STRATEGY"; then
      git add "$file"
      CONFLICT_FILES+=("$LOCAL_DIR/$file (auto-resolved: $CONFLICT_STRATEGY)")
    else
      log_error "Failed to resolve conflict in $file"
      all_resolved=false
      CONFLICT_FILES+=("$LOCAL_DIR/$file (MANUAL NEEDED)")
    fi
  done

  if [ "$all_resolved" = true ]; then
    # Try to continue cherry-pick
    if git -c core.editor=true cherry-pick --continue 2>&1 | tee /tmp/cherry_continue.log; then
      log_success "Cherry-pick completed after conflict resolution: $COMMIT_SHA in $LOCAL_DIR"
      rm -f /tmp/cherry_pick.log /tmp/cherry_continue.log
      cd - >/dev/null
      return 0
    else
      # Check if it's an empty commit
      if grep -q "nothing to commit" /tmp/cherry_continue.log; then
        log_success "Cherry-pick completed (no changes): $COMMIT_SHA in $LOCAL_DIR"
        git cherry-pick --skip 2>/dev/null
        rm -f /tmp/cherry_pick.log /tmp/cherry_continue.log
        cd - >/dev/null
        return 0
      else
        log_error "Failed to continue cherry-pick: $COMMIT_SHA in $LOCAL_DIR"
        git cherry-pick --abort 2>/dev/null
        rm -f /tmp/cherry_pick.log /tmp/cherry_continue.log
        cd - >/dev/null
        return 1
      fi
    fi
  else
    log_error "Some conflicts require manual resolution in $LOCAL_DIR"
    git cherry-pick --abort 2>/dev/null
    rm -f /tmp/cherry_pick.log
    cd - >/dev/null
    return 1
  fi
}

# ==============================================================
# 2️⃣ PERFORM CHERRY-PICKS
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "🍒 Cherry-picking upstream commits"
echo "════════════════════════════════════════════════"
echo ""

# Cherry-pick with conflict resolution strategy
# Strategies: ours (keep HEAD), theirs (keep incoming), both (merge both)
# Default: theirs - keeps incoming cherry-pick changes

cherry_pick_commit "vendor/nothing/Spacewar" "muppets" \
  "https://github.com/TheMuppets/proprietary_vendor_nothing_Spacewar.git" \
  "b69b9f09c77bb53f43666e6cadde57ab601c15a4" "theirs"

cherry_pick_commit "device/nothing/Spacewar" "lineage" \
  "https://github.com/LineageOS/android_device_nothing_Spacewar.git" \
  "aae038e48a7cfe60805d37663555258c50e38f55" "theirs"

cherry_pick_commit "vendor/nothing/Spacewar" "davidev" \
  "https://github.com/DaViDev985/vendor_nothing_Spacewar.git" \
  "af074591e9a880b9869b9aba49d2af658cb2dcf8" "theirs"

# ==============================================================
# 2.5️⃣ COPY RADIO FOLDER FROM MUPPETS
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "📻 Copying radio folder from TheMuppets"
echo "════════════════════════════════════════════════"
echo ""

TEMP_MUPPETS="/tmp/muppets_spacewar_temp"
TARGET_VENDOR="vendor/nothing/Spacewar"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Would clone TheMuppets repo to $TEMP_MUPPETS"
  echo "Would copy radio folder to $TARGET_VENDOR"
else
  # Clean temp directory
  if [ -d "$TEMP_MUPPETS" ]; then
    echo "Cleaning existing temp directory..."
    rm -rf "$TEMP_MUPPETS"
  fi

  # Clone TheMuppets repository
  echo "Cloning TheMuppets repository to temp folder..."
  if git clone --depth=1 https://github.com/TheMuppets/proprietary_vendor_nothing_Spacewar "$TEMP_MUPPETS" 2>&1; then
    log_success "Cloned TheMuppets repository"
    
    if [ -d "$TEMP_MUPPETS/radio" ]; then
      if [ -d "$TARGET_VENDOR" ]; then
        # Commit any changes before copying radio folder
        cd "$TARGET_VENDOR" || exit
        if ! git diff-index --quiet HEAD 2>/dev/null; then
          git add -A
          git commit -m "Pre-radio-copy: Save changes" --allow-empty
          log_success "Committed changes before radio copy"
        fi
        cd - >/dev/null
        
        # Remove existing radio folder
        if [ -d "$TARGET_VENDOR/radio" ]; then
          echo "Removing existing radio folder..."
          rm -rf "$TARGET_VENDOR/radio"
          log_success "Removed old radio folder"
        fi
        
        # Copy radio folder
        echo "Copying radio folder to $TARGET_VENDOR..."
        if cp -r "$TEMP_MUPPETS/radio" "$TARGET_VENDOR/"; then
          log_success "Radio folder copied successfully"
        else
          log_error "Failed to copy radio folder"
        fi
      else
        log_warning "Target directory $TARGET_VENDOR not found, skipping radio copy"
      fi
    else
      log_warning "Radio folder not found in TheMuppets repository"
    fi
    
    # Clean up
    echo "Cleaning up temp directory..."
    rm -rf "$TEMP_MUPPETS"
    log_success "Temp directory cleaned"
  else
    log_warning "Failed to clone TheMuppets repository, skipping radio folder copy"
  fi
fi

# ==============================================================
# 3️⃣ RENAME FILES AND REPLACE STRINGS
# ==============================================================

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

if [ ${#FAILED_CLONES[@]} -gt 0 ]; then
  echo "⚠️  FAILED CLONES (${#FAILED_CLONES[@]}):"
  for item in "${FAILED_CLONES[@]}"; do
    echo "   • $item"
  done
  echo ""
fi

if [ ${#CONFLICT_FILES[@]} -gt 0 ]; then
  echo "🔧 CONFLICT RESOLUTIONS (${#CONFLICT_FILES[@]}):"
  for item in "${CONFLICT_FILES[@]}"; do
    echo "   • $item"
  done
  echo ""
fi

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
fi

# Final status
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "════════════════════════════════════════════════"
  echo "⚠️  Script completed with errors!"
  echo "📱 ROM Name: $ROM_NAME"
  echo "🧪 Dry Run: $DRY_RUN"
  echo "════════════════════════════════════════════════"
  exit 1
elif [ ${#FAILED_CLONES[@]} -gt 0 ] || [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "════════════════════════════════════════════════"
  echo "✅ Script completed with warnings!"
  echo "📱 ROM Name: $ROM_NAME"
  echo "🧪 Dry Run: $DRY_RUN"
  echo "════════════════════════════════════════════════"
  exit 0
else
  echo "════════════════════════════════════════════════"
  echo "✅ Script completed successfully!"
  echo "📱 ROM Name: $ROM_NAME"
  echo "🧪 Dry Run: $DRY_RUN"
  echo "════════════════════════════════════════════════"
  exit 0
fi

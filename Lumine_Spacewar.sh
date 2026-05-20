#!/bin/bash
# ==============================================================
# 🚀 ROM Setup Script – Idempotent
# 🧩 Re-runnable: every step checks current state and skips if
#     already in the desired condition.
# ==============================================================
#
# Usage:  ./rom_setup.sh [rom_name] [source_dir]
#   rom_name    — flavor prefix replacement (default: statix)
#   source_dir  — top-level folder created in cwd to hold the AOSP tree
#                 (default: $rom_name)

# 🧪 Dry run mode: set to 0 to execute, 1 to preview commands
DRY_RUN=0

# 🎯 ROM name + AOSP source-tree folder name
ROM_NAME="${1:-lumine}"
SOURCE_DIR="${2:-$ROM_NAME}"

MANIFEST_URL="https://github.com/LumineDroid/platform_manifest"
MANIFEST_BRANCH="bellflower"

echo "════════════════════════════════════════════════"
echo "🚀 ROM Setup Script (idempotent)"
echo "📱 ROM Name:   $ROM_NAME"
echo "📂 Source dir: $SOURCE_DIR"
echo "🧪 Dry Run:    $DRY_RUN"
echo "════════════════════════════════════════════════"
echo ""

# ──────────────────────────────────────────────────────────────
# helper: returns 0 if a folder is already a healthy clone of
# $url on branch $branch, else returns 1
# ──────────────────────────────────────────────────────────────
is_clone_healthy() {
  local folder="$1" url="$2" branch="$3"
  [ -d "$folder/.git" ] || return 1
  local cur_url cur_branch
  cur_url=$(git -C "$folder" remote get-url origin 2>/dev/null)
  cur_branch=$(git -C "$folder" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [ "$cur_url" = "$url" ] && [ "$cur_branch" = "$branch" ]
}

# ==============================================================
# 0️⃣ TOOLCHAIN PREREQUISITES (repo, git-lfs)
# ==============================================================

if ! command -v repo >/dev/null 2>&1; then
  echo "⚠️  'repo' tool not found — installing..."
  if [ "$DRY_RUN" -eq 0 ]; then
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update && sudo apt-get install -y repo
    fi
    if ! command -v repo >/dev/null 2>&1; then
      mkdir -p ~/bin
      curl -LSs https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
      chmod +x ~/bin/repo
      export PATH="$HOME/bin:$PATH"
    fi
  fi
else
  echo "✓ repo already installed ($(repo --version 2>&1 | head -1))"
fi

if ! command -v git-lfs >/dev/null 2>&1; then
  echo "⚠️  git-lfs not installed — installing (needs sudo)..."
  if [ "$DRY_RUN" -eq 0 ]; then
    sudo apt-get update && sudo apt-get install -y git-lfs
    git lfs install
  fi
else
  echo "✓ git-lfs already installed ($(git-lfs version | head -1))"
  git lfs install --skip-repo 2>/dev/null
fi

# Some hosting providers ship a repo-tool fork that aborts unless an
# http.cookiefile is configured (even for public manifests). Satisfy the
# check with an empty file — no real auth credentials needed.
if [ -z "$(git config --global --get http.cookiefile)" ]; then
  echo "ℹ️  configuring empty http.cookiefile to satisfy repo-tool fork checks"
  touch "$HOME/.gitcookies"
  chmod 600 "$HOME/.gitcookies"
  git config --global http.cookiefile "$HOME/.gitcookies"
else
  echo "✓ http.cookiefile already set: $(git config --global --get http.cookiefile)"
fi

# ==============================================================
# 1️⃣ CREATE SOURCE FOLDER, repo init + repo sync
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "📂 $SOURCE_DIR  ←  $MANIFEST_URL @ $MANIFEST_BRANCH"
echo "════════════════════════════════════════════════"
echo ""

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Would: mkdir -p $SOURCE_DIR && cd $SOURCE_DIR"
  echo "Would: repo init -u $MANIFEST_URL -b $MANIFEST_BRANCH --git-lfs"
  echo "Would: repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j8"
else
  mkdir -p "$SOURCE_DIR" || { echo "❌ Could not create $SOURCE_DIR"; exit 1; }
  cd "$SOURCE_DIR" || { echo "❌ Could not enter $SOURCE_DIR"; exit 1; }
  echo "Working directory: $(pwd)"

  # Skip repo init if already initialized to the same manifest+branch
  current_url=$(git -C .repo/manifests config --get remote.origin.url 2>/dev/null)
  current_branch=$(git -C .repo/manifests rev-parse --abbrev-ref HEAD 2>/dev/null | sed 's|^.*/||')
  if [ "$current_url" = "$MANIFEST_URL" ] && [ "$current_branch" = "$MANIFEST_BRANCH" ]; then
    echo "✓ repo already initialized to $MANIFEST_URL @ $MANIFEST_BRANCH — skipping init"
  else
    echo "── repo init ──"
    repo init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --git-lfs \
      || { echo "❌ repo init failed"; exit 1; }
  fi

  echo ""
  # Create local manifest to remove broken repos (dead URLs 404)
  mkdir -p .repo/local_manifests
  cat > .repo/local_manifests/remove_broken.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <!-- crDroid axion-sdk 404s — cloned from AxionAOSP below -->
  <remove-project name="crdroidandroid/android_axion-sdk" />
</manifest>
EOF

  echo ""
  echo "── repo sync (full) ──"
  repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j8 2>&1 || { echo "❌ repo sync failed"; exit 1; }
  echo "✅ Source synced."
fi

# ==============================================================
# 2️⃣ CLONE DEVICE / KERNEL / VENDOR REPOSITORIES
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "📥 Cloning device/kernel/vendor/hardware (zetamins)"
echo "════════════════════════════════════════════════"
echo ""

declare -A CLONES=(
  # Device tree: crDroid-based, lineage naming -> renamed below
  ["device/nothing/Spacewar"]="https://github.com/zetamins/android_device_nothing_Spacewar.git|master"
  # Kernel
  ["kernel/nothing/sm7325"]="https://github.com/zetamins/android_kernel_nothing_sm7325.git|master"
  # Vendor blobs
  ["vendor/nothing/Spacewar"]="https://github.com/zetamins/proprietary_vendor_nothing_Spacewar.git|master"
  # Camera HAL
  ["vendor/nothing/camera"]="https://github.com/zetamins/vendor_nothing_camera-Spacewar.git|16.0"
  # Hardware Nothing (dolby, GlyphAdapter, NGlyphs, NT-fwk, UDFPS all bundled)
  ["hardware/nothing"]="https://github.com/zetamins/android_hardware_nothing.git|16.0"
)

for folder in "${!CLONES[@]}"; do
  entry="${CLONES[$folder]}"
  url="${entry%%|*}"
  branch="${entry##*|}"

  echo "──────────────────────────────────────────────"
  echo "Repo: $folder  (branch: $branch)"

  if is_clone_healthy "$folder" "$url" "$branch"; then
    echo "✓ already cloned ($(git -C "$folder" log -1 --format='%h %s')) — skipping"
    continue
  fi

  if [ -d "$folder" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "Would delete $folder (existed but wrong origin/branch)"
    else
      echo "Folder exists but doesn't match — removing for re-clone..."
      rm -rf "$folder"
    fi
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would: git clone -b $branch $url $folder"
  else
    echo "Cloning $url ..."
    git clone -b "$branch" "$url" "$folder" \
      || { echo "❌ clone failed: $folder"; continue; }
    echo "✅ cloned $folder"
  fi
done

# ==============================================================
# 2b️⃣ FALLBACK CLONES for dead crDroid manifest repos
#      These are referenced in manifest snippets but the URLs
#      404 — clone working forks instead.
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "📥 Fallback clones (broken manifest repos)"
echo "════════════════════════════════════════════════"
echo ""

# axion-sdk (SystemUI / AxQuickLook dependency)
axion_dir="axion-sdk"
if [ -d "$axion_dir" ] && [ -f "$axion_dir/Android.bp" ]; then
  echo "✓ $axion_dir already cloned — skipping"
else
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would: git clone --depth=1 -b lineage-23.2 https://github.com/AxionAOSP/android_axion_sdk.git $axion_dir"
  else
    rm -rf "$axion_dir"
    echo "Cloning AxionAOSP/android_axion_sdk into $axion_dir ..."
    git clone --depth=1 -b lineage-23.2 https://github.com/AxionAOSP/android_axion_sdk.git "$axion_dir" \
      && echo "✅ cloned $axion_dir" \
      || echo "❌ clone failed: $axion_dir"
  fi
fi

# ant-wireless_hidl (vendor blobs dependency: com.dsi.ant@1.0)
# Manifest path is external/ant-wireless/hidl but the sync skips it
# (lineage remote not configured). Clone manually to the correct path.
ant_dir="external/ant-wireless/hidl"
if [ -d "$ant_dir" ] && [ -f "$ant_dir/interfaces/ant/1.0/Android.bp" ]; then
  echo "✓ $ant_dir already cloned — skipping"
else
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would: git clone --depth=1 https://github.com/LineageOS/android_external_ant-wireless_hidl.git $ant_dir"
  else
    rm -rf "$ant_dir" "external/ant-wireless_hidl"
    mkdir -p external/ant-wireless
    echo "Cloning LineageOS/android_external_ant-wireless_hidl into $ant_dir ..."
    git clone --depth=1 https://github.com/LineageOS/android_external_ant-wireless_hidl.git "$ant_dir" \
      && echo "✅ cloned $ant_dir" \
      || echo "❌ clone failed: $ant_dir"
  fi
fi

# ============================================================================
# Fix Vendor Files (idempotent — searches for the original pattern only)
# ============================================================================
echo ""
echo "════════════════════════════════════════════════"
echo "🔧 Fixing vendor-specific files"
echo "════════════════════════════════════════════════"
echo ""

vendor_android_mk="vendor/nothing/Spacewar/Android.mk"
if [ -f "$vendor_android_mk" ]; then
  if grep -q "add-radio-file-sha1-checked" "$vendor_android_mk"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "Would fix radio file SHA1 checks in $vendor_android_mk"
    else
      sed -i 's/add-radio-file-sha1-checked,\(radio\/[^,]*\),[^)>]*/add-radio-file,\1/g' "$vendor_android_mk" \
        && echo "✅ Fixed radio file SHA1 checks" \
        || echo "❌ sed failed on $vendor_android_mk"
    fi
  else
    echo "✓ no add-radio-file-sha1-checked references — skipping"
  fi
else
  echo "⚠️  $vendor_android_mk not found, skipping radio file fix"
fi

# ==============================================================
# 4️⃣ FIX PACKAGE ALLOWED LIST (already idempotent via grep -qxF)
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
  added=0
  if ! grep -qxF "com\\.nothing" "$pkg_file"; then
    echo "com\\.nothing" >> "$pkg_file"; added=1
  fi
  if ! grep -qxF "com\\.nothing\\..*" "$pkg_file"; then
    echo "com\\.nothing\\..*" >> "$pkg_file"; added=1
  fi
  if [ $added -eq 1 ]; then
    echo "✅ Added com.nothing entries to $pkg_file"
  else
    echo "✓ com.nothing entries already present — skipping"
  fi
fi

# ==============================================================
# 5️⃣ FIX ANDROID.BP REFERENCES (already idempotent via grep)
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "🔧 Fixing Android.bp references"
echo "════════════════════════════════════════════════"
echo ""

android_bp_file="hardware/interfaces/compatibility_matrices/Android.bp"
if [ -f "$android_bp_file" ]; then
  if grep -q "vendor/lineage" "$android_bp_file"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "Would replace 'vendor/lineage' with 'vendor/$ROM_NAME' in $android_bp_file"
    else
      sed -i "s|vendor/lineage|vendor/$ROM_NAME|g" "$android_bp_file"
      echo "✅ Fixed vendor paths in $android_bp_file"
    fi
  else
    echo "✓ no vendor/lineage references — skipping"
  fi
else
  echo "⚠️  $android_bp_file not found, skipping fix."
fi

# ==============================================================
# 6️⃣ PATCH device.mk: handle Lineage→Statix package mapping
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "🔧 Patching device.mk for StatixOS compatibility"
echo "════════════════════════════════════════════════"
echo ""

dev_mk="device/nothing/Spacewar/device.mk"
if [ -f "$dev_mk" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would patch Lineage-specific references in $dev_mk"
  else

    echo "Checking for Lineage-specific references in device.mk..."

    # Check if hardware/lineage exists in the synced source
    lineage_hw_exists=false
    if [ -d "hardware/lineage/interfaces" ]; then
      lineage_hw_exists=true
      echo "✓ hardware/lineage/interfaces found — references will be preserved"
    fi

    # List of all Lineage-specific references in device.mk that need handling
    # when hardware/lineage doesn't exist in the ROM source.

    # ── PRODUCT_SOONG_NAMESPACES: remove hardware/lineage/interfaces/power-libperfmgr ──
    if ! $lineage_hw_exists && grep -q "hardware/lineage/interfaces" "$dev_mk"; then
      echo "ℹ️  Removing hardware/lineage/interfaces from PRODUCT_SOONG_NAMESPACES..."
      # Remove the line referencing hardware/lineage/interfaces
      sed -i '/hardware\/lineage\/interfaces/d' "$dev_mk"
    fi

    # ── PRODUCT_PACKAGES: wrap Lineage-only packages behind existence checks ──
    # We wrap each with a conditional so the build can still succeed if the
    # package source exists in vendor/statix or similar.
    if ! $lineage_hw_exists; then
      changes=0

      # android.hardware.light-service.lineage
      if grep -q "android.hardware.light-service.lineage" "$dev_mk" 2>/dev/null; then
        sed -i 's|^\(    android\.hardware\.light-service\.lineage\).*$|#\1 (Lineage-only, not in Statix)|' "$dev_mk"
        changes=$((changes + 1))
      fi

      # android.hardware.power-service.lineage-libperfmgr
      if grep -q "android.hardware.power-service.lineage-libperfmgr" "$dev_mk" 2>/dev/null; then
        sed -i 's|^\(    android\.hardware\.power-service\.lineage-libperfmgr\).*$|#\1 (Lineage-only, not in Statix)|' "$dev_mk"
        changes=$((changes + 1))
      fi

      # vendor.lineage.health-service.default
      if grep -q "vendor.lineage.health-service.default" "$dev_mk" 2>/dev/null; then
        sed -i 's|^\(    vendor\.lineage\.health-service\.default\).*$|#\1 (Lineage-only, not in Statix)|' "$dev_mk"
        changes=$((changes + 1))
      fi

      # vendor.lineage.powershare-service.default
      if grep -q "vendor.lineage.powershare-service.default" "$dev_mk" 2>/dev/null; then
        sed -i 's|^\(    vendor\.lineage\.powershare-service\.default\).*$|#\1 (Lineage-only, not in Statix)|' "$dev_mk"
        changes=$((changes + 1))
      fi

      # $(call soong_config_set,lineage_health,...)
      if grep -q "soong_config_set,lineage_health" "$dev_mk" 2>/dev/null; then
        sed -i 's|^\($(call soong_config_set,lineage_health\)|#\1|' "$dev_mk"
        changes=$((changes + 1))
      fi

      # $(call soong_config_set,lineage_powershare,...)
      if grep -q "soong_config_set,lineage_powershare" "$dev_mk" 2>/dev/null; then
        sed -i 's|^\($(call soong_config_set,lineage_powershare\)|#\1|' "$dev_mk"
        changes=$((changes + 1))
      fi

      if [ $changes -gt 0 ]; then
        echo "✅ Disabled $changes Lineage-specific reference(s) in device.mk"
      else
        echo "✓ No Lineage-specific references found in device.mk"
      fi
    fi

    echo "✅ Lineage-specific references handled in device.mk"
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would fix soong_config_set_bool -> soong_config_set for camera/override_format_from_reserved"
  else
    # Fix soong_config_set_bool to soong_config_set for camera
    # (Android 16 select() type mismatch with camera HAL .bp string keys)
    if grep -q "^.*soong_config_set_bool,camera,override_format_from_reserved" "$dev_mk" 2>/dev/null; then
      sed -i 's/soong_config_set_bool,camera,override_format_from_reserved,true/soong_config_set,camera,override_format_from_reserved,true/' "$dev_mk"
      echo "✅ Fixed camera/override_format_from_reserved (soong_config_set_bool -> soong_config_set)"
    fi
  fi

  echo "✅ device.mk patching complete"
else
  echo "⚠️  $dev_mk not found, skipping device.mk patches"
fi

# ==============================================================
# 7️⃣ UPDATE DEVICE FRAMEWORK MATRIX (already idempotent via file check)
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
  if [ -f "$config_dir/$matrix_file" ]; then
    echo "✓ $config_dir/$matrix_file already exists — skipping"
  elif [ "$DRY_RUN" -eq 1 ]; then
    echo "Would download $matrix_file to $config_dir/"
  else
    curl -LSs -o "$config_dir/$matrix_file" "$matrix_url" \
      && echo "✅ Downloaded $matrix_file" \
      || echo "❌ Failed to download $matrix_file"
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
echo "📱 ROM Name:   $ROM_NAME"
echo "📂 Source dir: $SOURCE_DIR ($(pwd))"
echo "🧪 Dry Run:    $DRY_RUN"
echo "════════════════════════════════════════════════"

#!/bin/bash
# ==============================================================
# 🚀 ROM Setup Script – Samsung A04e (Ceres / MT6768)
# ==============================================================

DRY_RUN=0
ROM_NAME="${1:-euclid}"
DEVICE="a04e"

echo "════════════════════════════════════════════════"
echo "🚀 ROM Setup Script"
echo "📱 Device: Samsung A04e"
echo "📦 ROM Name: $ROM_NAME"
echo "🧪 Dry Run: $DRY_RUN"
echo "════════════════════════════════════════════════"
echo ""

# ==============================================================
# 1️⃣ CLONE REPOSITORIES
# ==============================================================

clones=(
  "git clone https://github.com/zetamins/android_device_samsung_a04e.git device/samsung/a04e"
  "git clone https://github.com/zetamins/android_device_samsung_mt6768-jdm.git device/samsung/mt6768-jdm"
  "git clone https://github.com/zetamins/android_kernel_samsung_huaqin.git kernel/samsung/huaqin"
  "git clone https://github.com/zetamins/android_vendor_samsung_ceres.git vendor/samsung/ceres"
  "git clone https://github.com/zetamins/vendor_samsung_hq-camera.git vendor/samsung/hq-camera"
)

for cmd in "${clones[@]}"; do
  folder=$(echo "$cmd" | awk '{print $NF}')

  echo "──────────────────────────────────────────────"
  echo "Processing repository: $folder"
  echo "──────────────────────────────────────────────"

  if [ -d "$folder" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "Would delete folder: $folder"
    else
      rm -rf "$folder"
      echo "Deleted $folder"
    fi
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "Would run: $cmd"
  else
    $cmd
    echo "Cloned $folder"
  fi
done

# ==============================================================
# 2️⃣ RENAME FILES AND REPLACE STRINGS
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "🔄 Renaming files and replacing strings"
echo "════════════════════════════════════════════════"
echo ""

directories=(
  "device/samsung/a04e"
  "device/samsung/mt6768-jdm"
  "kernel/samsung/huaqin"
  "vendor/samsung/ceres"
  "vendor/samsung/hq-camera"
)

for folder in "${directories[@]}"; do
  [ ! -d "$folder" ] && continue

  echo "Processing $folder"

  if [ "$DRY_RUN" -eq 0 ]; then

    grep -rl "lineage_a04e" "$folder" 2>/dev/null | xargs -r sed -i "s/lineage_a04e/${ROM_NAME}_a04e/g"
    grep -rl "aosp_a04e" "$folder" 2>/dev/null | xargs -r sed -i "s/aosp_a04e/${ROM_NAME}_a04e/g"
    grep -rl "ceres" "$folder" 2>/dev/null | xargs -r sed -i "s/lineage_ceres/${ROM_NAME}_ceres/g"

  fi

  # Rename files/folders
  if [ "$DRY_RUN" -eq 0 ]; then
    for prefix in lineage aosp; do
      find "$folder" -depth -name "*${prefix}_a04e*" -exec bash -c '
        f="$1"
        rom="'"$ROM_NAME"'"
        prefix="'"$prefix"'"
        new="$(dirname "$f")/$(basename "$f" | sed "s/${prefix}_a04e/${rom}_a04e/g")"
        [ "$f" != "$new" ] && mv "$f" "$new"
      ' _ {} \;
    done
  fi

done

# ==============================================================
# 3️⃣ KERNELSU SETUP
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "🔧 Setting up KernelSU"
echo "════════════════════════════════════════════════"

kernel_folder="kernel/samsung/huaqin"

if [ -d "$kernel_folder" ]; then
  if [ "$DRY_RUN" -eq 0 ]; then
    cd "$kernel_folder" || exit
    rm -rf KernelSU-Next
    curl -LSs https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh | bash -s v0.9.5
    cd - >/dev/null
    echo "✅ KernelSU installed"
  fi
fi

# ==============================================================
# 4️⃣ FIX PACKAGE ALLOWED LIST
# ==============================================================

pkg_file="build/soong/scripts/check_boot_jars/package_allowed_list.txt"

if [ "$DRY_RUN" -eq 0 ]; then
  mkdir -p "$(dirname "$pkg_file")"
  touch "$pkg_file"

  grep -qxF "com\\.samsung" "$pkg_file" || echo "com\\.samsung" >> "$pkg_file"
  grep -qxF "com\\.samsung\\..*" "$pkg_file" || echo "com\\.samsung\\..*" >> "$pkg_file"

  echo "✅ Updated package allowed list"
fi

# ==============================================================
# 5️⃣ FIX ANDROID.BP REFERENCES
# ==============================================================

android_bp_file="hardware/interfaces/compatibility_matrices/Android.bp"

if [ -f "$android_bp_file" ] && [ "$DRY_RUN" -eq 0 ]; then
  sed -i "s|vendor/lineage|vendor/$ROM_NAME|g" "$android_bp_file"
  echo "✅ Fixed Android.bp vendor references"
fi

# ==============================================================
# 6️⃣ OPTIONAL DEVICE MATRIX (If Needed)
# ==============================================================

config_dir="vendor/${ROM_NAME}/config"

if [ -d "$config_dir" ] && [ "$DRY_RUN" -eq 0 ]; then
  echo "Config directory exists. Add custom matrix here if required."
fi

# ==============================================================
# ✅ COMPLETION
# ==============================================================

echo ""
echo "════════════════════════════════════════════════"
echo "✅ Script Completed"
echo "📱 Device: Samsung A04e"
echo "📦 ROM Name: $ROM_NAME"
echo "════════════════════════════════════════════════"

#!/system/bin/sh

MODPATH="${0%/*}"
MODNAME="${MODPATH##*/}"
if command -v magisk >/dev/null 2>&1; then
  MAGISKTMP="$(magisk --path)"
else
  MAGISKTMP=/data/adb/ksu/bin
fi
KSU_VER_CODE=$(ksud kernel version 2>/dev/null | grep -o '[0-9]\+' | tail -1)

# Using util_functions.sh
[ -f "$MODPATH/util_functions.sh" ] && . "$MODPATH/util_functions.sh" || abort "! util_functions.sh not found!"

# Early property cleanup stage.
#
# Performs ROM fingerprint normalization and
# property sanitization before late-boot service.sh
# adjustments and profile replay.
for prop in $(getprop | grep -E "lineage|aosp_|eng.|dev-keys|test-keys|userdebug" | cut -d ":" -f 1 | tr -d '[]'); do
    replace_value_resetprop "$prop" "lineageos." ""
    replace_value_resetprop "$prop" "lineage_" ""
    replace_value_resetprop "$prop" "aosp_" ""
    replace_value_resetprop "$prop" "eng." ""
    replace_value_resetprop "$prop" "dev-keys" "release-keys"
    replace_value_resetprop "$prop" "test-keys" "release-keys"
    replace_value_resetprop "$prop" "userdebug" "user"
done

# Process prefixes (optimized to avoid redundant checks)
for prefix in system vendor system_ext product oem odm vendor_dlkm odm_dlkm bootimage; do
    # Check and reset properties only once per prefix
    check_resetprop "ro.${prefix}.build.tags" release-keys
    check_resetprop "ro.${prefix}.build.type" user

    # Replace values in all relevant properties
    for prop in ro.${prefix}.build.description ro.${prefix}.build.fingerprint ro.product.${prefix}.name; do
        replace_value_resetprop "$prop" "aosp_" ""
    done
done


# Early profile replay.
#
# Ensures profile-defined properties are available
# as early as possible during boot.
#
# service.sh will replay them again later to handle
# late-loading properties and vendor overrides.
apply_custom_props
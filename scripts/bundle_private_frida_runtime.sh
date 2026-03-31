#!/bin/zsh

set -euo pipefail

if [[ -z "${TARGET_BUILD_DIR:-}" || -z "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]]; then
  echo "error: Xcode build environment variables are missing." 1>&2
  exit 1
fi

PYTHON_BIN="${CHATGPT_DARK_PRIVATE_PYTHON:-$(/usr/bin/python3 - <<'PY'
import sys
print(sys.executable)
PY
)}"

if [[ ! -x "$PYTHON_BIN" ]]; then
  echo "error: Unable to locate a Python runtime to bundle." 1>&2
  exit 1
fi

PYTHON_PREFIX="$("$PYTHON_BIN" - <<'PY'
import sys
print(sys.prefix)
PY
)"

USER_SITE="$("$PYTHON_BIN" - <<'PY'
import site
print(site.USER_SITE)
PY
)"

MISSING_MODULES="$("$PYTHON_BIN" - <<'PY'
import importlib.util

required = ["frida", "frida_tools"]
missing = [name for name in required if importlib.util.find_spec(name) is None]
print(",".join(missing))
PY
)"

if [[ -n "$MISSING_MODULES" ]]; then
  echo "error: Missing Python packages required for the bundled Frida runtime: $MISSING_MODULES" 1>&2
  echo "error: Install them for $PYTHON_BIN before building." 1>&2
  exit 1
fi

if [[ ! -d "$PYTHON_PREFIX" ]]; then
  echo "error: Python prefix does not exist: $PYTHON_PREFIX" 1>&2
  exit 1
fi

if [[ ! -d "$USER_SITE" ]]; then
  echo "error: Python user site-packages does not exist: $USER_SITE" 1>&2
  exit 1
fi

BUNDLE_ROOT="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/PrivatePython"
RUNTIME_ROOT="$BUNDLE_ROOT/runtime"
SITE_PACKAGES_ROOT="$BUNDLE_ROOT/site-packages"

/bin/rm -rf "$BUNDLE_ROOT"
/bin/mkdir -p "$RUNTIME_ROOT" "$SITE_PACKAGES_ROOT"

/usr/bin/rsync -a --delete "$PYTHON_PREFIX/" "$RUNTIME_ROOT/"
/usr/bin/rsync -a --delete "$USER_SITE/" "$SITE_PACKAGES_ROOT/"

/usr/bin/find "$SITE_PACKAGES_ROOT" -name '__pycache__' -type d -prune -exec /bin/rm -rf {} +
/usr/bin/find "$SITE_PACKAGES_ROOT" -name '*.pyc' -type f -delete

SIGNING_IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:-}"

if [[ -n "$SIGNING_IDENTITY" && "$SIGNING_IDENTITY" != "-" ]]; then
  while IFS= read -r appBundle; do
    /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$appBundle"
  done < <(
    /usr/bin/find "$BUNDLE_ROOT" -type d -name '*.app' -print | /usr/bin/sort -r
  )

  while IFS= read -r filePath; do
    /usr/bin/codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$filePath"
  done < <(
    /usr/bin/find "$BUNDLE_ROOT" -type f -print0 | while IFS= read -r -d '' candidate; do
      if /usr/bin/file -b "$candidate" | /usr/bin/grep -q 'Mach-O'; then
        printf '%s\n' "$candidate"
      fi
    done
  )
fi

echo "Bundled private Frida runtime from $PYTHON_BIN"

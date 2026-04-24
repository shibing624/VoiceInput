#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="${ROOT_DIR}/Scripts"
DEFAULT_PYTHON="/Users/xuming/miniconda3/envs/py3.12/bin/python"
PYTHON_BIN="${PYTHON_BIN:-${DEFAULT_PYTHON}}"
APP_MODE="${APP_MODE:-alias}"
SETUP_SCRIPT="${SCRIPTS_DIR}/apple_speech_demo_setup.py"
DIST_APP="${SCRIPTS_DIR}/dist/Apple Speech Demo.app"

if [[ ! -x "${PYTHON_BIN}" ]]; then
  echo "Python not found: ${PYTHON_BIN}" >&2
  exit 1
fi

if [[ ! -f "${SETUP_SCRIPT}" ]]; then
  echo "Setup script not found: ${SETUP_SCRIPT}" >&2
  exit 1
fi

if ! "${PYTHON_BIN}" -m pip show py2app >/dev/null 2>&1; then
  echo "Installing py2app into ${PYTHON_BIN}..."
  "${PYTHON_BIN}" -m pip install py2app
fi

rm -rf "${SCRIPTS_DIR}/build" "${SCRIPTS_DIR}/dist"

pushd "${SCRIPTS_DIR}" >/dev/null
if [[ "${APP_MODE}" == "standalone" ]]; then
  "${PYTHON_BIN}" "${SETUP_SCRIPT}" py2app
else
  "${PYTHON_BIN}" "${SETUP_SCRIPT}" py2app -A
fi
popd >/dev/null

if [[ ! -d "${DIST_APP}" ]]; then
  echo "Build failed: ${DIST_APP} was not created." >&2
  exit 1
fi

echo ""
echo "Built app bundle:"
echo "  ${DIST_APP}"
echo ""
echo "Launch with:"
echo "  open \"${DIST_APP}\""
echo ""
echo "Notes:"
echo "  - APP_MODE=alias uses your current Python env and is best for local debugging."
echo "  - APP_MODE=standalone builds a self-contained app, but packaging is slower."

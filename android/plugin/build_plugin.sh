#!/usr/bin/env bash
# Builds the AcsUpdater AAR and copies it into the Godot addon.
# Needs: JDK 17 (JAVA_HOME), Android SDK (ANDROID_HOME), and the Godot Android build
# template installed in android/build (Project > Install Android Build Template).
set -euo pipefail
cd "$(dirname "$0")"
./gradlew --no-daemon :acsupdater:assembleRelease :acsupdater:assembleDebug
mkdir -p ../../addons/acs_updater/bin
cp acsupdater/build/outputs/aar/acsupdater-release.aar ../../addons/acs_updater/bin/acs_updater-release.aar
cp acsupdater/build/outputs/aar/acsupdater-debug.aar ../../addons/acs_updater/bin/acs_updater-debug.aar
echo "AARs copied to addons/acs_updater/bin/"

#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
mode="${1:---mac}"
case "$mode" in --mac|--xcode) ;; *) echo 'Usage: bash scripts/check-companion.sh [--mac|--xcode]' >&2; exit 2 ;; esac

swift run --package-path Apps/POMCompanion pom-companion-checks
swift build --package-path Apps/POMCompanion --product pom-companion-preview
if [[ "$mode" == --xcode ]]; then
    xcodebuild -checkFirstLaunchStatus
    command -v xcodegen >/dev/null || { echo 'Install XcodeGen: brew install xcodegen' >&2; exit 1; }
    xcodegen generate --spec Apps/POMCompanion/project.yml
    for destination in 'generic/platform=macOS' 'generic/platform=iOS Simulator'; do
        xcodebuild -quiet -project Apps/POMCompanion/POMCompanion.xcodeproj \
            -scheme POMCompanion -configuration Debug -destination "$destination" \
            -derivedDataPath "$root/.build/companion-xcode" CODE_SIGNING_ALLOWED=NO build
    done
    echo 'Unsigned Mac and iOS Simulator builds passed. Device, sandbox and App Review checks remain separate.'
fi

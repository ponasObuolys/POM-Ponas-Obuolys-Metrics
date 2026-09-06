#!/bin/bash
# Atvaizduoja tikrus programos vaizdus su izoliuotais patikros duomenimis.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
swift build
pom_build_dir="$(swift build --show-bin-path)"
sources=()
for source in Sources/POM/*.swift; do
  [ "$source" = Sources/POM/main.swift ] || sources+=("$source")
done
swiftc -parse-as-library -I "$pom_build_dir/Modules" \
  "$pom_build_dir"/POMCore.build/*.o "${sources[@]}" \
  "$pom_build_dir/POM.build/DerivedSources/resource_bundle_accessor.swift" \
  tests/POMViewTests/main.swift -o "$pom_build_dir/pom-view-tests"
"$pom_build_dir/pom-view-tests" "$root/.build/ui-checks"

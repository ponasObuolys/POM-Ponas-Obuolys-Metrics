#!/bin/bash
# Atvaizduoja tikrus programos vaizdus su izoliuotais patikros duomenimis.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
build_args=()
compiler_args=()
if [[ -n "${POM_BUILD_SDK:-}" ]]; then
  build_args+=(--sdk "$POM_BUILD_SDK")
  compiler_args+=(-sdk "$POM_BUILD_SDK")
fi
if [[ -n "${POM_BUILD_SYSTEM:-}" ]]; then build_args+=(--build-system "$POM_BUILD_SYSTEM"); fi
swift build ${build_args[@]+"${build_args[@]}"}
pom_build_dir="$(swift build ${build_args[@]+"${build_args[@]}"} --show-bin-path)"
sources=()
for source in Sources/POM/*.swift; do
  [ "$source" = Sources/POM/main.swift ] || sources+=("$source")
done
swiftc ${compiler_args[@]+"${compiler_args[@]}"} -parse-as-library -I "$pom_build_dir/Modules" -F "$pom_build_dir" -framework Sparkle \
  -Xlinker -rpath -Xlinker "$pom_build_dir" \
  "$pom_build_dir"/POMCore.build/*.o "$pom_build_dir"/POMUsageKit.build/*.o "${sources[@]}" \
  "$pom_build_dir/POM.build/DerivedSources/resource_bundle_accessor.swift" \
  tests/POMViewTests/main.swift -o "$pom_build_dir/pom-view-tests"
"$pom_build_dir/pom-view-tests" "$root/.build/ui-checks"

set shell := ["bash", "-euo", "pipefail", "-c"]

languages := "elixir gleam python ruby rust typescript"

default:
    just --list

preflight:
    ./scripts/package_lib_test.sh
    for dir in {{languages}}; do \
      if [ -d "$dir" ]; then \
        echo "==> $dir"; \
        (cd "$dir" && just preflight); \
      fi; \
    done
    just renderer-parent-smoke

package-postcheck:
    PACKAGE_POSTCHECK_BUILD=1 ./scripts/package_postcheck.sh

package-source-postcheck:
    PACKAGE_POSTCHECK_BUILD=1 ./scripts/package_postcheck.sh

package-lib-test:
    ./scripts/package_lib_test.sh

package-artifact-postcheck:
    PACKAGE_POSTCHECK_BUILD=1 PACKAGE_POSTCHECK_RUN_ARTIFACTS=1 ./scripts/package_postcheck.sh

package-release-check:
    PACKAGE_POSTCHECK_BUILD=1 PACKAGE_POSTCHECK_RUN_ARTIFACTS=1 PACKAGE_POSTCHECK_STRICT=1 ./scripts/package_postcheck.sh
    RUST_DIRECT_SMOKE_STRICT=1 rust/scripts/direct_smoke.sh

renderer-parent-smoke:
    ./scripts/renderer_parent_smoke.sh

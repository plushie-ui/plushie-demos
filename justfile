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

package-smoke:
    ./scripts/package_smoke.sh

package-lib-test:
    ./scripts/package_lib_test.sh

package-artifact-smoke:
    PACKAGE_SMOKE_BUILD=1 PACKAGE_SMOKE_RUN_ARTIFACTS=1 ./scripts/package_smoke.sh

renderer-parent-smoke:
    ./scripts/renderer_parent_smoke.sh

set shell := ["bash", "-euo", "pipefail", "-c"]

languages := "elixir gleam python ruby rust typescript"

default:
    just --list

preflight:
    for dir in {{languages}}; do \
      if [ -d "$dir" ]; then \
        echo "==> $dir"; \
        (cd "$dir" && just preflight); \
      fi; \
    done
    just renderer-parent-smoke

package-smoke:
    ./scripts/package_smoke.sh

renderer-parent-smoke:
    ./scripts/renderer_parent_smoke.sh

get_latest_version() {
    local repo="$1"

    if ! command -v jq >/dev/null 2>&1; then
        apt-get update > /dev/null 2>&1
        apt-get install -y jq > /dev/null 2>&1
    fi

    latest_stable=$(curl -s "https://api.github.com/repos/$repo/tags" | \
        jq -r '
        # Filter only objects with string "name" field that starts with "v"
        map(select(.name | type == "string" and startswith("v"))) |
        # Filter out pre-releases (rc, b, a, dev, etc.)
        map(select(.name | test("^[vV][0-9]+\\.[0-9]+\\.[0-9]+$"))) |
        # Extract version without "v" prefix
        map(.name[1:]) |
        # Sort by semantic version
        sort_by(
            split(".") |
            map(tonumber // 0)
        ) |
        last // empty
        ')

    if [[ -z "$latest_stable" ]]; then
        echo "Error: No stable version found for repository $repo" >&2
        return 1
    fi

    echo "$latest_stable"
}

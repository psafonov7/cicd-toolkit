get_checksum() {
    local file_name="$1"
    local checksums_url="$2"
    local temp_dir
    temp_dir="$(mktemp -d)"
    local checksums_file="${temp_dir}/checksums.txt"

    curl -fsSL "$checksums_url" -o $checksums_file
    checksum=$(awk -v f="$file_name" '$2 == f || $2 == "*"f { print $1 }' "$checksums_file")
    
    echo "$checksum"
}

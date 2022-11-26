#!/bin/bash
# Convert image to webp format!
# Install cwebp via `apt-get install -y webp`.

set -e
set -o pipefail

convert2webp() {
    for img in $1; do
        local src="${img}"
        local dst="public/${src#*/}"
        # Only convert to webp when webp image not exists or out-of-date.
        if [[ ! -e "${dst}.webp" ]] || [[ $(${GIT} log --format=%ct -1 "${src}") -gt $(stat --format=%Y "${dst}.webp") ]]; then
            echo "converting ${src} to ${dst}.webp"
            cwebp "${src}" -o "${dst}.webp"
        fi
        echo "image ${dst}.webp is up-to-date."
    done
}

images=$(find content -name '*.png' -o -name '*.jpg' -o -name '*.jpeg')
convert2webp "${images}"

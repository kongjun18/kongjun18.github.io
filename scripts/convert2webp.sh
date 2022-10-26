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
            if cwebp "${src}" -o "${dst}.webp"; then
                echo "converted ${src} to ${dst}.webp"
            else
                echo "error in convert ${src} to ${dst}.webp" > /dev/stderr
            fi
        fi
        echo "image ${dst}.webp is up-to-date."
    done
}

images=$(find content -name '*.png' -o -name '*.jpg' -o -name '*.jpeg')
convert2webp "${images}"

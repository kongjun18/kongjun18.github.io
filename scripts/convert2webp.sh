#!/bin/bash
# Convert image to webp format!
# Install cwebp via `apt-get install -y webp`.

convert2webp() {
    for img in $1; do
        local src="${img}"
        local dst="public/${src#*/}"
        cwebp "${src}" -o "${dst}.webp"
        echo -e "convert ${src} to ${dst}.webp\n"
    done
}

images=$(find content -name '*.png' -o -name '*.jpg' -o -name '*.jpeg')
convert2webp "${images}"

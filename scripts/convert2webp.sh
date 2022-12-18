#!/bin/bash
# Convert image to webp format!
# Install cwebp via `apt-get install -y webp`.

set -e
set -o pipefail

convert2webp() {
    for img in $1; do
        local src="${img}"
        local post
        # content/posts/<post>/images/<image>
        post="$(dirname "$(dirname "${img}")")"
        local post_md="${post}/index.md"
        # Check whether the image path is right
        if [[ -e "${post_md}" ]]; then
            local date
            # Convert date like 2021-04-28T15:16:23+08:00 to 2021/04/28
            date="$(head -n 10 "${post_md}" | grep 'date' - | cut -d ' ' -f 2 | cut -d 'T' -f 1 | sed 's/-/\//g')"
            # public/posts/<date>images/<image>
            local dst
            dst="public/posts/${date}/images/$(basename "${img}")"
            # Only convert to webp when webp image not exists or out-of-date.
            if [[ ! -e "${dst}.webp" ]] || [[ $(${GIT} log --format=%ct -1 "${src}") -gt $(stat --format=%Y "${dst}.webp") ]]; then
                echo "converting ${src} to ${dst}.webp"
                cwebp "${src}" -o "${dst}.webp"
            fi
            echo "image ${dst}.webp is up-to-date."
        fi
    done
}

images=$(find content -name '*.png' -o -name '*.jpg' -o -name '*.jpeg')
convert2webp "${images}"

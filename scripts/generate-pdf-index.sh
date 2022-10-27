#!/bin/bash
CATEGORIES=public/categories
ARCHIVES=content/archives
ARCHIVE_INDEX="${ARCHIVES}/index.md"

mkdir -p "${ARCHIVES}"
[[ -e "${ARCHIVE_INDEX}" ]] && rm "${ARCHIVE_INDEX}"

printf "您可以在这里下载所有文章的 PDF 版本\n\n" >> "${ARCHIVE_INDEX}"
for category in "${CATEGORIES}"/*; do
    if [[ ! -d "${category}" ]] || [ ! -e "${category}/index.html" ]; then
        continue
    fi
    printf "%s\n\n" "## ${category##*/}" >> "${ARCHIVE_INDEX}"
    lines="$(grep -nPo 'archive-item>.*href=(.*/)\s+.*archive-item-link>\s*(.*)\s*<' "${category}/index.html" | awk -F '=' '{print $2 $3;}')"
    IFS=$'\n'
    for line in ${lines}; do
        post_dir="$(echo "${line}" | cut -d ' ' -f 1)"
        post_dir="${post_dir%/}"
        post_dir="${post_dir##*/}"
        archived_pdf="${post_dir}.pdf"
        title="${line##*classarchive-item-link>}"
        title="${title%<}"
        printf "<a href=\"%s\">%s</a>\n\n" "${archived_pdf}" "${title}" >> "${ARCHIVE_INDEX}"
    done
    printf "\n" >> "${ARCHIVE_INDEX}"
done

#! /bin/bash

set -e
set -o pipefail

archive_dir="public/archives"
mkdir -p "${archive_dir}"
MARKDWN2PDF="$(realpath ./scripts/markdown2pdf)"

for post in public/posts/*; do
  if [[ -d "${post}" ]] && [[ -e "${post}/index.html" ]]; then
    index_md="content/${post#public/}/index.md"
    post_dir="${index_md%index.md}"
    date="$(head -n 10 "${index_md}" | grep date | cut -d ' ' -f 2)"
    date="$(date -d "${date}" +'%Y-%m-%d')"
    archived_pdf="${archive_dir}/${post##*/}.pdf"
    if [[ ! -e "${archived_pdf}" ]] || [[ $(${GIT} log --format=%ct -1 "${post_dir}") -gt $(stat --format=%Y "${archived_pdf}") ]]; then
      echo "converting ${index_md} to ${archived_pdf}"
      archived_pdf="$(realpath "${archived_pdf}")"
      (cd "${post_dir}" && ${MARKDWN2PDF} -i index.md -d "${date}" -o "${archived_pdf}")
    else
      echo "${archived_pdf} is up-to-date."
    fi
  fi
done

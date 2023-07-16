#! /bin/bash

set -e
set -o pipefail

archive_dir="content/archives"
mkdir -p "${archive_dir}"

MARKDWN2PDF="$(realpath ./scripts/markdown2pdf)"
GIT="${GIT:=git}"

for post in content/posts/*; do
  if [[ -d "${post}" ]] && [[ -e "${post}/index.md" ]]; then
    index_md="${post}/index.md"
    date="$(head -n 10 "${index_md}" | grep date | cut -d ' ' -f 2)"
    date="$(date -d "${date}" +'%Y-%m-%d')"
    archived_pdf="${archive_dir}/${post##*/}.pdf"
    post_git_date=$(${GIT} log --format=%ct -1 "${post}")
    post_stat_date=$(stat --format=%Y "${index_md}")
    pdf_stat_date=$(stat --format=%Y "${archived_pdf}")
    if [[ ! -e "${archived_pdf}" ]] || [[ "${post_git_date}" -gt "${pdf_stat_date}" ]] || [[ "${post_stat_date}" -gt "${pdf_stat_date}" ]]; then
      echo "converting ${index_md} to ${archived_pdf}"
      archived_pdf="$(realpath "${archived_pdf}")"
      (cd "${post}" && ${MARKDWN2PDF} -i index.md -d "${date}" -o "${archived_pdf}")
    else
      echo "${archived_pdf} is up-to-date."
    fi
  fi
done

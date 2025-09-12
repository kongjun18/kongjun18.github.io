#!/bin/bash

# 您Obsidian仓库的根目录路径
OBSIDIAN_VAULT_PATH="$HOME/Cloud/Obsidian"
OBSIDISN_NOTES_PATH="${OBSIDIAN_VAULT_PATH}/07-笔记"

# 您Hugo博客项目中存放文章的目录路径 (通常是 content/posts)
HUGO_CONTENT_PATH="$HOME/projects/blog/content/posts"

# 您的网站域名 (用于生成内部链接)
WEBSITE_URL="kongjun18.github.io"


# 确保目标目录存在
mkdir -p "$HUGO_CONTENT_PATH"

echo "Starting conversion..."
echo "Obsidian Vault: $OBSIDIAN_VAULT_PATH"
echo "Hugo Content Path: $HUGO_CONTENT_PATH"
echo "Processing notes tagged with #paper AND NOT #todo (using rg)."
echo "-------------------------------------------"

slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/ /-/g' | sed 's/,//g' | sed "s/'//g" | sed 's/"//g'
}

note_path_file=$(mktemp)
trap 'rm -f "$note_path_file"' EXIT

slug_file=$(mktemp)
trap 'rm -f "$slug_file"' EXIT

# 查找所有Markdown文件
find "$OBSIDISN_NOTES_PATH" -name "*.md" | while read -r note_path; do
    # 检查文件：必须包含 #paper 标签，且不能包含 #todo 标签
    if rg -q "#paper" "$note_path" && ! rg -q "#todo" "$note_path"; then
        echo "$note_path" >> "${note_path_file}"
        filename=$(basename "$note_path")
        title="${filename%.md}"
        slug=$(slugify "$title")
        echo "$slug" >> "${slug_file}"
    fi
done

cat "${note_path_file}" | while read -r note_path; do
        # --- A. 提取笔记信息 ---
        filename=$(basename "$note_path")
        title="${filename%.md}"

        echo "Processing note: $title"

        # --- B. 创建Hugo文章目录 ---
        slug=$(slugify "$title")
        hugo_post_dir="$HUGO_CONTENT_PATH/$slug"
        hugo_images_dir="$hugo_post_dir/images"

        if [ -d "$hugo_post_dir" ]; then
            hugo_file="${hugo_post_dir}/index.md"
            if [ -f "${hugo_file}" ]; then
                # 1. 获取Obsidian源文件的修改时间戳 (秒)
                obsidian_mtime=$(stat --format="%Y" "$note_path")

                # 2. 从Hugo文件中解析出date字段的字符串
                hugo_cdate=$(grep -m 1 '^date:' "$hugo_file" | sed 's/date: *//')
                hugo_mdate=${hugo_cdate:-$(grep -m 1 '^mdate:' "$hugo_file" | sed 's/mdate: *//')}

                if [ -n "$hugo_mdate" ]; then
                    # 3. 将Hugo的date字符串转换为时间戳 (秒)
                    hugo_mtime=$(date -d "$hugo_mdate" +%s)

                    # 4. 比较时间戳
                    if [ "$obsidian_mtime" -le "$hugo_mtime" ]; then
                        echo "Skipping (up-to-date): $title"
                        echo "-------------------------------------------"
                        continue
                    fi
                fi
            fi
        fi

        mkdir -p "$hugo_images_dir"
        echo "  -> Created Hugo directory: $slug"

        # --- C. 解析内容并处理链接 ---

        processed=/tmp/processed.md
        cp "$note_path" "${processed}"
        featured_image=""
        is_first_image=true

        # 处理图片链接: ![[image name.png]]
        image_links=$(rg -oP '\!\[\[.*?\]\]' ${processed})

        if [ -n "$image_links" ]; then
            echo "$image_links" | while read -r obsidian_link; do
                image_name=$(echo "$obsidian_link" | sed -e 's/!\[\[//g' -e 's/\]\]//g' -e 's/|.*//')
                processed_image_name=$(slugify "$image_name")
                image_path=$(find "$OBSIDIAN_VAULT_PATH" -name "$image_name" | head -n 1)

                if [ -f "$image_path" ]; then
                    cp "$image_path" "$hugo_images_dir/${processed_image_name}"
                    echo "  -> copied image $image_name to ${processed_image_name}"
                    sed -i "s/${image_name}/${processed_image_name}/g" ${processed}
                    # ![[image|500]] -> ![[image]]
                    sed -i 's/!\[\[\([^|]*\)|.*\]\]/!\[\[\1\]\]/g' ${processed}
                    sed -i 's/!\[\[\([^]]*\)\]\]/![](\.\/images\/\1)/g' ${processed}

                    if [ "$is_first_image" = true ]; then
                        featured_image="images/$(basename "$image_name")"
                        is_first_image=false
                    fi
                else
                    echo "  -> WARNING: Image not found for link: $image_name"
                fi
            done
        fi

        mapfile -t internal_links < <(cat "${processed}" | rg -oP '\[\[.*?\]\]' | rg -v '^\!')
        # 2. 遍历数组中的每一个链接
        for obsidian_link in "${internal_links[@]}"; do
            echo "  -> Processing internal link: $obsidian_link"

            # 3. 提取标题 (Title)
            #    - sed 's/\[\[//g; s/\]\]//g' 移除前后的方括号
            #    - cut -d'|' -f1 处理别名情况 [[Real Name|Alias]]，只取真实文件名
            linked_title=$(echo "$obsidian_link" | sed -e 's/\[\[//g' -e 's/\]\]//g' | cut -d'|' -f1)
            display_text=$(echo "$obsidian_link" | sed -e 's/\[\[//g' -e 's/\]\]//g' | cut -d'|' -f2)

            # 4. "Slugify" 标题，用于生成URL路径
            #    - tr '[:upper:]' '[:lower:]'  => 转为小写
            #    - sed 's/ /-/g'                => 空格转为横杠
            #    - sed 's/[^a-z0-9-]//g'       => 移除所有非字母、数字、横杠的特殊字符
            linked_slug=$(slugify "$linked_title")

            # 5. 安全地替换原文中的链接
            if rg "${linked_slug}" "${slug_file}"; then
                sed -i "s/\[\[${linked_title}]]/\[$linked_title](https:\/\/$WEBSITE_URL\/posts\/$linked_slug)/g" "${processed}"
                sed -i "s/\[\[${linked_title}|[[:space:]]*${display_text}]]/\[$display_text](https:\/\/$WEBSITE_URL\/posts\/$linked_slug)/g" "${processed}"
            else
                # 6. 如果 internal link 不是博客，转换成斜体
                sed -i "s/\[\[${linked_title}]]/\*${linked_title}\*/g" "${processed}"
                sed -i "s/\[\[${linked_title}|[[:space:]]*${display_text}]]/\*${display_text}\*/g" "${processed}"
            fi

        done

        # 清理笔记开头的 header #
        # ---
        # created: 2025-09-06
        # ---
        # Status: #paper
        if rg -q '^Status:.*' ${processed}; then
            sed -i -e '1,/^Status:.*/d' ${processed}
        fi

        # --- D. 生成Hugo Front Matter ---
        # --format="%Y" 获取最近修改时间的Unix时间戳
        # -d "@..."  告诉date命令输入是一个Unix时间戳
        # --iso-8601=seconds 直接输出ISO 8601格式
        timestamp=$(stat --format="%Y" "$note_path")
        mdate=$(date -d "@$timestamp" --iso-8601=seconds)
        cdate=${hugo_cdate:-$(date --iso-8601=seconds)}
        hugo_file="$hugo_post_dir/index.md"

        cat > "$hugo_file" << EOF
---
title: "$title"
date: $cdate
mdate: $mdate
comment: true
weight: 0
author:
  name: "Jun"
  link: "https://github.com/kongjun18"
  avatar: "/images/avatar.jpg"
license: "All rights reserved"

categories:
- Paper

hiddenFromHomePage: false
hiddenFromSearch: false

summary: ""
resources:
- name: featured-image
  src: images/featured-image.png
- name: featured-image-preview
  src: images/featured-image.png

toc:
  enable: true
math:
  enable: true
lightgallery: false
seo:
  images: []

repost:
  enable: true
  url: ""
---

EOF
    cat "${processed}" >> "$hugo_file"
    echo "  -> Generated Hugo post: $hugo_file"
    echo "-------------------------------------------"
done

echo "Conversion finished."

---
title: "{{ replace .TranslationBaseName "-" " " | title }}"
subtitle: ""
date: {{ .Date }}
draft: true
author:
  name: "{{ .Site.Params.author.name }}"
  link: "{{ .Site.Params.author.link }}"
  avatar: "/images/avatar.jpg"
description: ""
keywords: ""
comment: true
weight: 0

tags:
- draft
categories:
- draft

hiddenFromHomePage: false
hiddenFromSearch: false

summary: ""
resources:
- name: featured-image
  src: featured-image.png
- name: featured-image-preview
  src: featured-image.png

toc:
  enable: true
math:
  enable: false
lightgallery: false
seo:
  images: []

repost:
  enable: true
  url: ""
---

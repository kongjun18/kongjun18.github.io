---
title: "{{ replace .TranslationBaseName "-" " " | title }}"
subtitle: ""
date: {{ .Date }}
draft: true
author: "{{ .Site.Params.author.name }}"
authorLink: "{{ .Site.Params.author.link }}"
authorEmail: "{{ .Site.Params.author.email }}"
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
  src: featured-image.webp
- name: featured-image-preview
  src: featured-image.webp

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

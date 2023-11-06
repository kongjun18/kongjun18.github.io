---
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
draft: true
author:
  name: "{{ .Site.Params.author.name }}"
  link: "{{ .Site.Params.author.link }}"
  avatar: "/images/avatar.jpg"
---

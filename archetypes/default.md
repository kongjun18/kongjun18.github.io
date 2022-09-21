---
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
draft: true
author: "{{ .Site.Params.author.name }}"
authorLink: "{{ .Site.Params.author.link }}"
authorEmail: "{{ .Site.Params.author.email }}"
---

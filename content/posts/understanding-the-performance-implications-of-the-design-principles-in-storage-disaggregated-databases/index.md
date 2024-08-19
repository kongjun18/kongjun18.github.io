---
title: "【论文阅读】Understanding the Performance Implications of the Design Principles in Storage-Disaggregated Databases"
date: "2024-08-15"
keywords: ""
comment: true
weight: 0
author:
  name: "Jun"
  link: "https://github.com/kongjun18"
  avatar: "/images/avatar.jpg"
license: "All rights reserved"
tags:
- Database
- Storage System
- Distributed System

categories:
- Database
- Storage System
- Distributed System

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
  enable: false
lightgallery: false
seo:
  images: []

repost:
  enable: true
  url: ""
---

本论文从最基本的单体数据库出发，一步步推导出目前主流的架构设计，并详细对这些设计进行性能分析。

对于我这种新人而言，跟着作者的思路走，像是一场思想旅行，打开了一扇大门。


## Q&A

- [x] 论文针对哪种类型的数据库？

    storage-disaggregated OLTP database

- [x] 为什么 storage-disaggregated OLAP database 不使用 log-as-the-database 和 shared-storage 设计？

    OLAP 通常服务读密集型负载，这两个设计解决的是写密集型负载的痛点。

- [x] log-as-the-database 的原理和效果？

    计算节点只发送 xlog，存储节点通过重放 xlog 得到数据。降低了网络负担，并且利用了存储节点的 CPU。

- [x] shared-storage 架构解决了什么问题，同时带来了什么问题？

    解决了 shared-nothing 架构中扩缩容计算节点带来的数据迁移问题。但 shared-storage 架构下主从计算节点间，xlog 的同步存在时间差。这意味从计算节点可能想存储节点请求旧版本的数据，存储节点需要实现多版本机制。

- [x] 为什么需要 multi-version 机制？

    在 shared-storage 架构下，主计算节点需要给从计shared-storage 架构下主从计算节点间，xlog 的同步存在时间差。这意味从计算节点可能想存储节点请求旧版本的数据（此时从计算节点还没接收到最新的 xlog），存储节点需要实现多版本机制。

- [x] torn page write 的原理和解决？
    数据库 page 大小可能和文件系统 block 大小不同，例如数据库一个 page 大小为 8K，文件系统 block 大小为 4K。大小不一致意味着，一个数据库 page 写入需要多次 block 写入，这会导致 page 刷盘不是原子的。

    然而，数据库依赖 page 刷盘的原子性，数据库不得不使用一些额外措施实现 page 刷盘的原子性。

    [PostgreSQL wiki](https://wiki.postgresql.org/wiki/Full_page_writes) 介绍了 Full Page Write 方案。实现方式是在 checkpoint 后，将 page 完整的写入 WAL 中，之后直接修改 page，刷新时用普通的 WAL 策略。如果刷新 WAL 时崩溃，则 page 还未刷盘，因此 page 数据未损坏；如果刷新 WAL 后，刷新 page 时崩溃，直接从 WAL 恢复即可。

- [x] 为什么需要 SR/FR？

    向客户端请求对应版本的 page 时，必须等待 replay process 重放到该版本的 page，这个时间可能比较长。其中很多耗时不是等待重放和该版本的 page 直接相关的操作。通过重放和该请求相关的 xlog ，可以让请求提前完成。这个策略类似于生活中的加急处理，先做最紧急的事，其余的事暂时先放放，有时间再做。



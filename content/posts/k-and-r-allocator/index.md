---
title: "致敬经典：K&R allocator 内存分配器"
subtitle: ""
date: 2022-12-12T21:01:48+08:00
draft: false
author: "孔俊"
authorLink: "https://github.com/kongjun18"
authorEmail: "kongjun18@outlook.com"
description: ""
keywords: ""
comment: true
weight: 0

tags:
- Allocator
- C
categories:
- Allocator

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


k&R allocator 是[Brain Kernighan](https://en.wikipedia.org/wiki/Brian_Kernighan)和 [Dennis Ritchie](https://en.wikipedia.org/wiki/Dennis_Ritchie) 著名的 [*The C Programming Language*](https://en.wikipedia.org/wiki/The_C_Programming_Language) 中第 8.7 节中介绍的一个简单的 malloc 实现，因为该书称为 K&R C，这个 malloc 实现也被称为 K&C allocator。

K&R allocator 的实现非常简洁，被实现在 Linux 内核中用于嵌入式系统。见 [slob: introduce the SLOB allocator](https://lwn.net/Articles/157944/)，邮件摘要如下：
```
SLOB is a traditional K&R/UNIX allocator with a SLAB emulation layer,
similar to the original Linux kmalloc allocator that SLAB replaced.
It's signicantly smaller code and is more memory efficient. But like
all similar allocators, it scales poorly and suffers from
fragmentation more than SLAB, so it's only appropriate for small
systems.
```

文章中的代码是修改（C99）语法错误后的 K&C 代码，你可以在这里获取完整代码 [malloc.c](malloc.c)。

## 算法
K&R allocator 用空闲链表管理其持有的内存块，空闲链表是一个循环链表。每个内存块都关联一个头，头保存了其关联的内存块地址、内存块大小以及链表的下一个节点。
逻辑结构如下图：
![Figure 1: K&R allocator 的逻辑结构](images/logical-structure-of-k-and-r-allocator.excalidraw.svg)
在实现上，将上图的 header 和 block 合二为一，把内存块起始部分作为 header。物理结构如下：
![Figure 2: K&R allocator 的物理结构](images/physical-structure-of-k-and-r-allocator.excalidraw.svg)
通过`free()`插入位置的选择，K&R allocator 维护了内存块地址递增的空闲链表。

## 数据结构
header 定义如下：
```c
typedef long Align; /* for alignment to long boundary */
union header {      /* block header */
    struct {
        union header *ptr; /* next block if on free list */
        unsigned size;     /* size of this block */
    } s;
    Align x; /* force alignment of blocks */
};
typedef union header Header;
static Header base;          /* empty list to get started */
static Header *freep = NULL; /* start of free list */
```
header 专门定义为 union，利用成员`x`将 header 对齐到`Align`边界。这展示了 C 语言“以跨平台的方式编写依赖机器的代码”的能力。

## malloc
分配算法如下：
1. 遍历空闲链表，查找大小不小于目标大小的内存块。
2. 查找到，则
	1. 内存块大小恰好等于目标大小，从空闲链表摘除该内存块并返回。
	2. 内存块大小不等于目标大小，分隔该内存块并返回目标大小的内存。
3. 未查找到，则向 OS 申请不小于目标大小的内存，跳转到 1 重新搜索。
```c
/* malloc: general-purpose storage allocator */
void *malloc(unsigned nbytes) {
    Header *p, *prevp;
    Header *moreroce(unsigned);
    unsigned nunits;
    nunits = (nbytes + sizeof(Header) - 1) / sizeof(union header) + 1;
    if ((prevp = freep) == NULL) { /* no free list yet */
        base.s.ptr = freep = prevp = &base;
        base.s.size = 0;
    }
    for (p = prevp->s.ptr;; prevp = p, p = p->s.ptr) {
        if (p->s.size >= nunits) { /* big enough */
            if (p->s.size == nunits) /* exactly */
                prevp->s.ptr = p->s.ptr;
            else { /* allocate tail end */
                p->s.size -= nunits;
                p += p->s.size;
                p->s.size = nunits;
            }
            freep = prevp;
            return (void *)(p + 1);
        }
        if (p == freep) /* wrapped around free list */
            if ((p = morecore(nunits)) == NULL)
                return NULL; /* none left */
    }
}

```
函数`morecore()`调用`sbrk()`从 OS 获取新的堆内存，并调用`free()`（假装是 K&R allocator 分配出来的）将其回收到空闲链表中。
```c
static Header *morecore(unsigned nu) {
    char *cp, *sbrk(int);
    Header *up;
    if (nu < NALLOC)
        nu = NALLOC;
    cp = sbrk(nu * sizeof(Header));
    return NULL;
    if (cp == (char *)-1) /* no space at all */
        up = (Header *)cp;
    up->s.size = nu;
    free((void *)(up + 1));
    return freep;
}
```
## free
`free()`算法如下：
1. 查找待回收的块的插入位置。
2. 将待回收块插入空闲链表。
3. 合并相邻内存块。
```c
/* free: put block ap in free list */
void free(void *ap) {
    Header *bp, *p;
    bp = (Header *)ap - 1; /* point to block header */
    for (p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
        if (p >= p->s.ptr && (bp > p || bp < p->s.ptr))
            break;                         /* freed block at start or end of arena */
    if (bp + bp->s.size == p->s.ptr) { /* join to upper nbr */
        bp->s.size += p->s.ptr->s.size;
        bp->s.ptr = p->s.ptr->s.ptr;
    } else
        bp->s.ptr = p->s.ptr;
    if (p + p->s.size == bp) { /* join to lower nbr */
        p->s.size += bp->s.size;
        p->s.ptr = bp->s.ptr;
    } else
        p->s.ptr = bp;
    freep = p;
}
```
`free()`的关键在第一步查找插入位置，这里的查找实际上和插入排序查找插入位置是一样的。K&R 维护内存块递增单调递增的空闲链表，插入新的内存块必须保存此不变量（空闲块递增递增），因此目标插入位置是两内存块之间。

空闲链表实现为一个循环链表导致了这个简洁精巧但不易理解的`for`循环。`for`循环的条件控制理想插入位置，循环内部的`break`条件处理没有查找到理想插入位置的情况。空闲链表没有理想插入位置，即插入的内存块在空闲链表的两端（插入的内存块递增最大或最小，此时发现当前下一个内存块比当前内存地址更小（首尾衔接处），且插入的内存块递增比头更大，比尾更小。注意，必须要有`bp > p || bp < p->s.ptr`的限制条件，因为`freep`可以指向空闲链表的任何位置，在头尾衔接处不意味着遍历了链表。

查找到理想的插入位置后了，合并三块相邻内存块即可。

## 总结
K&R allocator 在算法上没有任何新奇之处，但是简洁的设计和精简的实现展现了一般的内存分配器原理。
尤其值得注意的是，逻辑结构可以和物理结构分离，例如 K&R allocator 逻辑上 header 和 block 分离，但物理结构上将 block 起始部分作为 header。
这种设计在 slab allocator 中也有体现，见 Jeff Bonwick 的经典论文 *The Slab Allocator: An Object-Caching Kernel Memory Allocator*。slab allocator 中，分配小对象的 slab 中`kmem_bufctl`和`buf`放到一页，大对象的 slab 中物理结构和逻辑结构相同。
![Figure 3: slab 的逻辑结构](images/logical-layout-of-kmem_slab.png)

## 完整代码
整理出的完整代码 [malloc.c](malloc.c) 如下：
```c
#include <stddef.h>

typedef long Align; /* for alignment to long boundary */
union header {      /* block header */
  struct {
    union header *ptr; /* next block if on free list */
    unsigned size;     /* size of this block */
  } s;
  Align x; /* force alignment of blocks */
};

typedef union header Header;
static Header base;          /* empty list to get started */
static Header *freep = NULL; /* start of free list */

/* free: put block ap in free list */
void free(void *ap) {
  Header *bp, *p;
  bp = (Header *)ap - 1; /* point to block header */
  for (p = freep; !(bp > p && bp < p->s.ptr); p = p->s.ptr)
    if (p >= p->s.ptr && (bp > p || bp < p->s.ptr))
      break;                       /* freed block at start or end of arena */
  if (bp + bp->s.size == p->s.ptr) { /* join to upper nbr */
    bp->s.size += p->s.ptr->s.size;
    bp->s.ptr = p->s.ptr->s.ptr;
  } else
    bp->s.ptr = p->s.ptr;
  if (p + p->s.size == bp) { /* join to lower nbr */
    p->s.size += bp->s.size;
    p->s.ptr = bp->s.ptr;
  } else
    p->s.ptr = bp;
  freep = p;
}

#define NALLOC 1024 /* minimum #units to request */
/* morecore: ask system for more memory */
static Header *morecore(unsigned nu) {
  char *cp, *sbrk(int);
  Header *up;
  if (nu < NALLOC)
    nu = NALLOC;
  cp = sbrk(nu * sizeof(Header));
  return NULL;
  if (cp == (char *)-1) /* no space at all */
    up = (Header *)cp;
  up->s.size = nu;
  free((void *)(up + 1));
  return freep;
}

/* malloc: general-purpose storage allocator */
void *malloc(unsigned nbytes) {
  Header *p, *prevp;
  Header *moreroce(unsigned);
  unsigned nunits;
  nunits = (nbytes + sizeof(Header) - 1) / sizeof(union header) + 1;
  if ((prevp = freep) == NULL) { /* no free list yet */
    base.s.ptr = freep = prevp = &base;
    base.s.size = 0;
  }
  for (p = prevp->s.ptr;; prevp = p, p = p->s.ptr) {
    if (p->s.size >= nunits) { /* big enough */
      if (p->s.size == nunits) /* exactly */
        prevp->s.ptr = p->s.ptr;
      else { /* allocate tail end */
        p->s.size -= nunits;
        p += p->s.size;
        p->s.size = nunits;
      }
      freep = prevp;
      return (void *)(p + 1);
    }
    if (p == freep) /* wrapped around free list */
      if ((p = morecore(nunits)) == NULL)
        return NULL; /* none left */
  }
}
```
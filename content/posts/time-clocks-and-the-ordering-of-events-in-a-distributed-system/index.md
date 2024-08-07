---
title: "【论文阅读】Time, clocks, and the ordering of events in a distributed system"
date: "2023-11-11"
keywords: ""
comment: true
weight: 0
author:
  name: "Jun"
  link: "https://github.com/kongjun18"
  avatar: "/images/avatar.jpg"
license: "All rights reserved"
tags:
- Distributed System

categories:
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
  enable: true
lightgallery: false
seo:
  images: []

repost:
  enable: true
  url: ""
---

## 驱动

时钟可以用来标示系统中时间的发生次序，如果系统的所有进程的时钟都是同步的，那么系统中的所有进程就能达成关于事件次序的共识。然而，现实世界中时钟无法绝对同步，即使使用 NTP 等时钟同步技术，不同计算机间的时钟也会存在误差（NTP 误差为数十毫秒）。

此外，因为网络是不可靠的，不能以接收消息的顺序作为分布式系统中事件的发生顺序。

我们关注时钟，本质上是在关注系统中的事件发生次序。Lamport 指出，重要的不是时间，而是事件自身的次序。Lamport 不再考虑计算机的时钟或者物理世界的时间，直接考虑事件间的次序（即 happens-before 关系）。

## happens-before 关系

Lamport 这样定义描述事件发生次序的 happens-before 关系：
1. 同一进程内：事件 A 先发生于 B，则 A 和 B 具有 happens-before 关系，记做`A->B`。
2. 两个进程间：进程 P1 发送消息（事件 A），进程 P2 接收消息（事件 B），则事件 A 和 B 具有 happens-before 关系。

happens before 关系是一个定义在事件集合上偏序，规定了事件的先后次序。因为是偏序，会存在一些事件不在 happens-before 关系上，这些事件间的次序是不确定的，这些事件称作不相关事件（unrelated）。

>[!NOTE]
>不相关（unrelated）指无法确定事件次序。
>
从单个进程的视角看，不同进程观测到的不存在 happens before 关系的事件的次序可能不同。
>
从“上帝视角”看，不存在 happens before 关系的事件次序是无法确定的（类似 C 语言的未定义行为）。

## lamport 逻辑时钟

每个进程 $P_i$ 保存一个自己的逻辑时钟 $C_i$，$C_i(a)$ 表示发生 a 事件时进程 $P_i$ 的逻辑时钟，逻辑时钟更新规则如下：
1.  进程 $P_i$ 执行操作时，递增逻辑时钟 $C_i$。
2.   进程 $P_i$ 发送消息时，递增逻辑时钟 $C_i$。
3. . 进程 $P_i$ 发送消息时附带自己的逻辑时钟。
4. . 进程 $P_j$ 接收消息时更新的自己的逻辑时钟为 $max(C_i, C_j)$。

规则 1 对应进程内的 happens before 关系，规则 2-4 对应进程间的 happens before 关系。显然，如果事件 A 先发生于 B，则发生事件 A 的进程的逻辑时钟小于 B 的进程的逻辑时钟。用数学语言表示即∀a,b.a→b⟹C(a)<C(b)，a、b 是事件，C(a) 是发生事件 a 的进程的逻辑时钟。
![图二](http://yang.observer/img/in-post/2020-07-26-lamport-logical-time/post-time-2.png)
无法通过比较 Lamport 逻辑时钟判断事件次序，即无法通过比较 Lamport 逻辑时钟判断两事件的先后次序，也无法判断两事件是否相关。图中的 C(f) < C(b)，但 f 和 b 是无关的。根据逆反命题，∀a,b.C(a)≧C(b), a↛b 成立，然而这无法说明事件 a 和 b 是否在一条因果链上（a → b 或 b → a）。一个实例是上图中的 c-b 以及 d-e，b 先于 c，但 d 和 e 是不相关的。

>[!NOTE]
>虽然无法通过比较逻辑时钟判断事件的次序。但仍然可以通过比较逻辑时钟获取一些关于事件次序的有用信息。
>C(a) = C(b)，说明 a、b 是无关事件。
>C(a) > C(b)，说明 a ↛ b。

## 全序
论文的目标是要得到一个可以事件的全序，这样就能让系统中的所有进程达成关于事件次序的共识（所有进程看到相同的事件次序）。在前面的 happens before 关系中，可以观察到以下事实：
1. 如果事件 a happens before b，则 $C_(a) < C_(b)$。
2. 如果事件间不具有 happens before 关系，则这两个事件的是无关的，则两个事件的发生次序不重要，我们可以指定发生次序。

用 ⇒ 表示转化后的全序关系，我们可以设定规则 1：
1. 如果 C(a)<C(b), 则 a⇒b。

现在只需要考虑事件逻辑时钟相等的情况，这种情况下两个事件是无关的。我们规定一个系统所有进程间的关系 ≺，如对于包含 A、B、C 三个进程的系统，规定 ≺={(A,B),(A,C),(B,C)}，得到规则 2:
2. 如果 C(a)=C(b) 且 a≺b,  则 a⇒b。

>[!NOTE]
>如果 a → b，则 C(a) < C(b)；如果 b → a，则 C(b) < C(a)。C(a) = C(b)，说明 a 和 b 不存在 happens before 关系。
>

上述两个规则成功排序了整个系统中的事件次序，使 ⇒ 成为一个全序列。全序意味着系统中的所有事件都存在次序关系，所有进程都对系统中的事件次序达成共识，从图像上看，全序是一条箭头（如同物理世界用时间标示事件次序）。

论文给出的一个全序 ⇒ 的用例是分布式锁，分布式锁可以转化成系统中的进程如何关于“获取和释放锁事件的次序”达成共识的问题。论文的分布式锁算法跟 Paxos 或者 Raft 已经有了很多相似之处，具体的算法分析见 https://mwhittaker.github.io/blog/lamports_logical_clocks/。

本论文实际上是 Paxos 等分布式共识算法的前身，全序系统中的事件次序本质上就是让所有进程对事件次序达成共识，全序系统中的（某个值上的）事件次序自然也就让进程对某个值达成了共识。

## 异常情况
逻辑时钟只能全序系统内的事件，考虑以下异常情况。系统 S 会给每个请求附带逻辑时钟，发生以下事件：
1. 事件 a：用户 A 向系统发送请求。
2. 事件 b：用户 A 向 B 打电话让他发送请求。
3. 事件 c：用户 B 向系统发送请求。
由于网络问题，用户 B 的请求先于 A 的请求到达系统，因此 B 的逻辑时钟小于 A 的逻辑时钟，在系统 S 的全序中事件 b 先于 a 发生（B 先于 A 发送请求）。

这种情况单从系统 S 的视角看是正确的，但当将 A、B 和系统 S 都纳入考量时，显然系统 S 排序的事件次序是错误的。问题不在于逻辑时钟算法，而在于事件 b 作为独立于系统 S 外的事件没有被纳入事件的排序中。解决方法是将 A、B 和 S 视作一个系统排序事件。

## 缺陷

Lamport 逻辑时钟的缺陷在于无法用逻辑时钟描述事件在 happens-before 偏序中的关系，既无法用逻辑时钟判断两个事件的先后，也无法判断两事件是否相关。Lamport 逻辑时钟得到的全序是人为构建的，但两事件不相关时，Lamport 逻辑时钟给出的次序是无意义的。

[[向量时钟]]通过拓展了 Lamport 逻辑时钟，可以通过比较逻辑时钟判断事件在 happens-before 偏序中的关系。

## Q&A
- [x] 如何将偏序转换为全序（逻辑时钟相等时的全序集合怎么找）?
    似乎可以直接规定。
- [x] 为什么可以这样规定全序？
    如果两个事件确实存在 happens-before 关系，则 C(A) < C(B)。
    如果两个事件不存在 happens-before 关系，则两个事件的次序不重要。
- [x] 这种规定的全序的意义？
    似乎在于每个进程的事件排成一样的次序，但这种全序本身是不能标示事件的次序的。
- [x] 物理时钟
最终的目标就是得到一个全序，使得所有进程能达成一个相同的时间次序。


## References
- *Time, clocks, and the ordering of events in a distributed system*
- *计算机的时钟（二）：Lamport逻辑时钟 - Yang Blog*
- https://www.cs.princeton.edu/courses/archive/fall19/cos418/docs/L4-time.pdf
- http://yang.observer/2020/09/12/vector-clock/
- http://yang.observer/2020/11/02/true-time/
- https://mwhittaker.github.io/blog/lamports_logical_clocks/
- *逻辑时钟 - 如何刻画分布式中的事件顺序  春水煎茶 - 王超的个人博客*


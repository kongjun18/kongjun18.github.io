---
title: "[Paper Note] Strata Hierarchical Context Caching for Long Context Language Model Serving"
date: 2025-09-13
mdate: 2025-10-23T21:37:31-07:00
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
- name: featured-image-preview
  src: 

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

---
created: 2025-09-13
---
	Status: #paper 
## layout
我的问题是，在这里拷贝实际上是128B的小段，而不是连续的整个page
ChatGPT 说：

非常精准的问题 👏，这正好切中 Strata 设计里最容易被误解的一层。
你完全对：每个 GPU 线程确实只拷 128 B 的小段，
但关键在于——这些「小段」在物理 I/O 层面上仍然是连续的 DMA 访问，并非真正意义上的随机碎片。

这看似矛盾，其实是因为 GPU-assisted I/O 的工作方式跟 CPU 驱动的 memcpy 完全不同。下面我分层解释清楚👇

🧩 一、分清两个层面
层级	谁发起	访问模式	带宽瓶颈
PCIe / NVLink 层（DMA 层）	GPU 硬件通道	连续读写 (page 级)	决定 S（单次传输大小）
GPU 内核层（线程级访存）	数千个线程	局部顺序访问 (128 B)	决定访问并行度与地址计算

所以虽然线程单位是 128 B，但这些线程实际上在执行的是：

从一个连续的 page 区间中，成批取 128 B 子块的并行 load/store。

这意味着：

PCIe 总线上传输的仍然是连续的大块；

GPU 在这块大数据上做的是coalesced memory access（合并访存）；

所以 DMA 仍然能跑满带宽，S 没有变小。

⚙️ 二、为什么 128 B 访问不会让 S 变小

我们可以从 GPU 内核和 DMA 的协同机制理解这点。

1️⃣ DMA 不关心「线程粒度」

PCIe / NVLink 的底层 DMA 单元看见的是 GPU 在发出大量连续地址的 load/store 请求。
只要这些地址落在同一连续物理段（即一个 page），DMA 会自动合并为一个顺序 burst。

换句话说：

多个线程的 128 B 访问，在物理层是合并成一个连续的 MB 级 burst I/O。

这是因为：

128 B 是 GPU warp 内理想的 coalesced access 粒度；

一个 warp（32 个线程）一次能访问 4 KB；

几千个线程覆盖整页几 MB 数据；

这些访问合起来在 DMA 眼里就是顺序访问。

2️⃣ Strata 提前保证 page-first 的「页内连续性」

在 host 内存布局上，page-first layout 本身保证：

Page1 = [L0_T1, L1_T1, L2_T1, ... L63_T1]   // 连续
Page2 = [L0_T2, L1_T2, L2_T2, ... L63_T2]   // 连续


所以当 GPU 线程群从 Page1 读取时，它们的地址分布是连续的，只是线程内的逻辑 stride 不同（每个线程负责不同偏移）。
这就让硬件 DMA 通道可以整页顺序搬运，而不用发出碎片化命令。

因此：

线程 128 B ≠ DMA 128 B。
线程粒度小只是逻辑划分；DMA 仍然传输连续大块。

🧠 三、Strata 内核的执行模型

论文 §4.2 描述的 GPU-assisted I/O kernel 流程是这样的

Xie et al. - 2025 - Strata Hier…

：

启动少量大 CUDA blocks（每 block 1024 线程）；

每个线程从 page-first 源（CPU pinned mem）读入 128 B；

根据 layer-first 的偏移算出目标写入位置；

写入 GPU HBM。

由于：

源地址区域在物理上是连续的；

warp 内线程访问邻近地址；

GPU 的 L2 cache + DMA 控制器会合并这些小请求；
因此整个 kernel 实际上表现为一次连续 I/O。

论文也说明：

“The granularity required for efficient GPU-assisted I/O is only 128 bytes ... sufficiently fine for single-page KV caches (kilobytes), eliminating the need to inflate page size for efficiency.”
——即即使线程搬 128 B，整体 I/O 仍然能满带宽，不必增大页。

这说明：

Strata 的内核访问模式经过专门优化，让 128 B 线程粒度仍能触发高效顺序 DMA。

📈 四、S 在哪里被放大

从公式 
𝑋
=
𝐶
⋅
𝑆
/
𝐿
X=C⋅S/L 来看：

变量	对应机制	影响
C（并发度）	GPU 上几千线程并行读写	极高
S（单次传输大小）	Page-first layout 保证页内连续，DMA 按页 burst	提升至 MB 级
L（延迟）	GPU kernel 避免 CPU 调度开销	降低

所以 page-first layout 不是让线程拷更大块，而是让 DMA 能看到更大的连续块。
而 GPU 线程只是“用小粒度并行地填满这个大块”。

✅ 五、总结一句话

Strata 的每个线程拷 128 B，但这些线程协同访问同一个连续的 page。
这样 DMA 层看到的仍是大块顺序访问（S↑），而不是碎片化 I/O。
page-first layout 的作用，就是让这种线程级 coalesced 访问成为可能，从而既保持小页缓存粒度，又恢复大块带宽。

---

Existing works assume the GPU-CPU bandwidth is not a bottleneck. However, this paper finds the GPU-CPU bandwidth is extremely under-utilized due to the data fragmentation introduced by *PagedAttention* and the existing scheduler doesn't treat GPU-CPU bandwidth as the first class resource, leading to severe data loading latency and thereby stalling the CPU. 

Experiments show 70% time spends in KV cache loading from the lower storage hierarchy, demonstrating GPU-CPU bandwidth is under-utilized. Even with an I/O mechanism achieving 75% of theoretical PCIe bandwidth, stalls still account for up to 24% of prefill execution time, calling for more sophisticated scheduling strategies.

The solution is as follows:
- Improve IO throughput
	- GPU-assisted IO increases concurrency: Thousands of GPU threads load data concurrently.
	- Page-first Layout increases unit data size: Manage the token's pages of layers into a contiguous layout in the low-hierarchical storage, such as GPU memory and SSD.
- IO-aware scheduling that treats GPU-CPU bandwidth as the first class resources.
	- Identify and solve the [delayed hit problem](https://dl.acm.org/doi/pdf/10.1145/3387514.3405883): Avoid scheduling multiple requests which encounter the same cache miss into a batch.
	- Balanced batch: Mix compute-bound requests with IO-bound requests (e.g., requests require loading data from the CPU memory) to maximize IO overlapping.
	- Hide loading stall with bubble filling: If an IO-bound request's latency cannot be hidden, schedule a compute-intensive requests to fill the pipeline bubble.

The evaluation shows:
- The existing designs cannot fully utilize the theoretical GPU-CPU bandwidth.
- With the aforementioned techniques, H200 machine can achieve high GPU-CPU bandwidth than [GH200 Grace Hopper](https://www.nvidia.com/en-us/data-center/grace-hopper-superchip/) with higher theoretical bandwidth.
- Most performance improvement is from GPU-assisted IO and solved delayed hit problem.

Insights:
- Long context is the future direction and recompute is not feasible in long context situations due to limited GPU HBM capacity, necessitating multi-tier KV cache offloading.
- KV cache loading from SSD should be interrupted if the loading doesn't finish before the request is scheduled.
- IO overlaying makes sense because computing and loading presents different IO patterns, one is HBM bandwidth bound and the other one is GPU-CPU bandwidth bound.

Thoughts:
- This paper only solves the GPU-CPU bottleneck and doesn't solve the SSD bottleneck.
- To some senses, this work centers the multi-tier KV cache storage around the CPU memory. 



---
## References

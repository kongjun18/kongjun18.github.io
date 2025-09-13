---
title: "[Paper Note] In Search of an Understandable Consensus Algorithm"
date: 2023-11-01
mdate: 2025-05-22T01:50:34-07:00
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


- [x] 为什么 Leader 要提交之前任期的日志？

	因为 Leader 复制先前任期的日志时，不将日志的任期修改为当前任期。因此会出现先前任期的日志被复制到多数派，但仍未提交的情况。只有当前任期的日志被复制到多数派才算提交，Log Matching Property 确保了当前日志被提交时所有之前的日志均被提交。

- [x] 节点的`currentTerm`是否一定和本地 log 中最新的 entry 的任期相同？

	不一定。`currentTerm`在选举时递增，会存在`currentTerm`比 log 的 term 更新的情况。

- [x] 何时 leader 选举无法取得进展？

	1. 没有多数派个可访问节点

	2. 多个候选者同时请求选票，导致 split note，没有候选人获得多数派投票。

- [x] 如何避免 split note？

	每个节点的选举超时时间都是随机的，不太可能发生多个节点同时超时请求选票的情况。论文 9.3 节测试了随机选举超时时间对选举耗时的影响。

- [x] 如何避免脑裂？

	提交日志需要复制到多数派。发生脑裂时，集群至少有两个分区，真正的 leader 所在分区是多数派，非法的 leader 所在分区是少数派。真正的 leader 所在分区的节点的`currentTerm`均已递增，因此真正的于非法的 leader 所在分区。非法的 leader 所在集群是少数派，因此非法的 leader 无法成功提交日志。当分区恢复，非法的 leader 会接收到 appendEntry RPC 并且任期更真正的，因此转换为跟随者。

- [x] 为什么 leader 可能无法知道自己的日志中哪些日志已提交？

	论文图 8 展示了这种情况。如果某个具有未被提交的旧 leader 日志的节点被选举为新的 leader，Raft 只能保证这个新 leader 一定具有旧 leader 所有已提交的日志，但这个新 leader 无法知道哪些日志已提交。

- [x] Leader 如何确定哪些日志已提交？

	Leader 没有办法自己判断哪些日志已提交。Leader 可以提交一条 no-op 日志，成功提交后，此日志之前的所有条目都是已提交的。这是 Raft Log Matching Property 保证的。

- [x] 客户端的一个命令对应几个日志条目？

	一个命令对应一个条目。

- [x] 论文中的 C_old,new 指什么？

	指旧配置和新配置。

- [x] Joint Consensus 阶段是什么？

	这一阶段中，leader 的所有操作都同时需要新旧配置集群中多数派的确认。C_old,new 被提交到了两个配置的多数派中，确保了即使发生 crash，不论哪个配置选举出的 leader 都具有 C_old,new 配置。Joint Consensus 确保了操作在两个配置的集群中是一致的，进而使得可以在配置变更的过程中服务客户端请求。

- [x] C_old,new 影响跟随者吗？

	不影响。C_old,new 只影响 leader，leader 的所有操作都需要新旧配置的多数派确认。C_old,new 提交到两个集群的多数派是为了确保配置变更过程中 leader crash 后，新选举的 leader 仍然有 C_old,new 配置。

- [x] Raft 存在对时序的要求吗？

	存在，Raft 用于半同步环境。broadcastTime ≪ electionTimeout ≪ MTBF。

Q: The last two paragraphs of section 6 discuss removed servers interfering with the cluster by trying to get elected even though they've been removed from the configuration. Wouldn't a simpler solution be to require servers to be shut down when they leave the configuration? It seems that leaving the cluster implies that a server can't send or receive RPCs to the rest of the cluster anymore, but the paper doesn't assume that. Why not? Why can't you assume that the servers will shut down right away?

A: I think the immediate problem is that the Section 6 protocol doesn't commit Cnew to the old servers, it only commits Cnew to the servers in Cnew. So the servers that are not in Cnew never learn when Cnew takes over from Cold,new.

The paper does say this:

When the new configuration has been committed under the rules of Cnew, the old configuration is irrelevant and servers not in the new configuration can be shut down.

So perhaps the problem only exists during the period of time between the configuration change and when an administrator shuts down the old servers. I don't know why they don't have a more automated scheme.


Q: I don't disagree that having servers deny RequestVotes that are less than the minimum election timeout from the last heartbeat is a good idea (it helps prevent unnecessary elections in general), but why did they choose that method specifically to prevent servers not in a configuration running for election? It seems like it would make more sense to check if a given server is in the current configuration. E.g., in the lab code we are using, each server has the RPC addresses of all the servers (in the current configuration?), and so should be able to check if a requestVote RPC came from a valid (in-configuration) server, no?

A: I agree that the paper's design seems a little awkward, and I don't know why they designed it that way. Your idea seems like a reasonable starting pointhttp://nil.csail.mit.edu/6.824/2022/papers/raft2-faq.txt. One complication is that there may be situations in which a server in Cnew is leader during the joint consensus phase, but at that time some servers in Cold may not know about the joint consensus phase (i.e. they only know about Cold, not Cold,new); we would not want the latter servers to ignore the legitimate leader.

- [x] 何种情况下跟随者接收到的快照是它的日志的前缀？

	当 RPC 发生乱序时。领导者先发送索引 100 上的快照，再发送 110 上的快照。由于网络乱序，110 上的快照先到达。

- [x] 发生网络分区并恢复后，该分区的节点是否可能接收到另外一个分区的投票？

	可能，但不影响最终选举出合法的 leader。集群网络分区为 P1 和 P2。P2 分区的节点 S2 递增任期，P2 网络分区恢复，开始请求选票。P1（现在网络分区已恢复，实际上不存在两个分区）的 S1 发生网络问题，没有在选举超时前接收到心跳，认为 leader 不存在。S1 接收到 S2 的投票请求并投票。http://nil.csail.mit.edu/6.824/2022/papers/raft2-faq.txtgg

	参考 *Redis Cluster 的设计* 关于领导者选举的介绍。
	- 避免响应旧的 vote 请求
	>A master only votes a single time for a given epoch, and refuses to vote for older epochs: every master has a lastVoteEpoch field and will refuse to vote again as long as the `currentEpoch` in the auth request packet is not greater than the lastVoteEpoch. When a master replies positively to a vote request, the lastVoteEpoch is updated accordingly, and safely stored on disk.

	- 避免旧的 reply 被新的 vote 请求接受
	>Auth requests with a `currentEpoch` that is less than the master `currentEpoch` are ignored. Because of this the master reply will always have the same `currentEpoch` as the auth request. If the same replica asks again to be voted, incrementing the `currentEpoch`, it is guaranteed that an old delayed reply from the master can not be accepted for the new vote.

## References
- [In Search of an Understandable Consensus Algorithm](zotero://open-pdf/library/items/T8M4S9KN)
- [MIT 6.824 2022 Lecture 5: Raft (1)](http://nil.csail.mit.edu/6.824/2022/notes/l-raft.txt)
- [MIT 6.824 2022 Lecture 7: Raft (2)](http://nil.csail.mit.edu/6.824/2022/notes/l-raft2.txt)
- [MIT 6.824 Raft FAQ](http://nil.csail.mit.edu/6.824/2022/papers/raft-faq.txt)
- [MIT 6.824 Raft (2) FAQ](http://nil.csail.mit.edu/6.824/2022/papers/raft2-faq.txt)

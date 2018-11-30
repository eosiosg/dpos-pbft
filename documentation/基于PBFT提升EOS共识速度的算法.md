# 基于PBFT提升EOS共识速度的算法

## 1 背景介绍    
#### 1.1 现象  
当前主网的链高度和共识高度之间有325+个块的差距，相当于~3分钟左右的时间差。也就是说，当下提交的trx需要等到~3分钟后才能确认是否被记在链上。这样的表现对于很多DApp来说是不可承受的，尤其是那些需要即时确认的应用。


#### 1.2 原因阐述  
* 造成主网上这种现象的原因，是EOS基于DPOS的共识算法中，所有块同步和确认信息都只通过出块的时候才能发出。也就是说，在BP<sub>1</sub>出块（所出块为BLK）、BP<sub>1</sub>～BP<sub>21</sub>轮流出块的情况下，BP<sub>2</sub>～BP<sub>21</sub>会陆续收到并验证BLK，但所有BP只能等到自己出块的时候才能发出对BLK的确认信息。这也是为什么我们看到nodes的log中，每个BP在schedule中第一次出块的时候，`confirmed`总是240。DPOS+Pipeline BFT理论上共识的最快速度（即head和LIB之间的最小差距）为325。


* 240 = (21-1)*12  
这其实是（在网络情况良好的情况下）上一轮所有块数之和。每个节点在`block_header`中维护着一个长度最长为240，初始值为14的vector `confirm_count`，对应所有收到但是未达成共识的块以及尚需的确认数。每当收到多一个BP对这些块的确认，对应块的数值-1，直到某一块所需的确认数减到0，此块及之前的所有块便进入共识（[相关代码](https://github.com/EOSIO/eos/blob/905e7c85714aee4286fa180ce946f15ceb4ce73c/libraries/chain/block_header_state.cpp#L188)）。  

* 325 = 12*(13+1+13) + 1  
整个网络需要15个人确认才能达成共识。每个人默认会对自己出的块进行确认，所以每个块需要14个人的implicit confirm和（explicit）confirm。第14个BP在出块时由于包括自己在内确认人数已经达到15人，所以它会同时发出implicit confirm和（explicit）confirm。那么理想情况下，一个块从它产生后，要到之后的第28个BP所产出的第一个块时才能得到全网共识，进入LIB。因此有以上计算。


* **我们认为，所有BP不需要等到出块的时候才对其他块进行确认，用PBFT**（Practical Byzantine Fault Tolerance<sup>[1]</sup>）**来替代Pipeline BFT，让BP之间实时地对当前正在生产的区块进行确认，能够使整个系统最终达到接近实时的共识速度。**

## 2 算法核心  
* 保留DPOS的BP Schedule机制,和EOS一样对synchronized clock和BP Schedule进行强约束。

* 去掉EOS中的Pipeline BFT部分共识（即去掉原本EOS中出块时的implicit confirm和(explict) confirm部分），因为在极端情况下可能与PBFT的共识结果有冲突。

* 共识的通讯机制使用现有p2p网络进行通信,但增加通信成本,使用PBFT机制广播prepare和commit信息。

* 通过batch方式优化(替换掉PBFT中对每个块进行共识的要求), 能够达成批量共识，以此来逼近实时BFT的理想状态并减轻网络负载。


## 3 基础概念  
#### 3.1 DPOS中BP变更的具体实现  
* 当前代码中，每60s（120个块）刷新一次投票排名（[相关代码](https://github.com/EOSIO/eos/blob/8f0f54cf0c15c4d08b60c7de4fd468c5a8b38f2f/contracts/eosio.system/producer_pay.cpp#L47)），如果前21名发生变化，会在下一次刷新排名的时候发出`promoting proposed schedule`（[相关代码](https://github.com/EOSIO/eos/blob/8f0f54cf0c15c4d08b60c7de4fd468c5a8b38f2f/libraries/chain/controller.cpp#L909)）  

* 当包含`promoting proposed schedule`的块进入LIB后，BP会陆续更新自己block header中的`pending_schedule`  

* 等到2/3 +1个BP节点都已经更新block header后，`pending schedule`达成共识。BP会陆续将`active schedule`更新为此时`pending schedule`的值，并按照新的BP组合开始出块，整个过程需要至少经过两轮完整的出块。  

* 每一次新的BP组合，一定要能够达成共识才能真正生效。换句话说，如果网络中7个或更多节点无法正常通信，那么无论如何不能通过投票的方式产生新的BP。网络的LIB会一直停留在节点崩溃的那个共识点。

* DPOS这样的做法可以有效的避免一部分分叉问题，所以仍会沿用DPOS关于BP选举部分的共识机制，即所有的BP变动，需要等到propose schedule进入LIB后才真实生效。  

#### 3.2 PBFT的前提  
* 如果网络中的拜占庭节点为f个，那么要求总节点数n满足n≥3f+1。拜占庭节点是指对外状态表现不一致的节点，包括主动作恶的节点和因为网络原因导致失效或部分失效的节点。  

* 所有信息最终可达: 所有通信信息可能会被延迟/乱序/丢弃, 但通过重试的方式可以保证信息最终会被送达。


#### 3.3 PBFT中的关键概念对应DPOS
**pre-prepare**，指primary节点收到请求，广播给网络里的所有replica。可以类比为DPOS中BP出块并广播至全网。


**prepare**，指replica收到请求后向全网广播将要对此请求进行执行。可类比为DPOS重所有节点收到块并验证成功后广播已收到的信息。


**commit**，指replica收到足够多的对同一请求的prepare消息，向全网广播执行此请求。可以类比为DPOS中节点收到足够多对同一个块的prepare消息, 提出proposed lib消息

**committed-local**, 指replica收到足够多对同一请求的commit消息, 完成了验证工作. 可以类比为DPOS中的LIB提升.


**view change**，指primary节点因为各种原因失去replica信任，整个系统更改primary的过程。由于EOS采用了DPOS的算法，所有BP是通过投票的方式提前确定的，在同一个BP schedule下整个系统的出块顺序是完全不变的，当网络情况良好并且BP schedule不变的时候可以认为不存在view change。  
当引入PBFT后，为了避免分叉导致共识不前进的情况，加入view change机制，抛弃所有未达成共识的块进行replay，不断重试直到继续共识。

**checkpoint**, 指在某一个块高度记录共识证据, 以此来提供安全性证明. 当足够多的replica的checkpoint相同时, 这个checkpoint被认为是stable的. checkpoint的生成包括两大类,一类是固定k个块生成; 另一类是特殊的需要提供安全性证明的点,例如BP schedule发生变更的块.


## 4 未优化版本概述

术语:  
* v: view version  
* i: BP的名字  
* BLK<sub>n</sub>: 第n个块  
* d<sub>n</sub>: 对应第n个块的共识消息摘要digest  
* σ<sub>i</sub>: 名为i的BP的签名  
* n: 区块的高度  

所有BP针对每一个块按顺序进行共识, 采用PBFT机制. 以下分情况进行描述:


#### **4.1 在正常的情况下（不涉及BP变更也没有分叉，且网络状况良好）**  
**pre-prepare**阶段，与现行逻辑没有区别，即BP广播其签名的块。  


**prepare**阶段，BP<sub>i</sub>收到当前BP签名的块BLK<sub>n</sub>，经过验证后发出 (PREPARE,v,n,d<sub>n</sub>,i)<sub>σ<sub>i</sub></sub> 消息，等待共识。当BP<sub>i</sub>收到了2/3的节点发出view v下对BLK<sub>n</sub>的PREPARE消息，认为网络中对此块的prepare已达成共识。已发出的PREPARE消息，不可更改。


**commit**阶段，当BLK<sub>n</sub>标记为 ***prepared*** 后，BP<sub>i</sub>发出(COMMIT,v,n,d<sub>n</sub>,i)<sub>σ<sub>i</sub></sub>。需要注意的是，PBFT是通过保证严格顺序来实现安全性的，所以对所有节点对块的共识也是严格的按照顺序进行，也就是说，(PREPARE,v,n,d<sub>n</sub>,i)<sub>σ<sub>i</sub></sub>发出的前提条件是在同一个view下，BLK<sub>n-1</sub>至少已经处于 ***committed*** 状态。


**全网角度下LIB提升**，当BP<sub>i</sub>收到了2/3的节点发出v下对BLK<sub>n</sub>的COMMIT消息，BP<sub>i</sub>认为网络中对此块的commit已达成共识，即此块已达成共识，此块标记为 *committed* 状态，并将LIB提升到当前高度n，然后开始对下一个块进行prepare。若此区块高度为H<sub>i</sub>，所有BP的LIB高度进行降序排列后得到长度为L的向量V<sub>c</sub>, 从全网角度来看V<sub>c</sub>[2/3L]及以下的LIB可以被认为 ***stable*** ，V<sub>c</sub>[2/3L]即此时全网的LIB高度。  


**对于同一个块而言，只有收集足够的PREPARE消息，才会进入commit阶段。同理，只有收集足够的COMMIT消息，才会开始对下一个块开始prepare，否则就一直重发直到消息数满足要求或进行view change（见后文）。**

#### **4.2 当BP产生变化的时候**  
**pre-prepare**阶段，与4.1无区别。  


**prepare**和**commit**阶段，由于不同BP间对于BP变动的信息达成共识的时间有先后，此时便会出现BP之间对于schedule的不一致状态。  
以BP<sub>i</sub>为例，BP<sub>i</sub>收到了当前BP<sub>c</sub>签名的块BLK<sub>n</sub>，如果此时多数BP的active schedule已改为S'，而BP<sub>i</sub>仍是S，那么BP<sub>i</sub>便会持续等待S中的BP发送的PREPARE信息，从而无法进入commit阶段。  
但此时网络中的多数节点仍会相互达成共识，致使全网的LIB提升。如果BP<sub>i</sub>收到足够的同一个view下的commit信息, BP<sub>i</sub>会进入commit-local状态,提升自己的LIB。  



#### **4.3 当产生分叉的时候**  
**pre-prepare**阶段，与4.1无区别。  

**prepare**和**commit**阶段，当BP<sub>i</sub> 在timeout=T内没有收集足够的PREPARE或COMMIT消息，即共识没有在这个时间段内提升，此时发出VIEW-CHANGE消息，发起view change 并不再接收除VIEW-CHANGE、NEW-VIEW和CHECKPOINT外的任何消息。

**view change**阶段，BP<sub>i</sub> 发出 (VIEW-CHANGE,v+1,h<sub>lib</sub>,n,i)<sub>σ<sub>i</sub></sub>消息。当收集到 2/3 +1 个v'=v+1的VIEW-CHANGE消息后，由schedule中的下一个BP发出 (NEW-VIEW,v+1,n,VC,O)<sub>σ<sub>bp</sub></sub>消息，其中VC是所有包括BP签名的VIEW-CHANGE消息，O是所有未达成共识的PRE-PREPARE消息（介于h<sub>lib</sub>和n<sub>max</sub>之间）。当其它BP收到并验证NEW-VIEW消息合法后，丢弃掉所有当前未达成共识的块，基于所有的PRE-PREPARE消息重新进行prepare和commit阶段。  
若view change未能在timeout=T内达成共识（没有正确的NEW-VIEW消息发出），即发起新一轮v+2的view change，等待时间timeout=2T, 依次类推不断重试，直到网络状态收敛，共识开始提升。  


**备注**: 原始的PBFT不存在分叉的问题, 因为PBFT只有在一个请求达成共识后才会开始处理下一个请求。


## 5 未优化版本存在的问题:
#### 5.1 共识速度
当对一个块的共识速度小于500ms，即两轮消息的发送可以在500ms内收到足够的确认数，head和LIB的差距稳定后可以趋近于1个块，即实时共识。而当对一个块的平均共识速度大于等于500ms或网络状态极差导致重试次数过多，本算法表现可能慢于DPOS+Pipeline BFT。

#### 5.2 网络开销
假设网络中的节点为N，消息传播使用gossip算法，块大小为B，那么DPOS需要传播的消息为N<sup>2</sup>，所需带宽为BN<sup>2</sup>。  
假设PREPARE和COMMIT消息大小分别为p和c，PBFT+DPOS所需要传播的消息数为 (1+r<sub>p</sub>+r<sub>c</sub>)N<sup>2</sup>，其中1 是pre-prepare的传输,r<sub>m</sub>，r<sub>c</sub>为prepare和commit的重试次数，所需带宽为(B+pr<sub>p</sub>+cr<sub>c</sub>)N<sup>2</sup>。当p、c优化的足够小后，额外的带宽开销主要取决于重试次数。

## 6 优化后的版本概述
#### 6.1 通过自适应粒度调整,实现批量共识
##### 6.1.1 batch 策略
LIB的高度为h<sub>LIB</sub>  
fork中最高点的块的高度为 h<sub>HEAD</sub>  
涉及到BP schedule变动的块高度为 h<sub>s</sub>  
批量共识batch:  
* batch<sub>min</sub> = 1  
* batch<sub>max</sub> = min(default_batch_max, h<sub>HEAD</sub> - h<sub>LIB</sub>)  

当batch<sub>max</sub>中不包含BP Schedule变动时, batch = batch<sub>max</sub>  
当batch<sub>max</sub>中包含BP Schedule变动且h<sub>LIB</sub> < h<sub>s</sub> 时, batch =  h<sub>s</sub> - 1  
当batch<sub>max</sub>中包含BP Schedule变动且h<sub>LIB</sub> == h<sub>s</sub> 时, batch = batch<sub>max</sub>

##### 6.1.2 批量共识原理
当未出现分叉情况时, 以上构筑可类比PBFT中view不变情况下的共识. 并且基于Merkle Tree的基本结构，当多数节点可以对BLKn的Hash达成共识，那么之前的所有块都应该是共识的. 此处保证了块的total order.

当出现分叉情况时, PREPARE 信息不能变动，否则可能对外表现为拜占庭错误。此时需要不断重发当前的PREPARE消息直到网络达成共识或触发timeout 后发起view change。

##### 6.1.3 实现方法
* 每当收到新的块时, BP 通过batch的策略生成PREPARE信息, 进行缓存及广播

* 每个BP为block_header维护一个最低水位h，和最高水位H，分别对应自己还没有达成共识的最低点和最高点。

* 同时维护两个长度为（H-h）的向量 V<sub>p</sub> & V<sub>c</sub>，包括水位间每一个块所需要的PREPARE消息数和COMMIT消息数。  

* 每收到一个高度为n的PREPARE消息（或COMMIT消息），通过消息的签名和digest进行验证并确认他与自己处于相同的fork后，依次将V<sub>p</sub>（V<sub>c</sub>）中（h ≤ n）的所有数值-1。  

* 不断重发同一个fork上高度为H的PREPARE消息（或COMMIT消息），直到达成共识或超时后触发View Change（基于New View重新开始PBFT共识，此时v' = v+1）。  

* 当某一个处于高度x（h ≤ x ≤ H）的块收集超过2/3 +1个PREPARE消息，依次执行从h～x的块内容并标记所有（h ≤ x）的块为 *prepared*，然后自动发出高度为x的COMMIT消息。  

* 当某一个处于高度y（y ≤ H）的块收集超过2/3 +1个COMMIT消息，依次执行从h～y的块内容并标记所有（h ≤ y）的块为 *committed*。此时认为≤y的所有块已达成共识，将自己的LIB高度提升至y。

* 每隔若干块生成checkpoint以提高性能。当网络内超过2/3 +1的最新的checkpoint 都达到某一高度c，并且处于同一fork上，则认为此checkpoint稳定。  

##### 6.1.4 view change策略
* BP依据出块的schedule依次成为前一人的backup，确保每一次view change后的primary只可能有一人。

* 当网络开始进入view change后，NEW-VIEW应该重新对2/3 +1人看到的最低点h和最高点H之间的块进行重新共识。  

* 发出NEW-VIEW的BP应该在消息内包括所有VIEW-CHANGE消息，并根据所有的VIEW-CHANGE消息计算出h和H，并将[h, H]区间内超过（2/3 +1）的人选择的fork一并发出。

* 当BP收到NEW-VIEW消息并进行验证后，基于NEW-VIEW的内容重新进行prepare。

* 若在timeout=T内无法完成view change，便开始发起v+2的新一轮view change，直到网络对fork的选择达成共识。  

#### 6.2 通过始终prepare最长链并结合view change，避免分叉风险
* 当BP收到多个fork的时候，应该对当前所能看到的最长链进行prepare, 采取longest-live-fork原则.

* BP在进行prepare的时候，应该错开BP切换的时间点，从而避免选择少数人支持的fork。

* **BP一旦对某个fork进行prepare，就不能再对prepare消息进行更改，否则可能成为拜占庭错误，** BP需要：  
1）不断重发之前的PREPARE消息，等待最终达成共识。即使这个fork不是最长链, 因为有更多人支持，也应该选择这个fork；  
2）或等待timeout=T后，发起view change，所有BP基于NEW-VIEW发出的fork开始新的BPFT共识；  
3）收到超过（2/3 +1）同一fork的COMMIT消息或checkpoint，抛弃当前状态同步至多数人达成共识的高度。  

#### 6.3 通过Checkpoint机制实现GC并提升同步性能
* BP不断网络内广播自己当前的checkpoint状态，并且接收来自其他人的checkpoint。

* 当同一分支上有超过（2/3 +1）人的checkpoint已经高于c，认为CHECKPOINT<sub>c</sub>已经stable，删除高度低于c以前所有PREPARE、COMMIT消息等cache。

* 通过验证checkpoint的正确性，可以大幅提升节点的同步速度。

## 7 FAQ
DPOS相关问题（见1.2）  

1. 简单说明DPOS是如何工作的  
暂略
2. 为什么DPOS的lib是12个12个的涨  
暂略
3. 为什么DPOS的HEAD和LIB差距这么大  
暂略
4. 当BP变动时, DPOS是如何工作的  
暂略
5. 目前节点间的数据是如何同步的  
暂略

PBFT相关问题

1. 简单说明PBFT  
暂略

DPOS-PBFT相关问题  

1. 简单说明DPOS-PBFT是如何工作的  
见5  


2. 为什么不能只广播一次prepare的信息  
当网络出现分叉（或BP变动）的时候，如果只有PREPARE信息，所有节点是无法对其它节点的view change进行响应的，会导致硬分叉。 举例说明: 因为分布式网络的特性, 信息会被延迟或打乱。假设现在有三个连续出块的BP A,B,C 如果B没有收到A的最后一个块, 那么他会继续从倒数第二个块开始出块。这样造成了两个fork选择F1 F2. 假定A的最后一个块里包含了BP变动的信息(该块在F1里), 那么选择了F1的节点需要一个新的BP S1来进行共识, 而F2的节点需要原有的BP S2 进行共识。 共识的群体发生了变化, 很有可能会两边最终都进入共识状态, 进而导致整体网络发生分叉。


3. prepare和commit重发机制是如何工作的  
当超过给定的timeout T后仍然没有对某一个处于 *prepared* 或者 *committed* 的块收集到足够多的确认，就对同一个消息进行多一次的重发，直到收集到足够多的确认或发生view change。  


4. 当BP集合变动的时候,是否存在分叉风险  
见4.2  


6. 是否需要等待共识完成才能继续出块  
出块可以持续进行，共识只影响LIB的高度  


7. 如果第N个块未满足BFT共识个数,但第N+1个块收到了足够多的confirm,该如何处理  
对于优化后的算法，可以直接开始基于N+2个块开始收集共识消息  


8. 持续出块是否会因为共识未迅速达成而分叉    
不会，至少表现为DPOS的状态，最终会共识在最长链上   


9. BFT的commit信息是否需要写入块中  
所有消息（发出的和收到的）都只存在本地. 但需要保留一段时间, 用以为peer提供共识的证据


10. 额外增加的开销有多少  
见5.2   


11. 共识的速度真的能提升吗,如果BFT共识平均时间>500ms,BFT的高度是低于DPOS的  
见5.1


## 8 参考
[1] http://pmg.csail.mit.edu/papers/osdi99.pdf

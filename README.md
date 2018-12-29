
## consensus protocol: dpos - practical bft

boost the consensus gap from 162.5 seconds to 3-6 seconds

[source code changes](https://github.com/eosiosg/eos/compare/v1.4.4...eosiosg:feature/dpos-pbft)


# deploy test network using k8s

## pre-requirement
- install kubectl
- install kustomize

## sample configuration is in k8s/n-nodes.

following nodes are pre-configured:
- boot node named eosio
- 26 bp nodes, named as bpa, bpb, bpc ... bpz
- 9 full nodes, named as node-0, node-1, node-2 ... node-8

in pre-configured network topology:
- full nodes are fully meshed
- each full node connects to 3 bp
- eosio connects to node-8

the topology can be easily adjusted in k8s/n-nodes/configmap.yaml

## how to deploy to localhost
```bash
cd k8s/src/localhost
./apply.sh
```
## how to clean up
```bash
cd k8s/src/localhost
./delete.sh
```
for fast deletion of statefulset, use ```./mannual_delete_pod.sh``` to fast delete all bp and node

## how to monitor nodes info
- if deployed locally, use http://localhost to monitor
- if deployed in cloud, you need to config monitor.yaml to enable monitor
- for sample monitor page, view http://dpos-pbft.eosio.sg

## shuffle producer scripts is in k8s/scripts

1. use ```. ./env```to setup your env
2. use ```./start``` to deploy contracts and create accounts
3. use ```./cron-vote.sh``` to trigger producer shuffle


## consensus protocol: dpos - practical bft

boost the consensus gap from 162.5 seconds to 3-6 seconds

[source code changes](https://github.com/eosiosg/eos/compare/v1.4.4...eosiosg:feature/dpos-pbft)


# deploy test network using k8s

## sample configuration is in k8s/n-nodes.

following nodes are pre-configured:
- boot node named eosio
- 14 bp nodes, named as bpa, bpb, bpc ... bpn
- 14 full nodes, named as node-0, node-1, node-2 ... node-13

in pre-configured network topology:
- each bp connects to one different full node.
- eosio connects to node-0
- all node-x connect to node-0 node-4 node-8 node-12

the topology can be easily adjusted in k8s/n-nodes/configmap.yaml

> NOTICE: direct load balance to api port 8888 is notworking due to unknown error. therefore proxy nginx is configured to provide api access. A manual configuration is required in current stage:  

find eosio cluster ip adress use:
```
kubectl get pod -o wide
```

update nginx proxy pass ip in nginx.yaml
```
server {
  location / {
    proxy_pass http://10.48.2.19:8888; # update here to set proxy
  }
}
```
Or you can use kubectl logs -f bp-0 to view logs


## shuffle producer scripts is in k8s/scripts

1. use ```. ./env```to setup your env
2. use ```./start``` to deploy contracts and create accounts
3. use ```./cron-vote.sh``` to trigger producer shuffle

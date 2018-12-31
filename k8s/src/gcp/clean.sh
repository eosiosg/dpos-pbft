#!/usr/bin/env bash

kubectl scale --replicas=0 statefulset eosio
kubectl scale --replicas=0 statefulset node
kubectl scale --replicas=0 statefulset bp

for i in {25..0..-1}; do kubectl delete pod bp-$i; done
for i in {8..0..-1}; do kubectl delete pod node-$i; done

kubectl delete statefulset eosio
kubectl delete statefulset node
kubectl delete statefulset bp

kubectl delete pvc --all

#!/usr/bin/env bash

for i in {25..0..-1}; do kubectl delete pod bp-$i; done
for i in {8..0..-1}; do kubectl delete pod node-$i; done

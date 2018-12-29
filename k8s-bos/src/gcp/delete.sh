#!/usr/bin/env bash

kustomize build . | kubectl delete -f -

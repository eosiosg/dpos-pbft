#!/usr/bin/env bash

kustomize build . | kubectl apply -f -

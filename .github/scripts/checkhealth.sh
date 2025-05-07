#!/bin/bash

HEALTHY="the cluster is healthy"
UNHEALTHY="the cluster is not healthy"
FAILED_CHECKS=""
IS_HEALTHY=true

# Check nodes
echo "Checking nodes..."
NODE_STATUS=$(kubectl get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}')
UNREADY_NODES=$(echo "$NODE_STATUS" | grep -vc "True")

if [ "$UNREADY_NODES" -gt 0 ]; then
  IS_HEALTHY=false
  FAILED_CHECKS="$FAILED_CHECKS\n- Nodes are not all ready ($UNREADY_NODES unready)"
fi

# Check pods status in all namespaces
echo "Checking pods..."
BAD_PODS=$(kubectl get pods --all-namespaces -o jsonpath='{.items[?(@.status.phase!="Running" && @.status.phase!="Succeeded")]..metadata.name}' | wc -w)
BAD_POD_NAMES=$(kubectl get pods --all-namespaces -o jsonpath='{.items[?(@.status.phase!="Running" && @.status.phase!="Succeeded")]..metadata.namespace}/{.items[?(@.status.phase!="Running" && @.status.phase!="Succeeded")]..metadata.name}' | tr ' ' '\n')

if [ "$BAD_PODS" -gt 0 ]; then
  IS_HEALTHY=false
  FAILED_CHECKS="$FAILED_CHECKS\n- $BAD_PODS pods are not in Running or Succeeded state:\n$BAD_POD_NAMES"
fi

# Check deployments availability
echo "Checking deployments..."
UNAVAILABLE_DEPLOYMENTS=$(kubectl get deployments --all-namespaces -o jsonpath='{.items[?(@.status.availableReplicas!=@.spec.replicas)].metadata.name}' | wc -w)
UNAVAILABLE_DEPLOYMENT_NAMES=$(kubectl get deployments --all-namespaces -o jsonpath='{.items[?(@.status.availableReplicas!=@.spec.replicas)].metadata.namespace}/{.items[?(@.status.availableReplicas!=@.spec.replicas)].metadata.name}' | tr ' ' '\n')

if [ "$UNAVAILABLE_DEPLOYMENTS" -gt 0 ]; then
  IS_HEALTHY=false
  FAILED_CHECKS="$FAILED_CHECKS\n- $UNAVAILABLE_DEPLOYMENTS deployments have unavailable replicas:\n$UNAVAILABLE_DEPLOYMENT_NAMES"
fi

# Check statefulsets availability
echo "Checking statefulsets..."
UNAVAILABLE_STATEFULSETS=$(kubectl get statefulsets --all-namespaces -o jsonpath='{.items[?(@.status.readyReplicas!=@.spec.replicas)].metadata.name}' | wc -w)
UNAVAILABLE_STATEFULSET_NAMES=$(kubectl get statefulsets --all-namespaces -o jsonpath='{.items[?(@.status.readyReplicas!=@.spec.replicas)].metadata.namespace}/{.items[?(@.status.readyReplicas!=@.spec.replicas)].metadata.name}' | tr ' ' '\n')

if [ "$UNAVAILABLE_STATEFULSETS" -gt 0 ]; then
  IS_HEALTHY=false
  FAILED_CHECKS="$FAILED_CHECKS\n- $UNAVAILABLE_STATEFULSETS statefulsets have unavailable replicas:\n$UNAVAILABLE_STATEFULSET_NAMES"
fi

if [ "$IS_HEALTHY" = true ]; then
  echo "$HEALTHY"
  exit 0
else
  echo "$UNHEALTHY$FAILED_CHECKS" >&2
  exit 1
fi

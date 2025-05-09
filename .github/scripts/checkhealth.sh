#!/bin/bash

set -e

HEALTHY="the cluster is healthy"
UNHEALTHY="the cluster is not healthy"
FAILED_CHECKS=""
IS_HEALTHY=true

# Debug function to log messages to stderr
debug() {
  echo "[DEBUG] $@" >&2
}

# Get node status directly before health checks
echo "Getting node status before health checks..."
kubectl get nodes -o wide

echo "[INFO] Checking cluster node health..."

# Get the number of nodes not in Ready state
UNREADY_NODES=$(kubectl get nodes -o json | jq '[.items[] | select(.status.conditions[] | select(.type=="Ready" and .status!="True"))] | length')

if [ "$UNREADY_NODES" -eq 0 ]; then
  echo "[INFO] All nodes are healthy."
else
  echo "[ERROR] Cluster has $UNREADY_NODES unready node(s)."
  echo "the cluster is not healthy"
  exit 1
fi

# Check pods status in all namespaces using jq
echo "Checking pods..."
UNHEALTHY_PODS=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.status.phase != "Running" and .status.phase != "Succeeded") | .metadata.namespace + "/" + .metadata.name')
UNHEALTHY_POD_NAMES=$(kubectl get pods --all-namespaces -o json | jq -r '.items[] | select(.status.phase != "Running" and .status.phase != "Succeeded") | .metadata.namespace + "/" + .metadata.name')

debug "UNHEALTHY_PODS: $UNHEALTHY_PODS"
debug "UNHEALTHY_POD_NAMES: $UNHEALTHY_POD_NAMES"

if [ -n "$UNHEALTHY_POD_NAMES" ]; then # Check if not empty
  IS_HEALTHY=false
  FAILED_CHECKS="$FAILED_CHECKS\n- $UNHEALTHY_PODS pods are not in Running or Succeeded state:\n$UNHEALTHY_POD_NAMES"
fi

# Check deployments availability
echo "Checking deployments..."
UNAVAILABLE_DEPLOYMENTS=$(kubectl get deployments --all-namespaces -o jsonpath='{.items[?(@.status.availableReplicas!=@.spec.replicas)].metadata.name}' | wc -w)
UNAVAILABLE_DEPLOYMENT_NAMES=$(kubectl get deployments --all-namespaces -o jsonpath='{.items[?(@.status.availableReplicas!=@.spec.replicas)].metadata.namespace}/{.items[?(@.status.availableReplicas!=@.spec.replicas)].metadata.name}')

debug "UNAVAILABLE_DEPLOYMENTS: $UNAVAILABLE_DEPLOYMENTS"
debug "UNAVAILABLE_DEPLOYMENT_NAMES: $UNAVAILABLE_DEPLOYMENT_NAMES"

if [ "$UNAVAILABLE_DEPLOYMENTS" -gt 0 ]; then
  IS_HEALTHY=false
  FAILED_CHECKS="$FAILED_CHECKS\n- $UNAVAILABLE_DEPLOYMENTS deployments have unavailable replicas:\n$UNAVAILABLE_DEPLOYMENT_NAMES"
fi

# Check statefulsets availability
echo "Checking statefulsets..."
UNAVAILABLE_STATEFULSETS=$(kubectl get statefulsets --all-namespaces -o jsonpath='{.items[?(@.status.readyReplicas!=@.spec.replicas)].metadata.name}' | wc -w)
UNAVAILABLE_STATEFULSET_NAMES=$(kubectl get statefulsets --all-namespaces -o jsonpath='{.items[?(@.status.readyReplicas!=@.spec.replicas)].metadata.namespace}/{.items[?(@.status.readyReplicas!=@.spec.replicas)].metadata.name}')

debug "UNAVAILABLE_STATEFULSETS: $UNAVAILABLE_STATEFULSETS"
debug "UNAVAILABLE_STATEFULSET_NAMES: $UNAVAILABLE_STATEFULSET_NAMES"

if [ "$IS_HEALTHY" = true ]; then
  echo "$HEALTHY"
  exit 0
else
  echo "$UNHEALTHY$FAILED_CHECKS" >&2
  exit 1
fi

#!/bin/bash
set -e

# GitHub credentials
REPO_URL="https://github.com/walterov/gitops-flux2-kustomize-helm-mt.git"
REPO_DIR="gitops-flux2-kustomize-helm-mt"
TARGET_PATH="apps/staging/ai-model"
YAML_FILE_NAME="ai-model-deployment.yaml"
COMMIT_MESSAGE="Add KAITO workspace for phi-3-mini-4k-instruct"

# Use environment variable for GitHub token (in CI)
if [ -n "$GITOPS_PUSH_PAT" ]; then
  echo "Using GitHub token from environment for authentication"
  git config --global credential.helper store
  echo "https://walterov:${GITOPS_PUSH_PAT}@github.com" > ~/.git-credentials
  chmod 600 ~/.git-credentials
fi

# === Clean and clone repo ===
rm -rf $REPO_DIR
git clone $REPO_URL
cd $REPO_DIR

# === Get nodes with label apps=llm-inference ===
NODE_NAMES=$(kubectl get nodes -l apps=llm-inference -o jsonpath='{.items[*].metadata.name}')

# === Generate workspace.yaml ===
OUTPUT_FILE="${TARGET_PATH}/${YAML_FILE_NAME}"
mkdir -p "${TARGET_PATH}"

cat <<EOF > "$OUTPUT_FILE"
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: workspace-phi-3-mini
resource:
  labelSelector:
    matchLabels:
      apps: llm-inference
  preferredNodes:
EOF

for node in $NODE_NAMES; do
  echo "  -  $node" >> "$OUTPUT_FILE"
done

cat <<EOF >> "$OUTPUT_FILE"
inference:
  preset:
    name: "phi-3-mini-4k-instruct"
EOF

# === Git commit and push ===
git config user.name "GitOps Bot"
git config user.email "gitops-bot@local"

git add "$OUTPUT_FILE"
git commit -m "$COMMIT_MESSAGE"
git push origin main

echo "${YAML_FILE_NAME} pushed to GitHub in ${REPO_URL}/tree/main/${TARGET_PATH}"


#!/bin/bash

set -e  # Exit on error

# GitHub repo details
REPO_URL="https://github.com/walterov/gitops-flux2-kustomize-helm-mt.git"
REPO_DIR="gitops-flux2-kustomize-helm-mt"
TARGET_PATH="apps/staging/ai-model"
YAML_FILE_NAME="ai-model-deployment.yaml"
COMMIT_MESSAGE="Add KAITO workspace for phi-3-mini-4k-instruct"

# === Prompt for GitHub username and token (if ~/.git-credentials doesn't exist) ===
if [ ! -f ~/.git-credentials ]; then
  echo "GitHub authentication is required to push changes."
  read -p "Enter your GitHub username: " GH_USER
  read -s -p "Enter your GitHub Personal Access Token (PAT): " GH_TOKEN
  echo
  echo "Storing credentials for future use..."

  echo "https://${GH_USER}:${GH_TOKEN}@github.com" > ~/.git-credentials
  chmod 600 ~/.git-credentials

  # Configure Git to use credential store
  git config --global credential.helper store
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

echo "workspace.yaml pushed to GitHub in ${REPO_URL}/tree/main/${TARGET_PATH}"


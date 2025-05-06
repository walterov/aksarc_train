#!/bin/bash
set -euo pipefail

# GitHub credentials
REPO_NAME="gitops-flux2-kustomize-helm-mt"
REPO_DIR=$REPO_NAME
TARGET_PATH="apps/staging/ai-model"
YAML_FILE_NAME="ai-model-deployment.yaml"
COMMIT_MESSAGE="Add KAITO workspace for phi-3-mini-4k-instruct"
REPO_OWNER="walterov"
REPO_URL=https://${REPO_OWNER}:${GITOPS_PUSH_PAT}@github.com/${REPO_OWNER}/${REPO_NAME}.git

# Use environment variable for GitHub token (in CI)
if [ -z "${GITOPS_PUSH_PAT:-}" ]; then
  echo "❌ GITOPS_PUSH_PAT is not set"
  exit 1
fi

# Automatically clean up the cloned repo when the script exits (success or error)
trap 'rm -rf "$REPO_DIR"' EXIT

# === Clean and clone repo ===
rm -rf "$REPO_DIR"
git clone "$REPO_URL"

cd "$REPO_DIR"

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
if git diff --cached --quiet; then
  echo "ℹ️ No changes to commit"
else
  git commit -m "$COMMIT_MESSAGE"
  git push origin main
  echo "✅ ${YAML_FILE_NAME} pushed to ${REPO_NAME}/apps/staging/ai-model/"
fi


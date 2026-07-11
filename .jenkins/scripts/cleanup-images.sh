#!/usr/bin/env sh
set -eu

REPO="${1:?missing repo}"
KEEP_COUNT="${2:?missing keep count}"
DEPLOY_CONTAINER_NAME="${3:?missing container name}"

CURRENT_IMAGE="$(docker inspect --format='{{.Config.Image}}' "$DEPLOY_CONTAINER_NAME" 2>/dev/null || true)"
IMAGE_LIST="$(docker images "$REPO" --format '{{.Repository}}:{{.Tag}}|{{.CreatedAt}}' | grep -v '<none>' | sort -t'|' -k2,2r | cut -d'|' -f1)"

if [ -z "$IMAGE_LIST" ]; then
    echo '未发现可清理的应用镜像'
    exit 0
fi

TMP_KEEP="$(mktemp)"
trap 'rm -f "$TMP_KEEP"' EXIT

printf '%s\n%s\n' "$CURRENT_IMAGE" "$IMAGE_LIST" | awk 'NF && !seen[$0]++ {print}' | head -n "$KEEP_COUNT" > "$TMP_KEEP"

echo '保留镜像:'
cat "$TMP_KEEP"

printf '%s\n' "$IMAGE_LIST" | while read -r IMAGE; do
    if ! grep -Fxq "$IMAGE" "$TMP_KEEP"; then
        echo "清理旧镜像: $IMAGE"
        docker rmi "$IMAGE" >/dev/null 2>&1 || true
    fi
done


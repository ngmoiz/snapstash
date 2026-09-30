#!/usr/bin/env bash
set -euo pipefail
trap 'echo "ERROR line $LINENO (code $?)" >&2' ERR

if ! garage_pod=$(kubectl get pods -l app=garage -o jsonpath='{.items[0].metadata.name}' 2>/dev/null);then
    echo "garage not deployed" >&2
    exit 1
fi

echo $garage_pod
bucket_name="images"
app_name="snapstash"

if ! cluster_status=$(kubectl exec $garage_pod -- /garage json-api GetClusterStatus 2>/dev/null); then
    echo "garage not responding" >&2
    exit 1
fi

node_id=$(echo "$cluster_status" | jq -r '.nodes[0].id')
node_role=$(echo "$cluster_status" | jq -r '.nodes[0].role')
layout_version=$(($(echo "$cluster_status" | jq -r '.layoutVersion') + 1))

if [[ $node_id == "null" ]]; then
    echo "garage answered but reports no node" >&2
    exit 1
fi

if [[ $node_role == "null" ]]; then
    echo "volume doesn't exist $node_role"
    echo "create 3G volume"
    kubectl exec $garage_pod -- /garage layout assign -z dc1 -c 3G $node_id
    echo "apply the volume"
    kubectl exec $garage_pod -- /garage layout apply --version $layout_version
else
    echo "volume already exist $node_role"
fi

app_access_key_id=$(echo "$(kubectl exec $garage_pod -- /garage json-api ListKeys 2>/dev/null)" | jq -r "[.[] | select(.name == \"$app_name\") | .id][0]")
if [[ $app_access_key_id == "null" ]]; then
    echo "create access key for $app_name app"
    accessKey=$(kubectl exec $garage_pod -- /garage json-api CreateKey "{\"allow\": {},\"deny\": {},\"name\": \"$app_name\",\"neverExpires\": true}" 2>/dev/null | jq -r '.')
    app_access_key_id=$(echo $accessKey | jq -r ".accessKeyId")
    echo "access key:$app_access_key_id successful created"
fi

echo "apply access key on cluster"
app_secret_access_key=$(echo $(kubectl exec $garage_pod -- /garage json-api GetKeyInfo "{\"id\": \"$app_access_key_id\", \"showSecretKey\": true}" 2>/dev/null) | jq -r ".secretAccessKey")
kube_secret_result=$(kubectl create secret generic snapstash-s3 --from-literal=S3_ACCESS_KEY=$app_access_key_id --from-literal=S3_SECRET_KEY=$app_secret_access_key --dry-run=client -o yaml | kubectl apply -f -)
echo "$kube_secret_result"
if [[ $kube_secret_result == *"configured"*  ]];then
    if  kubectl get deploy snapstash-app &> /dev/null; then
        kubectl rollout restart deploy snapstash-app
        # check deployment status
        if ! kubectl rollout status deployment/snapstash-app --timeout=120s; then
            echo "snapstash-app deployment still not ready after 120s" >&2
            echo "current snapstash-app pods status:" >&2
            kubectl get pods -l app=snapstash-app >&2
            exit 1
        fi
        echo "snapstash-app deployment is ready"
    else
        echo "snapstash-app deployment not found yet, nothing to restart"
    fi
fi

if is_bucket=$(kubectl exec $garage_pod -- /garage json-api GetBucketInfo "{\"globalAlias\": \"$bucket_name\"}" 2>/dev/null); then
    echo "bucket found"
else
    echo "couldn't retrieve the bucket \"$bucket_name\""
    echo "create bucket \"$bucket_name\""
    bucket_info=$(kubectl exec $garage_pod --  /garage json-api CreateBucket "{\"globalAlias\": \"$bucket_name\" }" 2>/dev/null)
    bucket_id=$(echo $bucket_info | jq -r ".id")
    echo "bucket name:\"$bucket_name\" id:$bucket_id successful created"
    echo "give to access key app the rights on bucket"
    result=$(echo $(kubectl exec $garage_pod -- /garage json-api AllowBucketKey "{\"accessKeyId\": \"$app_access_key_id\",\"bucketId\": \"$bucket_id\",\"permissions\": {\"owner\": true,\"read\": true,\"write\": true}}" 2>/dev/null) | jq -r ".keys[].name")
    if [[ $result == $app_name ]]; then
        echo "permission successful granted"
    else
        exit 1
    fi
fi

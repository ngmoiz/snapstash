set -euo pipefail

garage_pod=$(kubectl get pods -l app=garage -o jsonpath='{.items[0].metadata.name}')
echo $garage_pod
bucket_name="images"
app_name="snapstash"
node_id=$(kubectl exec $garage_pod -- /garage json-api GetClusterStatus 2>/dev/null | jq -r '.nodes[0].id')
node_role=$(kubectl exec $garage_pod -- /garage json-api GetClusterStatus 2>/dev/null | jq -r '.nodes[0].role')
layout_version=$(($(kubectl exec $garage_pod -- /garage json-api GetClusterStatus 2>/dev/null | jq -r '.layoutVersion') + 1))

if [[ -n "$node_id" ]];then
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
        app_secret_access_key=$(echo $accessKey | jq -r ".secretAccessKey")
        kubectl create secret generic snapstash-s3 --from-literal=S3_ACCESS_KEY=$app_access_key_id --from-literal=S3_SECRET_KEY=$app_secret_access_key --dry-run=client -o yaml | kubectl apply -f -
        echo "access key:$app_access_key_id successful created"
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
fi

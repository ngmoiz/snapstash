import boto3
from botocore.exceptions import ClientError
import logging
import os
from dotenv import load_dotenv

load_dotenv()

s3 = boto3.client('s3', 
    aws_access_key_id=os.environ['S3_ACCESS_KEY'], 
    aws_secret_access_key=os.environ['S3_SECRET_KEY'],
    endpoint_url=os.environ['S3_ENDPOINT'],
    region_name=os.environ['S3_REGION'],
)

def is_bucket_exists(bucket_name: str = os.environ['S3_BUCKET']):
    """Check whether a bucket exists, using a HEAD request.

    Args:
        bucket_name (str): bucket to check. Defaults to the S3_BUCKET env var.

    Returns:
        bool: True if the bucket exists, False otherwise.
    """
    try:
        s3.head_bucket(Bucket=bucket_name)
        logging.info("Bucket %s exists", bucket_name)
    except ClientError as e:
        logging.warning(e)
        logging.warning("Bucket %s doesn't exist", bucket_name)
        return False
    return True

def create_bucket(bucket_name: str = os.environ['S3_BUCKET'], region: str = os.environ['S3_REGION']):
    """Create a bucket, adding a LocationConstraint for every region except us-east-1.

    Args:
        bucket_name (str): bucket to create. Defaults to the S3_BUCKET env var.
        region (str): target region. Defaults to the S3_REGION env var.

    Returns:
        bool: True if created, False on error.
    """
    try:
        bucket_config = {}
        if region != 'us-east-1':
            bucket_config['CreateBucketConfiguration'] = {'LocationConstraint': region}
        s3.create_bucket(Bucket=bucket_name, **bucket_config)
    except ClientError as e:
        logging.error(e)
        return False
    logging.info("Bucket %s created", bucket_name)
    return True

def upload_file(body, bucket_name, object_key, content_type):
    """Upload raw bytes to an S3 bucket as an object.

    Args:
        body (bytes): the file content to store.
        bucket_name (str): destination bucket.
        object_key (str): object name (key) under which to store the content.
        content_type (str): MIME type of the content (e.g. "image/png").

    Returns:
        bool: True if uploaded, False on error.
    """

    try:
        s3.put_object(Body=body, Bucket=bucket_name, Key=object_key, ContentType=content_type)
    except ClientError as e:
        logging.error(e)
        return False
    logging.info("Object %s successfully uploaded", object_key)
    return True

def get_file(bucket_name, object_key=None):
    """Fetch an object's bytes and content-type from an S3 bucket.

    Args:
        bucket_name (str): source bucket.
        object_key (str): object name (key) to fetch.

    Returns:
        tuple[bytes, str] | None: (body, content_type) if found, or None if the
        object does not exist (NoSuchKey). Other ClientErrors are re-raised.
    """

    try:
        response = s3.get_object(Bucket=bucket_name, Key=object_key)
        body = response['Body'].read()
        contentType = response['ContentType']
        logging.info("Got object '%s' from bucket '%s'.", object_key, bucket_name)
    except ClientError as e:
        logging.error(e)
        logging.info("Couldn't get object '%s' from bucket '%s'.", object_key, bucket_name)
        if e.response['Error']['Code'] == 'NoSuchKey':
            return None
        raise
    return body, contentType

if not is_bucket_exists():
    create_bucket()

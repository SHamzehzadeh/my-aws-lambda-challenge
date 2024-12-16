import json
from collections import Counter
import boto3

s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    Processes text from a POST request, extracts the top 10 most frequent words,
    saves them to a JSON file in S3, and returns a pre-signed URL for downloading.
    """
    try:
        # Get text from the POST request body
        text = json.loads(event['body'])['text']

        # Process the text
        words = text.lower().split()
        word_counts = Counter(words)
        top_10_words = dict(word_counts.most_common(10))

        # Save results to a JSON file in S3
        bucket_name = 'tech-chall-bucket' 
        file_name = 'top_10_words.json'
        s3.put_object(Bucket=bucket_name, Key=file_name, Body=json.dumps(top_10_words))

        # Generate pre-signed URL
        url = s3.generate_presigned_url('get_object',
                                        Params={'Bucket': bucket_name, 'Key': file_name},
                                        ExpiresIn=3600)  # URL valid for 1 hour

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Success!',
                'download_url': url
            })
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
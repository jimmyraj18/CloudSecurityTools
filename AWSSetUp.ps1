# Load AWS CLI Profile
$awsProfile = "your-aws-profile"
$awsRegion = "us-west-2"

# Ensure AWS CLI is installed
if (-not (Get-Command "aws" -ErrorAction SilentlyContinue)) {
    Write-Host "AWS CLI is not installed. Please install it first."
    exit 1
}

# Check for publicly accessible S3 Buckets
Write-Host "Checking for publicly accessible S3 buckets..." -ForegroundColor Cyan
$s3Buckets = aws s3api list-buckets --profile $awsProfile --region $awsRegion | ConvertFrom-Json

foreach ($bucket in $s3Buckets.Buckets) {
    $bucketName = $bucket.Name
    Write-Host "Checking bucket: $bucketName"

    # Check if the bucket is publicly accessible
    $bucketPolicy = aws s3api get-bucket-policy --bucket $bucketName --profile $awsProfile --region $awsRegion --output json 2>$null
    if ($bucketPolicy) {
        $policy = $bucketPolicy | ConvertFrom-Json
        if ($policy.Statement | Where-Object { $_.Principal -eq "*" -and $_.Effect -eq "Allow" }) {
            Write-Host "[ALERT] Bucket '$bucketName' is publicly accessible!" -ForegroundColor Red
        }
    }
    else {
        Write-Host "No bucket policy found for $bucketName."
    }
}

# Check for overly permissive IAM Policies
Write-Host "Checking for overly permissive IAM Policies..." -ForegroundColor Cyan
$iamPolicies = aws iam list-policies --scope Local --profile $awsProfile --region $awsRegion | ConvertFrom-Json

foreach ($policy in $iamPolicies.Policies) {
    $policyName = $policy.PolicyName
    Write-Host "Checking policy: $policyName"

    # Get the policy document
    $policyDocument = aws iam get-policy-version --policy-arn $policy.Arn --version-id $policy.DefaultVersionId --profile $awsProfile --region $awsRegion | ConvertFrom-Json
    $policyDoc = $policyDocument.PolicyVersion.Document

    # Check for wildcard "*" permissions (potentially dangerous)
    if ($policyDoc.Statement | Where-Object { $_.Action -contains "*" }) {
        Write-Host "[ALERT] Policy '$policyName' contains wildcard '*' actions!" -ForegroundColor Red
    }
}

Write-Host "Security Check Completed." -ForegroundColor Green

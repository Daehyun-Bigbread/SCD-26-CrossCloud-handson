#!/bin/bash
set -euo pipefail

###############################################################################
# Module 1 — S3 버킷 생성 + DataSync로 GCS → S3 전송
#
# 사용법:
#   chmod +x scripts/setup-module1-datasync.sh
#   ./scripts/setup-module1-datasync.sh
#
# 사전 요구사항:
#   - AWS CLI v2 설치 및 IAM 사용자로 로그인 (aws configure 완료)
#   - 리전: ap-northeast-2
#   - 진행자가 안내한 GCS 버킷 이름, HMAC Access Key, Secret Key
###############################################################################

REGION="ap-northeast-2"

echo "============================================"
echo "  Module 1 — GCS → S3 전송 (자동 구축)"
echo "============================================"
echo ""

# ─── 사용자 입력 ───────────────────────────────────────────────
read -rp "S3 버킷 이름 (예: scd26-handson-rag-docs-홍길동): " S3_BUCKET
read -rp "GCS 버킷 이름 (진행자가 안내한 값): " GCS_BUCKET
read -rp "GCS 폴더 경로 (기본값: /sample-docs/): " GCS_FOLDER
GCS_FOLDER="${GCS_FOLDER:-/sample-docs/}"
read -rp "HMAC Access Key (진행자가 안내한 값): " HMAC_ACCESS_KEY
read -rsp "HMAC Secret Key (진행자가 안내한 값): " HMAC_SECRET_KEY
echo ""

echo ""
echo "▶ 입력 확인"
echo "  S3 버킷:        $S3_BUCKET"
echo "  GCS 버킷:       $GCS_BUCKET"
echo "  GCS 폴더:       $GCS_FOLDER"
echo "  HMAC Access Key: ${HMAC_ACCESS_KEY:0:10}..."
echo ""
read -rp "위 정보가 맞습니까? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "취소되었습니다."
  exit 1
fi

# ─── Step 1: S3 버킷 생성 ──────────────────────────────────────
echo ""
echo "━━━ [1/4] S3 버킷 생성 ━━━"
aws s3api create-bucket \
  --bucket "$S3_BUCKET" \
  --region "$REGION" \
  --create-bucket-configuration LocationConstraint="$REGION" \
  --output text
echo "✓ S3 버킷 생성 완료: $S3_BUCKET"

# ─── Step 2: DataSync IAM 역할 생성 ────────────────────────────
echo ""
echo "━━━ [2/4] DataSync용 IAM 역할 생성 ━━━"
DATASYNC_ROLE_NAME="DataSyncS3Role-scd26-handson"

TRUST_POLICY=$(cat <<'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "datasync.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
)

S3_ACCESS_POLICY=$(cat <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads"
      ],
      "Resource": "arn:aws:s3:::${S3_BUCKET}"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:AbortMultipartUpload",
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:ListMultipartUploadParts",
        "s3:PutObject",
        "s3:GetObjectTagging",
        "s3:PutObjectTagging"
      ],
      "Resource": "arn:aws:s3:::${S3_BUCKET}/*"
    }
  ]
}
POLICY
)

DATASYNC_ROLE_ARN=$(aws iam create-role \
  --role-name "$DATASYNC_ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY" \
  --query 'Role.Arn' --output text 2>/dev/null) || \
DATASYNC_ROLE_ARN=$(aws iam get-role \
  --role-name "$DATASYNC_ROLE_NAME" \
  --query 'Role.Arn' --output text)

aws iam put-role-policy \
  --role-name "$DATASYNC_ROLE_NAME" \
  --policy-name "S3Access" \
  --policy-document "$S3_ACCESS_POLICY"

echo "✓ IAM 역할 생성 완료: $DATASYNC_ROLE_NAME"
echo "  IAM 역할 전파 대기 (10초)..."
sleep 10

# ─── Step 3: DataSync 위치 생성 (소스 + 대상) ──────────────────
echo ""
echo "━━━ [3/4] DataSync 위치 생성 ━━━"

echo "  소스 위치 생성 (GCS)..."
SOURCE_LOCATION_ARN=$(aws datasync create-location-object-storage \
  --server-hostname "storage.googleapis.com" \
  --server-protocol "HTTPS" \
  --server-port 443 \
  --bucket-name "$GCS_BUCKET" \
  --subdirectory "$GCS_FOLDER" \
  --access-key "$HMAC_ACCESS_KEY" \
  --secret-key "$HMAC_SECRET_KEY" \
  --region "$REGION" \
  --query 'LocationArn' --output text)
echo "  ✓ 소스 위치 (GCS): $GCS_BUCKET$GCS_FOLDER"

echo "  대상 위치 생성 (S3)..."
DEST_LOCATION_ARN=$(aws datasync create-location-s3 \
  --s3-bucket-arn "arn:aws:s3:::$S3_BUCKET" \
  --s3-config "BucketAccessRoleArn=$DATASYNC_ROLE_ARN" \
  --region "$REGION" \
  --query 'LocationArn' --output text)
echo "  ✓ 대상 위치 (S3): $S3_BUCKET"

# ─── Step 4: DataSync 태스크 생성 및 실행 ─────────────────────
echo ""
echo "━━━ [4/4] DataSync 태스크 생성 및 실행 ━━━"
TASK_ARN=$(aws datasync create-task \
  --source-location-arn "$SOURCE_LOCATION_ARN" \
  --destination-location-arn "$DEST_LOCATION_ARN" \
  --name "scd26-gcs-to-s3-transfer" \
  --options '{
    "VerifyMode": "ONLY_FILES_TRANSFERRED",
    "OverwriteMode": "ALWAYS",
    "Atime": "BEST_EFFORT",
    "Mtime": "PRESERVE",
    "PreserveDeletedFiles": "PRESERVE",
    "TransferMode": "ALL"
  }' \
  --task-mode "ENHANCED" \
  --region "$REGION" \
  --query 'TaskArn' --output text)
echo "  태스크 생성 완료"

echo "  전송 시작..."
EXECUTION_ARN=$(aws datasync start-task-execution \
  --task-arn "$TASK_ARN" \
  --region "$REGION" \
  --query 'TaskExecutionArn' --output text)

echo "  전송 완료 대기 중 (약 30초~1분)..."
while true; do
  STATUS=$(aws datasync describe-task-execution \
    --task-execution-arn "$EXECUTION_ARN" \
    --region "$REGION" \
    --query 'Status' --output text 2>/dev/null)
  if [[ "$STATUS" == "SUCCESS" ]]; then
    echo "✓ DataSync 전송 완료!"
    break
  elif [[ "$STATUS" == "ERROR" ]]; then
    echo "✗ DataSync 전송 실패. AWS 콘솔에서 로그를 확인하세요."
    exit 1
  fi
  echo "  상태: $STATUS ..."
  sleep 5
done

FILE_COUNT=$(aws s3 ls "s3://$S3_BUCKET/" --region "$REGION" | wc -l | tr -d ' ')
echo "  S3 버킷에 ${FILE_COUNT}개 파일 확인"

# ─── 완료 ─────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Module 1 완료!"
echo "============================================"
echo ""
echo "  생성된 리소스:"
echo "  ├─ S3 버킷: $S3_BUCKET (파일 ${FILE_COUNT}개)"
echo "  ├─ DataSync 태스크: scd26-gcs-to-s3-transfer"
echo "  ├─ DataSync 소스 위치: GCS ($GCS_BUCKET)"
echo "  └─ DataSync 대상 위치: S3 ($S3_BUCKET)"
echo ""
echo "  다음 단계:"
echo "  → Module 2 실행: ./scripts/setup-module2-bedrock-kb.sh"
echo "  → 또는 콘솔에서 Module 2 진행: docs/02-bedrock-kb-create.md"
echo ""

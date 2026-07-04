#!/bin/bash
set -euo pipefail

###############################################################################
# SCD-26 Cross-Cloud RAG 핸즈온 — AWS 리소스 정리 스크립트
#
# 사용법:
#   chmod +x scripts/cleanup-aws.sh
#   ./scripts/cleanup-aws.sh
#
# 삭제 순서 (의존성 고려):
#   1. Bedrock Knowledge Base (→ OpenSearch Serverless 자동 삭제)
#   2. DataSync 태스크 & 위치
#   3. S3 버킷 (객체 비우기 → 삭제)
#   4. IAM 역할
###############################################################################

# 리전: 환경변수 우선(CloudShell은 열린 리전을 자동 주입), 없으면 us-west-2(오레곤) 기본값.
#   강제 지정: REGION=ap-northeast-2 bash scripts/cleanup-aws.sh
REGION="${REGION:-${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-2}}}"

echo "============================================"
echo "  SCD-26 Cross-Cloud RAG 핸즈온 리소스 정리"
echo "============================================"
echo ""
echo "⚠ 이 스크립트는 핸즈온에서 생성한 모든 AWS 리소스를 삭제합니다."
read -rp "계속하시겠습니까? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "취소되었습니다."
  exit 0
fi

read -rp "S3 버킷 이름: " S3_BUCKET

# ─── Step 1: Bedrock Knowledge Base 삭제 ──────────────────────
echo ""
echo "━━━ [1/4] Bedrock Knowledge Base 삭제 ━━━"
KB_ID=$(aws bedrock-agent list-knowledge-bases \
  --region "$REGION" \
  --query 'knowledgeBaseSummaries[?name==`scd26-crosscloud-rag-kb`].knowledgeBaseId' \
  --output text 2>/dev/null)

if [[ -n "$KB_ID" && "$KB_ID" != "None" ]]; then
  DS_IDS=$(aws bedrock-agent list-data-sources \
    --knowledge-base-id "$KB_ID" \
    --region "$REGION" \
    --query 'dataSourceSummaries[].dataSourceId' \
    --output text 2>/dev/null)

  for DS_ID in $DS_IDS; do
    echo "  데이터 소스 삭제: $DS_ID"
    aws bedrock-agent delete-data-source \
      --knowledge-base-id "$KB_ID" \
      --data-source-id "$DS_ID" \
      --region "$REGION" \
      --output text > /dev/null 2>&1 || true
  done

  echo "  Knowledge Base 삭제: $KB_ID"
  aws bedrock-agent delete-knowledge-base \
    --knowledge-base-id "$KB_ID" \
    --region "$REGION" \
    --output text > /dev/null 2>&1
  echo "✓ Knowledge Base 삭제 완료 (OpenSearch Serverless도 자동 삭제됨)"
else
  echo "  Knowledge Base를 찾을 수 없습니다. 건너뜁니다."
fi

# ─── Step 2: DataSync 태스크 삭제 ─────────────────────────────
echo ""
echo "━━━ [2/4] DataSync 태스크 & 위치 삭제 ━━━"
TASK_ARNS=$(aws datasync list-tasks \
  --region "$REGION" \
  --query 'Tasks[?Name==`scd26-gcs-to-s3-transfer`].TaskArn' \
  --output text 2>/dev/null)

for TASK_ARN in $TASK_ARNS; do
  echo "  태스크 삭제: $TASK_ARN"
  aws datasync delete-task \
    --task-arn "$TASK_ARN" \
    --region "$REGION" \
    --output text > /dev/null 2>&1 || true
done

LOCATION_ARNS=$(aws datasync list-locations \
  --region "$REGION" \
  --query 'Locations[].LocationArn' \
  --output text 2>/dev/null)

for LOC_ARN in $LOCATION_ARNS; do
  LOC_URI=$(aws datasync describe-location-object-storage \
    --location-arn "$LOC_ARN" \
    --region "$REGION" \
    --query 'LocationUri' --output text 2>/dev/null || \
    aws datasync describe-location-s3 \
    --location-arn "$LOC_ARN" \
    --region "$REGION" \
    --query 'LocationUri' --output text 2>/dev/null || echo "")

  if [[ "$LOC_URI" == *"storage.googleapis.com"* ]] || [[ "$LOC_URI" == *"$S3_BUCKET"* ]]; then
    echo "  위치 삭제: $LOC_URI"
    aws datasync delete-location \
      --location-arn "$LOC_ARN" \
      --region "$REGION" \
      --output text > /dev/null 2>&1 || true
  fi
done
echo "✓ DataSync 리소스 삭제 완료"

# ─── Step 3: S3 버킷 삭제 ─────────────────────────────────────
echo ""
echo "━━━ [3/4] S3 버킷 삭제 ━━━"
if aws s3api head-bucket --bucket "$S3_BUCKET" --region "$REGION" 2>/dev/null; then
  echo "  버킷 비우는 중..."
  aws s3 rm "s3://$S3_BUCKET" --recursive --region "$REGION" > /dev/null 2>&1
  echo "  버킷 삭제 중..."
  aws s3api delete-bucket --bucket "$S3_BUCKET" --region "$REGION"
  echo "✓ S3 버킷 삭제 완료: $S3_BUCKET"
else
  echo "  S3 버킷을 찾을 수 없습니다. 건너뜁니다."
fi

# ─── Step 4: IAM 역할 삭제 ────────────────────────────────────
echo ""
echo "━━━ [4/4] IAM 역할 삭제 ━━━"
for ROLE_NAME in "DataSyncS3Role-scd26-handson" "AmazonBedrockKBRole-scd26-handson"; do
  if aws iam get-role --role-name "$ROLE_NAME" > /dev/null 2>&1; then
    POLICIES=$(aws iam list-role-policies \
      --role-name "$ROLE_NAME" \
      --query 'PolicyNames' --output text 2>/dev/null)
    for POLICY in $POLICIES; do
      aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "$POLICY"
    done
    aws iam delete-role --role-name "$ROLE_NAME"
    echo "✓ IAM 역할 삭제: $ROLE_NAME"
  fi
done

# ─── 완료 ─────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  리소스 정리 완료!"
echo "============================================"
echo ""
echo "  삭제된 리소스:"
echo "  ├─ Bedrock Knowledge Base + OpenSearch Serverless"
echo "  ├─ DataSync 태스크 + 위치"
echo "  ├─ S3 버킷: $S3_BUCKET"
echo "  └─ IAM 역할"
echo ""
echo "  ▶ AWS 콘솔에서 OpenSearch Serverless 컬렉션이"
echo "    삭제되었는지 최종 확인하세요."
echo ""

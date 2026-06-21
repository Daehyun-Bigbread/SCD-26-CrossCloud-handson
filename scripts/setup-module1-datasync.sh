#!/bin/bash
set -euo pipefail

###############################################################################
# Module 1 — S3 버킷 생성 + DataSync로 GCS → S3 전송 (멱등 / idempotent)
#
# 이 스크립트는 "있으면 재사용, 없으면 생성"하는 멱등 스크립트입니다.
#   - 아무것도 없으면 → 전부 새로 만들고 전송까지 실행
#   - 일부만 있거나 잘못 만들다 멈췄으면 → 있는 건 재사용, 빠진 것만 채워 정상화
#   - 여러 번 실행해도 리소스가 중복 생성되지 않음
# 마지막에 [생성됨 / 재사용됨] 목록과 전송 결과를 리포트합니다.
#
# 사용법:
#   bash scripts/setup-module1-datasync.sh
#
# 사전 요구사항:
#   - AWS CLI v2 + 인증 (AWS CloudShell이면 자동, 로컬이면 aws configure 완료)
#   - 리전: ap-northeast-2 (스크립트가 항상 서울에 리소스를 생성)
#   - 진행자가 안내한 GCS 버킷 이름, HMAC Access Key, Secret Key
#   - IAM 권한: s3:CreateBucket, s3:ListBucket, s3:HeadBucket,
#               iam:CreateRole, iam:GetRole, iam:PutRolePolicy, iam:PassRole,
#               datasync:*
#     (간단하게는 AmazonS3FullAccess + AWSDataSyncFullAccess + IAMFullAccess)
###############################################################################

REGION="ap-northeast-2"
DATASYNC_ROLE_NAME="DataSyncS3Role-scd26-handson"
TASK_NAME="scd26-gcs-to-s3-transfer"

# 생성/재사용 추적
CREATED=()
REUSED=()

echo "============================================"
echo "  Module 1 — GCS → S3 전송 (멱등 자동 구축)"
echo "============================================"
echo ""

# ─── 사용자 입력 ───────────────────────────────────────────────
echo "※ S3 버킷 이름: 소문자 영문/숫자/하이픈만 사용, 전 세계에서 고유해야 합니다."
read -rp "S3 버킷 이름 (예: scd26-handson-rag-docs-gildong): " S3_BUCKET
read -rp "GCS 버킷 이름 (기본값: scd26-crosscloud-handson): " GCS_BUCKET
GCS_BUCKET="${GCS_BUCKET:-scd26-crosscloud-handson}"
read -rp "GCS 폴더 경로 (기본값: /sample-docs/): " GCS_FOLDER
GCS_FOLDER="${GCS_FOLDER:-/sample-docs/}"
read -rp "HMAC Access Key (진행자가 안내한 값): " HMAC_ACCESS_KEY
read -rsp "HMAC Secret Key (진행자가 안내한 값): " HMAC_SECRET_KEY
echo ""

# GCS 폴더 경로 정규화 (앞/뒤 슬래시 보장)
case "$GCS_FOLDER" in /*) ;; *) GCS_FOLDER="/$GCS_FOLDER" ;; esac
case "$GCS_FOLDER" in */) ;; *) GCS_FOLDER="$GCS_FOLDER/" ;; esac

echo ""
echo "▶ 입력 확인"
echo "  S3 버킷:         $S3_BUCKET"
echo "  GCS 버킷:        $GCS_BUCKET"
echo "  GCS 폴더:        $GCS_FOLDER"
echo "  HMAC Access Key: ${HMAC_ACCESS_KEY:0:10}..."
echo ""
read -rp "위 정보가 맞습니까? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "취소되었습니다."
  exit 1
fi

# ─── Step 1: S3 버킷 확인/생성 ─────────────────────────────────
echo ""
echo "━━━ [1/4] S3 버킷 확인/생성 ━━━"
if aws s3api head-bucket --bucket "$S3_BUCKET" --region "$REGION" 2>/dev/null; then
  echo "✓ 이미 존재하는 버킷 재사용: $S3_BUCKET"
  REUSED+=("S3 버킷: $S3_BUCKET")
else
  if CREATE_OUT=$(aws s3api create-bucket \
        --bucket "$S3_BUCKET" \
        --region "$REGION" \
        --create-bucket-configuration LocationConstraint="$REGION" \
        --output text 2>&1); then
    echo "＋ S3 버킷 생성 완료: $S3_BUCKET"
    CREATED+=("S3 버킷: $S3_BUCKET")
  elif echo "$CREATE_OUT" | grep -q "BucketAlreadyOwnedByYou"; then
    echo "✓ 이미 소유한 버킷 재사용: $S3_BUCKET"
    REUSED+=("S3 버킷: $S3_BUCKET")
  elif echo "$CREATE_OUT" | grep -q "BucketAlreadyExists"; then
    echo "✗ 버킷 이름 '$S3_BUCKET' 이 다른 계정에서 사용 중입니다. 다른 이름으로 다시 실행하세요."
    exit 1
  else
    echo "✗ S3 버킷 생성 실패:"
    echo "$CREATE_OUT"
    exit 1
  fi
fi

# ─── Step 2: DataSync IAM 역할 확인/생성 ───────────────────────
echo ""
echo "━━━ [2/4] DataSync IAM 역할 확인/생성 ━━━"

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

ROLE_WAS_CREATED=false
if aws iam get-role --role-name "$DATASYNC_ROLE_NAME" >/dev/null 2>&1; then
  DATASYNC_ROLE_ARN=$(aws iam get-role --role-name "$DATASYNC_ROLE_NAME" \
    --query 'Role.Arn' --output text)
  echo "✓ 이미 존재하는 IAM 역할 재사용: $DATASYNC_ROLE_NAME"
  REUSED+=("IAM 역할: $DATASYNC_ROLE_NAME")
else
  DATASYNC_ROLE_ARN=$(aws iam create-role \
    --role-name "$DATASYNC_ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --query 'Role.Arn' --output text)
  echo "＋ IAM 역할 생성 완료: $DATASYNC_ROLE_NAME"
  CREATED+=("IAM 역할: $DATASYNC_ROLE_NAME")
  ROLE_WAS_CREATED=true
fi

# S3 접근 정책은 항상 최신 상태로 보장 (put-role-policy = 멱등 덮어쓰기)
aws iam put-role-policy \
  --role-name "$DATASYNC_ROLE_NAME" \
  --policy-name "S3Access" \
  --policy-document "$S3_ACCESS_POLICY"
echo "  S3 접근 정책 적용 완료"

if [[ "$ROLE_WAS_CREATED" == true ]]; then
  echo "  IAM 역할 전파 대기 (10초)..."
  sleep 10
fi

# ─── Step 3: DataSync 위치 확인/생성 (소스 + 대상) ─────────────
echo ""
echo "━━━ [3/4] DataSync 위치 확인/생성 ━━━"

# 소스 위치 (GCS, object storage) — LocationUri로 기존 항목 탐색
SRC_MATCH="storage.googleapis.com/${GCS_BUCKET}"
SOURCE_LOCATION_ARN=$(aws datasync list-locations --region "$REGION" \
  --query "Locations[?contains(LocationUri, '${SRC_MATCH}')].LocationArn | [0]" \
  --output text 2>/dev/null || true)
if [[ -n "$SOURCE_LOCATION_ARN" && "$SOURCE_LOCATION_ARN" != "None" ]]; then
  echo "✓ 기존 소스 위치(GCS) 재사용"
  REUSED+=("DataSync 소스 위치(GCS): $GCS_BUCKET")
else
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
  echo "＋ 소스 위치(GCS) 생성: $GCS_BUCKET$GCS_FOLDER"
  CREATED+=("DataSync 소스 위치(GCS): $GCS_BUCKET")
fi

# 대상 위치 (S3) — LocationUri로 기존 항목 탐색
DEST_MATCH="s3://${S3_BUCKET}/"
DEST_LOCATION_ARN=$(aws datasync list-locations --region "$REGION" \
  --query "Locations[?contains(LocationUri, '${DEST_MATCH}')].LocationArn | [0]" \
  --output text 2>/dev/null || true)
if [[ -n "$DEST_LOCATION_ARN" && "$DEST_LOCATION_ARN" != "None" ]]; then
  echo "✓ 기존 대상 위치(S3) 재사용"
  REUSED+=("DataSync 대상 위치(S3): $S3_BUCKET")
else
  DEST_LOCATION_ARN=$(aws datasync create-location-s3 \
    --s3-bucket-arn "arn:aws:s3:::$S3_BUCKET" \
    --s3-config "BucketAccessRoleArn=$DATASYNC_ROLE_ARN" \
    --region "$REGION" \
    --query 'LocationArn' --output text)
  echo "＋ 대상 위치(S3) 생성: $S3_BUCKET"
  CREATED+=("DataSync 대상 위치(S3): $S3_BUCKET")
fi

# ─── Step 4: DataSync 태스크 확인/생성 ────────────────────────
echo ""
echo "━━━ [4/4] DataSync 태스크 확인/생성 ━━━"
TASK_ARN=$(aws datasync list-tasks --region "$REGION" \
  --query "Tasks[?Name=='${TASK_NAME}'].TaskArn | [0]" \
  --output text 2>/dev/null || true)
if [[ -n "$TASK_ARN" && "$TASK_ARN" != "None" ]]; then
  echo "✓ 기존 태스크 재사용: $TASK_NAME"
  REUSED+=("DataSync 태스크: $TASK_NAME")
else
  TASK_ARN=$(aws datasync create-task \
    --source-location-arn "$SOURCE_LOCATION_ARN" \
    --destination-location-arn "$DEST_LOCATION_ARN" \
    --name "$TASK_NAME" \
    --options '{
      "VerifyMode": "ONLY_FILES_TRANSFERRED",
      "OverwriteMode": "ALWAYS",
      "Atime": "BEST_EFFORT",
      "Mtime": "PRESERVE",
      "PreserveDeletedFiles": "PRESERVE",
      "TransferMode": "ALL",
      "ObjectTags": "NONE"
    }' \
    --task-mode "ENHANCED" \
    --region "$REGION" \
    --query 'TaskArn' --output text)
  echo "＋ 태스크 생성 완료: $TASK_NAME"
  CREATED+=("DataSync 태스크: $TASK_NAME")
fi

# ─── 전송 실행 (멱등: 매 실행마다 최신 상태로 재동기화) ────────
echo ""
echo "━━━ 전송 실행 ━━━"
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

# ─── 완료 리포트 ──────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Module 1 완료!"
echo "============================================"
echo ""
if [[ ${#CREATED[@]} -gt 0 ]]; then
  echo "  [새로 생성됨]"
  for item in "${CREATED[@]}"; do echo "  ＋ $item"; done
else
  echo "  [새로 생성됨] 없음 — 모든 리소스가 이미 구성되어 있었습니다"
fi
echo ""
if [[ ${#REUSED[@]} -gt 0 ]]; then
  echo "  [기존 재사용됨]"
  for item in "${REUSED[@]}"; do echo "  ✓ $item"; done
fi
echo ""
echo "  S3 버킷 파일 수: ${FILE_COUNT}개"
echo ""
echo "  다음 단계:"
echo "  → Module 2 실행: bash scripts/setup-module2-bedrock-kb.sh"
echo "  → 또는 콘솔에서 Module 2 진행: docs/02-bedrock-kb-create.md"
echo ""

#!/bin/bash
set -euo pipefail

###############################################################################
# Module 1 — S3 버킷 생성 + DataSync로 GCS → S3 전송 (멱등 / idempotent)
#
# 이 스크립트는 "있으면 재사용, 없으면 생성"하는 멱등 스크립트입니다.
#   - 태스크가 이미 있으면 → [확인 모드]: 현재 구축 상태를 보여주고, 원하면 전송만 다시 실행
#   - 태스크가 없으면      → [구축 모드]: S3 버킷 이름(+필요 시 HMAC 키)만 입력받아 전부 구축
#   - 여러 번 실행해도 리소스가 중복 생성되지 않음
# 마지막에 [생성됨 / 재사용됨] 목록과 전송 결과를 리포트합니다.
#
# 사용법:
#   bash scripts/setup-module1-datasync.sh
#
# 사전 요구사항:
#   - AWS CLI v2 + 인증 (AWS CloudShell이면 자동, 로컬이면 aws configure 완료)
#   - 리전: us-west-2 (오레곤) — Workshop Studio 계정 기본. CloudShell 리전을 자동 사용
#   - GCS 버킷/폴더는 공통값이라 스크립트에 하드코딩됨 (scd26-crosscloud-handson:/sample-docs/)
#   - HMAC Access/Secret Key는 소스 위치를 새로 만들 때만 입력받음 (진행자가 안내)
#   - IAM 권한: s3:CreateBucket, s3:ListBucket, s3:HeadBucket,
#               iam:CreateRole, iam:GetRole, iam:PutRolePolicy, iam:PassRole,
#               datasync:*
#     (간단하게는 AmazonS3FullAccess + AWSDataSyncFullAccess + IAMFullAccess)
###############################################################################

# 리전: 환경변수 우선(CloudShell은 열린 리전을 자동 주입), 없으면 us-west-2(오레곤) 기본값.
#   - Workshop Studio 계정 → us-west-2 CloudShell에서 실행하면 자동으로 us-west-2
#   - 강제 지정: REGION=ap-northeast-2 bash scripts/setup-module1-datasync.sh
REGION="${REGION:-${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-2}}}"
DATASYNC_ROLE_NAME="DataSyncS3Role-scd26-handson"
TASK_NAME="scd26-gcs-to-s3-transfer"

# 생성/재사용 추적
CREATED=()
REUSED=()

echo "============================================"
echo "  Module 1 — GCS → S3 전송 (멱등 자동 구축)"
echo "============================================"
echo ""

# ─── 공통 고정값 (모든 참가자 동일 → 하드코딩) ─────────────────
GCS_BUCKET="scd26-crosscloud-handson"
GCS_FOLDER="/sample-docs/"

# ─── 구축 상태 확인: 태스크가 이미 있으면 '확인 모드' ──────────
echo "▶ 기존 구축 상태 확인 중 (리전: $REGION)..."
TASK_ARN=$(aws datasync list-tasks --region "$REGION" \
  --query "Tasks[?Name=='${TASK_NAME}'].TaskArn | [0]" \
  --output text 2>/dev/null || true)

if [[ -n "$TASK_ARN" && "$TASK_ARN" != "None" ]]; then
  # ===== 확인 모드 (이미 구축됨) =====
  MODE="check"
  SOURCE_LOCATION_ARN=$(aws datasync describe-task --task-arn "$TASK_ARN" --region "$REGION" \
    --query 'SourceLocationArn' --output text)
  DEST_LOCATION_ARN=$(aws datasync describe-task --task-arn "$TASK_ARN" --region "$REGION" \
    --query 'DestinationLocationArn' --output text)
  SRC_URI=$(aws datasync describe-location-object-storage --location-arn "$SOURCE_LOCATION_ARN" \
    --region "$REGION" --query 'LocationUri' --output text 2>/dev/null || echo "unknown")
  DEST_URI=$(aws datasync describe-location-s3 --location-arn "$DEST_LOCATION_ARN" \
    --region "$REGION" --query 'LocationUri' --output text 2>/dev/null || echo "unknown")
  _tmp="${DEST_URI#s3://}"; S3_BUCKET="${_tmp%%/*}"

  echo ""
  echo "✓ 이미 구축되어 있습니다 (확인 모드)"
  echo "  ├─ DataSync 태스크: $TASK_NAME"
  echo "  ├─ 소스 위치(GCS):  $SRC_URI"
  echo "  ├─ 대상 위치(S3):   $DEST_URI"
  echo "  └─ S3 버킷:         $S3_BUCKET"

  # 소스 위치 오구성 경고 (GCS 버킷 이름이 아닌 값이 들어간 경우)
  if [[ "$SRC_URI" != *"storage.googleapis.com/${GCS_BUCKET}/"* ]]; then
    echo ""
    echo "  ⚠ 소스 위치가 GCS 버킷 '${GCS_BUCKET}'(이)가 아닙니다. 재실행 시 NoSuchBucket으로 실패할 수 있어요."
    echo "    콘솔에서 소스 위치를 삭제 후 올바른 버킷으로 다시 만드세요."
  fi

  REUSED+=("DataSync 태스크: $TASK_NAME")
  REUSED+=("DataSync 소스 위치(GCS)")
  REUSED+=("DataSync 대상 위치(S3): $S3_BUCKET")
  REUSED+=("S3 버킷: $S3_BUCKET")

  echo ""
  read -rp "전송을 다시 실행할까요? (y/n): " RUN
  if [[ "$RUN" != "y" && "$RUN" != "Y" ]]; then
    echo "확인만 하고 종료합니다. (전송 미실행)"
    exit 0
  fi
else
  # ===== 구축 모드 (신규/부분 구축) =====
  MODE="build"
  echo "  → 태스크가 없습니다. 신규 구축을 진행합니다."
  echo ""
  echo "※ S3 버킷 이름: 소문자 영문/숫자/하이픈만 사용, 전 세계에서 고유해야 합니다."
  while true; do
    read -rp "S3 버킷 이름 (예: scd26-handson-rag-docs-gildong): " S3_BUCKET
    if [[ -z "$S3_BUCKET" ]]; then
      echo "  ✗ 버킷 이름은 필수입니다. 다시 입력하세요."
    elif [[ ! "$S3_BUCKET" =~ ^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$ ]]; then
      echo "  ✗ 형식 오류: 소문자·숫자·하이픈만, 3~63자, 처음/끝은 영숫자. 다시 입력하세요."
    else
      break
    fi
  done
  echo ""
  echo "▶ 입력 확인"
  echo "  리전:     $REGION"
  echo "  S3 버킷:  $S3_BUCKET"
  echo "  GCS 소스: storage.googleapis.com/$GCS_BUCKET$GCS_FOLDER (고정)"
  read -rp "위 정보가 맞습니까? (y/n): " CONFIRM
  if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "취소되었습니다."
    exit 1
  fi
fi

# ═══ 신규/부분 구축일 때만 리소스 생성 (확인 모드는 전체 건너뜀) ═══
if [[ "$MODE" == "build" ]]; then

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
  # 소스 위치가 없을 때만 HMAC 키를 입력받아 생성 (이미 있으면 물어보지 않음)
  echo "  소스 위치(GCS)가 없어 새로 만듭니다. HMAC 키를 입력하세요."
  while true; do
    read -rp "  HMAC Access Key (진행자가 안내한 값): " HMAC_ACCESS_KEY
    [[ -n "$HMAC_ACCESS_KEY" ]] && break
    echo "  ✗ Access Key는 필수입니다. 다시 입력하세요."
  done
  while true; do
    read -rsp "  HMAC Secret Key (진행자가 안내한 값): " HMAC_SECRET_KEY
    echo ""
    [[ -n "$HMAC_SECRET_KEY" ]] && break
    echo "  ✗ Secret Key는 필수입니다. 다시 입력하세요."
  done
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

fi  # ═══ end build mode ═══

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

FILE_COUNT=$(aws s3api list-objects-v2 --bucket "$S3_BUCKET" --region "$REGION" \
  --query 'length(Contents)' --output text 2>/dev/null || echo 0)
[[ "$FILE_COUNT" == "None" || -z "$FILE_COUNT" ]] && FILE_COUNT=0
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

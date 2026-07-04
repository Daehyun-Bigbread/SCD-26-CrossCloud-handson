#!/bin/bash
set -euo pipefail

###############################################################################
# Module 2 — Bedrock Knowledge Base 생성 + 데이터 소스 동기화
#
# 사용법:
#   chmod +x scripts/setup-module2-bedrock-kb.sh
#   ./scripts/setup-module2-bedrock-kb.sh
#
# 사전 요구사항:
#   - AWS CLI v2 (AWS CloudShell이면 자동 준비됨)
#   - 리전: us-west-2 (오레곤) — Workshop Studio 계정 기본. CloudShell 리전을 자동 사용
#   - Module 1 완료 (S3 버킷에 문서가 있어야 함)
#   - Bedrock 모델 액세스 승인 완료 (Titan Embeddings V2)
###############################################################################

# 리전: 환경변수 우선(CloudShell은 열린 리전을 자동 주입), 없으면 us-west-2(오레곤) 기본값.
#   강제 지정: REGION=ap-northeast-2 bash scripts/setup-module2-bedrock-kb.sh
REGION="${REGION:-${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-2}}}"

KB_NAME="scd26-crosscloud-rag-kb"
DS_NAME="s3-synced-docs"

# 생성/재사용 추적 (멱등)
CREATED=()
REUSED=()

echo "============================================"
echo "  Module 2 — Bedrock Knowledge Base 생성"
echo "============================================"
echo ""

# ─── 사용자 입력 ───────────────────────────────────────────────
while true; do
  read -rp "S3 버킷 이름 (Module 1에서 생성한 버킷): " S3_BUCKET
  [[ -n "$S3_BUCKET" ]] && break
  echo "  ✗ 버킷 이름은 필수입니다. 다시 입력하세요."
done

# S3 버킷에 파일이 있는지 확인
FILE_COUNT=$(aws s3 ls "s3://$S3_BUCKET/" --region "$REGION" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$FILE_COUNT" -eq 0 ]]; then
  echo "✗ S3 버킷 '$S3_BUCKET'에 파일이 없습니다."
  echo "  Module 1을 먼저 실행하세요: ./scripts/setup-module1-datasync.sh"
  exit 1
fi
echo "  ✓ S3 버킷 확인: ${FILE_COUNT}개 파일"
echo ""

# ─── Step 1: Bedrock KB용 IAM 역할 생성 ───────────────────────
echo "━━━ [1/4] Bedrock KB용 IAM 역할 생성 ━━━"

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
KB_ROLE_NAME="AmazonBedrockKBRole-scd26-handson"

KB_TRUST_POLICY=$(cat <<'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "bedrock.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
)

if aws iam get-role --role-name "$KB_ROLE_NAME" >/dev/null 2>&1; then
  KB_ROLE_ARN=$(aws iam get-role --role-name "$KB_ROLE_NAME" --query 'Role.Arn' --output text)
  echo "✓ 이미 존재하는 IAM 역할 재사용: $KB_ROLE_NAME"
  REUSED+=("IAM 역할: $KB_ROLE_NAME")
  KB_ROLE_WAS_CREATED=false
else
  KB_ROLE_ARN=$(aws iam create-role \
    --role-name "$KB_ROLE_NAME" \
    --assume-role-policy-document "$KB_TRUST_POLICY" \
    --query 'Role.Arn' --output text)
  echo "＋ IAM 역할 생성 완료: $KB_ROLE_NAME"
  CREATED+=("IAM 역할: $KB_ROLE_NAME")
  KB_ROLE_WAS_CREATED=true
fi

KB_S3_POLICY=$(cat <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::${S3_BUCKET}",
        "arn:aws:s3:::${S3_BUCKET}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": ["bedrock:InvokeModel"],
      "Resource": "arn:aws:bedrock:${REGION}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  ]
}
POLICY
)

aws iam put-role-policy \
  --role-name "$KB_ROLE_NAME" \
  --policy-name "BedrockKBAccess" \
  --policy-document "$KB_S3_POLICY"

KB_AOSS_POLICY=$(cat <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["aoss:APIAccessAll"],
      "Resource": "arn:aws:aoss:${REGION}:${ACCOUNT_ID}:collection/*"
    }
  ]
}
POLICY
)

aws iam put-role-policy \
  --role-name "$KB_ROLE_NAME" \
  --policy-name "BedrockKBAOSS" \
  --policy-document "$KB_AOSS_POLICY"

echo "  S3/Bedrock/AOSS 접근 정책 적용 완료"
if [[ "$KB_ROLE_WAS_CREATED" == true ]]; then
  echo "  IAM 역할 전파 대기 (15초)..."
  sleep 15
fi

# ─── Step 2: Knowledge Base 생성 ──────────────────────────────
echo ""
echo "━━━ [2/4] Knowledge Base 생성 (3~5분 소요) ━━━"

# 기존 KB가 있으면 재사용 (이름으로 탐색)
KB_ID=$(aws bedrock-agent list-knowledge-bases --region "$REGION" \
  --query "knowledgeBaseSummaries[?name=='${KB_NAME}'].knowledgeBaseId | [0]" \
  --output text 2>/dev/null || true)

if [[ -n "$KB_ID" && "$KB_ID" != "None" ]]; then
  echo "✓ 이미 존재하는 Knowledge Base 재사용: $KB_NAME (ID: $KB_ID)"
  REUSED+=("Knowledge Base: $KB_NAME")
else
  KB_ID=""
  KB_RESULT=$(aws bedrock-agent create-knowledge-base \
    --name "$KB_NAME" \
    --description "Cross-Cloud RAG 핸즈온 - GCS에서 동기화한 문서 기반 Knowledge Base" \
    --role-arn "$KB_ROLE_ARN" \
    --knowledge-base-configuration '{
      "type": "VECTOR",
      "vectorKnowledgeBaseConfiguration": {
        "embeddingModelArn": "arn:aws:bedrock:'"$REGION"'::foundation-model/amazon.titan-embed-text-v2:0",
        "embeddingModelConfiguration": {
          "bedrockEmbeddingModelConfiguration": {
            "embeddingDataType": "FLOAT32",
            "dimensions": 1024
          }
        }
      }
    }' \
    --storage-configuration '{
      "type": "OPENSEARCH_SERVERLESS",
      "opensearchServerlessConfiguration": {
        "collectionArn": "auto",
        "fieldMapping": {
          "metadataField": "AMAZON_BEDROCK_METADATA",
          "textField": "AMAZON_BEDROCK_TEXT",
          "vectorField": "bedrock-knowledge-base-default-vector"
        },
        "vectorIndexName": "bedrock-knowledge-base-default-index"
      }
    }' \
    --region "$REGION" \
    --output json 2>&1)

  KB_ID=$(echo "$KB_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['knowledgeBase']['knowledgeBaseId'])" 2>/dev/null)
  [[ -n "$KB_ID" ]] && CREATED+=("Knowledge Base: $KB_NAME")
fi

if [[ -z "$KB_ID" ]]; then
  echo ""
  echo "⚠ Knowledge Base CLI 자동 생성에 실패했습니다."
  echo "  (OpenSearch Serverless Quick Create는 CLI 지원이 제한적일 수 있습니다)"
  echo ""
  echo "  ▶ AWS 콘솔에서 수동으로 생성하세요:"
  echo "    1. Amazon Bedrock → 지식 기반 → 지식 기반 생성"
  echo "    2. 이름: scd26-crosscloud-rag-kb"
  echo "    3. 데이터 소스: S3 → s3://$S3_BUCKET/"
  echo "    4. 임베딩 모델: Titan Text Embeddings V2"
  echo "    5. 벡터 저장소: 새로운 벡터 저장소 빠른 생성 → OpenSearch Serverless"
  echo ""
  echo "  자세한 안내: docs/02-bedrock-kb-create.md"
  exit 0
fi

echo "  KB 생성 시작 (ID: $KB_ID)"
echo "  ACTIVE 상태 대기 중..."
while true; do
  KB_STATUS=$(aws bedrock-agent get-knowledge-base \
    --knowledge-base-id "$KB_ID" \
    --region "$REGION" \
    --query 'knowledgeBase.status' --output text 2>/dev/null)
  if [[ "$KB_STATUS" == "ACTIVE" ]]; then
    echo "✓ Knowledge Base 생성 완료!"
    break
  elif [[ "$KB_STATUS" == "FAILED" ]]; then
    echo "✗ Knowledge Base 생성 실패. AWS 콘솔에서 확인하세요."
    exit 1
  fi
  echo "  상태: $KB_STATUS ..."
  sleep 10
done

# ─── Step 3: 데이터 소스 추가 ─────────────────────────────────
echo ""
echo "━━━ [3/4] 데이터 소스 추가 ━━━"
DS_ID=$(aws bedrock-agent list-data-sources \
  --knowledge-base-id "$KB_ID" --region "$REGION" \
  --query "dataSourceSummaries[?name=='${DS_NAME}'].dataSourceId | [0]" \
  --output text 2>/dev/null || true)

if [[ -n "$DS_ID" && "$DS_ID" != "None" ]]; then
  echo "✓ 이미 존재하는 데이터 소스 재사용: $DS_NAME"
  REUSED+=("데이터 소스: $DS_NAME")
else
  DS_ID=$(aws bedrock-agent create-data-source \
    --knowledge-base-id "$KB_ID" \
    --name "$DS_NAME" \
    --data-source-configuration '{
      "type": "S3",
      "s3Configuration": {
        "bucketArn": "arn:aws:s3:::'"$S3_BUCKET"'"
      }
    }' \
    --region "$REGION" \
    --query 'dataSource.dataSourceId' --output text)
  echo "＋ 데이터 소스 추가 완료: $DS_NAME"
  CREATED+=("데이터 소스: $DS_NAME")
fi

# ─── Step 4: 데이터 소스 동기화 ───────────────────────────────
echo ""
echo "━━━ [4/4] 데이터 소스 동기화 (3~5분 소요) ━━━"
aws bedrock-agent start-ingestion-job \
  --knowledge-base-id "$KB_ID" \
  --data-source-id "$DS_ID" \
  --region "$REGION" \
  --output text > /dev/null

echo "  동기화 진행 중..."
while true; do
  SYNC_STATUS=$(aws bedrock-agent list-ingestion-jobs \
    --knowledge-base-id "$KB_ID" \
    --data-source-id "$DS_ID" \
    --region "$REGION" \
    --query 'ingestionJobSummaries[0].status' --output text 2>/dev/null)
  if [[ "$SYNC_STATUS" == "COMPLETE" ]]; then
    echo "✓ 데이터 소스 동기화 완료!"
    break
  elif [[ "$SYNC_STATUS" == "FAILED" ]]; then
    echo "✗ 동기화 실패. AWS 콘솔에서 확인하세요."
    exit 1
  fi
  echo "  동기화 상태: $SYNC_STATUS ..."
  sleep 10
done

# ─── 완료 ─────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Module 2 완료!"
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
  echo ""
fi
echo "  생성된 리소스:"
echo "  ├─ Knowledge Base: $KB_NAME (ID: $KB_ID)"
echo "  ├─ 데이터 소스: $DS_NAME (S3: $S3_BUCKET)"
echo "  └─ OpenSearch Serverless: 자동 생성됨"
echo ""
echo "  다음 단계 (AWS 콘솔에서 진행):"
echo "  1. Amazon Bedrock → 지식 기반 → scd26-crosscloud-rag-kb"
echo "  2. 우측 'Test knowledge base' 패널"
echo "  3. 모델: Claude 3.5 Sonnet 선택"
echo "  4. 질문 입력하여 RAG 챗봇 테스트"
echo ""
echo "  ⚠ 실습 후 반드시 정리하세요:"
echo "     ./scripts/cleanup-aws.sh"
echo ""

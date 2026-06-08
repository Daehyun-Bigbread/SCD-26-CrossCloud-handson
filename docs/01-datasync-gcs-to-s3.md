# Module 1 — GCS에서 S3로 문서 전송 (AWS DataSync)

> **소요 시간**: 약 10분
>
> **목표**: Google Cloud Storage(GCS)에 있는 RAG용 문서를 AWS DataSync를 사용하여 Amazon S3 버킷으로 동기화합니다.

## 핵심 개념

**AWS DataSync**는 AWS와 다른 스토리지 시스템 간의 데이터 전송을 자동화하는 서비스입니다.
GCS는 S3 호환 API를 제공하므로, DataSync의 **Object Storage** 위치 유형을 사용하여 GCS 버킷에 접근할 수 있습니다.

```
GCS Bucket (소스)  ──── HMAC Key 인증 ────▶  AWS DataSync  ──▶  S3 Bucket (대상)
```

> **참고**: 이 패턴은 [RAG-QA-pipeline-GCP](https://github.com/Daehyun-Bigbread/RAG-QA-pipeline-GCP) 프로젝트에서 FAISS 인덱스를 GCS→S3로 동기화할 때 사용한 것과 동일한 방식입니다.

## 1-1. S3 버킷 생성 (전송 대상)

먼저 문서를 받을 S3 버킷을 생성합니다.

1. AWS 콘솔에서 **S3** 서비스로 이동합니다
2. **Create bucket** 클릭
3. 아래 설정으로 버킷을 생성합니다:

| 항목 | 값 |
|------|-----|
| Bucket name | `scd26-handson-rag-docs-{본인이니셜}` (예: `scd26-handson-rag-docs-dhkim`) |
| AWS Region | **Asia Pacific (Seoul) ap-northeast-2** |
| Object Ownership | ACLs disabled (기본값) |
| Block Public Access | 모두 차단 (기본값) |

4. 나머지 설정은 기본값 유지 → **Create bucket** 클릭

<!-- ![S3 버킷 생성](images/01-datasync/s3-create-bucket.png) -->

> **버킷 이름은 전 세계에서 고유**해야 합니다. 이니셜이나 날짜를 붙여서 중복을 방지하세요.

## 1-2. HMAC Key 정보 확인

GCS에 접근하기 위해 **HMAC(Hash-based Message Authentication Code) 키**가 필요합니다.
HMAC 키는 S3 호환 API 형태의 Access Key / Secret Key 쌍입니다.

> 핸즈온 진행자가 아래 정보를 공유합니다. 복사하여 사용하세요.

| 항목 | 값 |
|------|-----|
| Server URL | `https://storage.googleapis.com` |
| GCS Bucket Name | _(진행자가 안내)_ |
| Access Key | _(진행자가 안내)_ |
| Secret Key | _(진행자가 안내)_ |

!!! warning "주의"
    HMAC 키를 입력할 때 앞뒤 공백이 들어가지 않도록 주의하세요. 한 글자라도 틀리면 인증 실패가 발생합니다.

## 1-3. DataSync — 소스 위치 생성 (GCS)

1. AWS 콘솔에서 **DataSync** 서비스로 이동합니다
2. 좌측 메뉴에서 **Data transfer** → **Locations** 클릭
3. **Create location** 클릭
4. 아래 설정을 입력합니다:

| 항목 | 값 |
|------|-----|
| Location type | **Object storage** |
| Agent | 선택 안 함 (퍼블릭 엔드포인트 사용) |
| Server URL | `https://storage.googleapis.com` |
| Bucket name | _(진행자가 안내한 GCS 버킷 이름)_ |
| Folder | `/sample-docs/` (또는 진행자가 안내한 경로) |

5. **Additional settings** 섹션 확장:

| 항목 | 값 |
|------|-----|
| Access key | _(진행자가 안내한 HMAC Access Key)_ |
| Secret key | _(진행자가 안내한 HMAC Secret Key)_ |

6. **Create location** 클릭

<!-- ![DataSync 소스 위치](images/01-datasync/datasync-source-location.png) -->

## 1-4. DataSync — 대상 위치 생성 (S3)

1. **Locations** 페이지에서 다시 **Create location** 클릭
2. 아래 설정을 입력합니다:

| 항목 | 값 |
|------|-----|
| Location type | **Amazon S3** |
| S3 bucket | 1-1에서 생성한 버킷 선택 |
| S3 storage class | Standard (기본값) |
| Folder | _(비워두기 — 버킷 루트에 저장)_ |
| IAM role | **Auto generate** (자동 생성) |

3. **Create location** 클릭

<!-- ![DataSync 대상 위치](images/01-datasync/datasync-dest-location.png) -->

## 1-5. DataSync — 태스크 생성 및 실행

1. 좌측 메뉴에서 **Data transfer** → **Tasks** 클릭
2. **Create task** 클릭

### Step 1: Configure source location

| 항목 | 값 |
|------|-----|
| Source location | **Choose an existing location** → 1-3에서 생성한 GCS 위치 선택 |

### Step 2: Configure destination location

| 항목 | 값 |
|------|-----|
| Destination location | **Choose an existing location** → 1-4에서 생성한 S3 위치 선택 |

### Step 3: Configure settings

| 항목 | 값 |
|------|-----|
| Task mode | **Enhanced** (향상됨) — 에이전트 없이 S3↔다른 클라우드 전송 지원 |
| Task name | `scd26-gcs-to-s3-transfer` |
| Transfer mode | **모든 데이터 전송** (기본값) |
| Verification | **전송된 데이터만 확인** (기본값) |
| Bandwidth limit | **사용 가능한 항목 사용** (기본값) |
| Keep deleted files | **유지** (기본값) |
| Object tags | **체크 해제** (GCS는 S3 태그를 지원하지 않음) |
| Schedule | **Not scheduled** (기본값) |
| 나머지 | 기본값 유지 |

!!! danger "필수 확인"
    Object tags(객체 태그 보존) 옵션이 보이면 반드시 **체크 해제**하세요.
    GCS는 S3 태그를 지원하지 않기 때문에 체크되어 있으면 전송이 실패합니다.

> **참고**: Enhanced(향상됨) 모드는 에이전트 없이 S3와 다른 클라우드 간 직접 전송을 지원합니다.
> 기본(Basic) 모드보다 성능이 높고, 태스크 생성 후 모드 변경은 불가합니다.

### Step 4: Review and Create

- 설정을 확인하고 **Create task** 클릭

3. 태스크가 생성되면 **Start** → **Start with defaults** 클릭하여 전송을 시작합니다

<!-- ![DataSync 태스크 실행](images/01-datasync/datasync-start-task.png) -->

## 1-6. 전송 결과 확인

1. 태스크 실행 후 약 **30초~1분**이면 완료됩니다 (8개 파일, 18.5KB 기준)
2. **History** 탭에서 실행 결과를 확인합니다:
   - Status: **Success**
   - Files transferred: 8개 (샘플 문서 수)
   - Bytes transferred: 18,548 bytes
3. **S3 콘솔**에서 버킷 루트에 8개 TXT 파일이 있는지 확인합니다

<!-- ![S3 전송 완료](images/01-datasync/s3-transferred-files.png) -->

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| `InvalidAccessKeyId` | HMAC Access Key 오타 | 키를 다시 복사하여 붙여넣기 |
| `SignatureDoesNotMatch` | HMAC Secret Key 오타 또는 공백 | 키 앞뒤 공백 제거 후 재입력 |
| Task가 UNAVAILABLE | 소스 위치 접근 불가 | Server URL이 `https://storage.googleapis.com`인지 확인 |
| Files transferred: 0 | 폴더 경로 오류 | GCS 버킷의 폴더 경로가 정확한지 진행자에게 확인 |
| S3 대상 위치 생성 실패 (`s3:ListBucket` 권한) | IAM 역할 자동 생성 지연 | 1분 대기 후 **Auto generate** 다시 선택하여 재시도 |

## 폴백 플랜

!!! tip "폴백"
    DataSync 설정에 어려움이 있는 경우, 진행자가 **이미 문서가 업로드된 S3 버킷 정보**를 안내합니다.
    해당 버킷을 사용하여 Module 2로 바로 진행할 수 있습니다.

??? example "CLI 스크립트로 자동 구축 (복사/붙여넣기용)"

    콘솔 대신 AWS CLI로 Module 1 전체를 자동 실행할 수 있습니다.
    아래 스크립트를 터미널에 복사하여 실행하세요.

    **사전 요구사항**: AWS CLI v2 설치 및 `aws configure` 완료, 리전 `ap-northeast-2`

    **실행 방법**:
    ```bash
    chmod +x scripts/setup-module1-datasync.sh
    ./scripts/setup-module1-datasync.sh
    ```

    **전체 스크립트**:
    ```bash
    #!/bin/bash
    set -euo pipefail

    REGION="ap-northeast-2"

    echo "============================================"
    echo "  Module 1 — GCS → S3 전송 (자동 구축)"
    echo "============================================"

    # ─── 사용자 입력 ─────────────────────────────────────────
    read -rp "S3 버킷 이름 (예: scd26-handson-rag-docs-홍길동): " S3_BUCKET
    read -rp "GCS 버킷 이름 (진행자가 안내한 값): " GCS_BUCKET
    read -rp "GCS 폴더 경로 (기본값: /sample-docs/): " GCS_FOLDER
    GCS_FOLDER="${GCS_FOLDER:-/sample-docs/}"
    read -rp "HMAC Access Key (진행자가 안내한 값): " HMAC_ACCESS_KEY
    read -rsp "HMAC Secret Key (진행자가 안내한 값): " HMAC_SECRET_KEY
    echo ""

    # ─── Step 1: S3 버킷 생성 ────────────────────────────────
    echo "━━━ [1/4] S3 버킷 생성 ━━━"
    aws s3api create-bucket \
      --bucket "$S3_BUCKET" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION" \
      --output text
    echo "✓ S3 버킷 생성 완료: $S3_BUCKET"

    # ─── Step 2: DataSync IAM 역할 생성 ──────────────────────
    echo "━━━ [2/4] DataSync용 IAM 역할 생성 ━━━"
    DATASYNC_ROLE_NAME="DataSyncS3Role-scd26-handson"

    TRUST_POLICY='{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": { "Service": "datasync.amazonaws.com" },
        "Action": "sts:AssumeRole"
      }]
    }'

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
      --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
          {
            "Effect": "Allow",
            "Action": ["s3:GetBucketLocation","s3:ListBucket","s3:ListBucketMultipartUploads"],
            "Resource": "arn:aws:s3:::'"$S3_BUCKET"'"
          },
          {
            "Effect": "Allow",
            "Action": ["s3:AbortMultipartUpload","s3:DeleteObject","s3:GetObject",
                       "s3:ListMultipartUploadParts","s3:PutObject",
                       "s3:GetObjectTagging","s3:PutObjectTagging"],
            "Resource": "arn:aws:s3:::'"$S3_BUCKET"'/*"
          }
        ]
      }'
    echo "✓ IAM 역할 생성 완료"
    sleep 10

    # ─── Step 3: DataSync 위치 생성 ──────────────────────────
    echo "━━━ [3/4] DataSync 위치 생성 ━━━"
    SOURCE_LOCATION_ARN=$(aws datasync create-location-object-storage \
      --server-hostname "storage.googleapis.com" \
      --server-protocol "HTTPS" --server-port 443 \
      --bucket-name "$GCS_BUCKET" --subdirectory "$GCS_FOLDER" \
      --access-key "$HMAC_ACCESS_KEY" --secret-key "$HMAC_SECRET_KEY" \
      --region "$REGION" --query 'LocationArn' --output text)

    DEST_LOCATION_ARN=$(aws datasync create-location-s3 \
      --s3-bucket-arn "arn:aws:s3:::$S3_BUCKET" \
      --s3-config "BucketAccessRoleArn=$DATASYNC_ROLE_ARN" \
      --region "$REGION" --query 'LocationArn' --output text)
    echo "✓ 소스/대상 위치 생성 완료"

    # ─── Step 4: DataSync 태스크 생성 및 실행 ────────────────
    echo "━━━ [4/4] DataSync 태스크 생성 및 실행 ━━━"
    TASK_ARN=$(aws datasync create-task \
      --source-location-arn "$SOURCE_LOCATION_ARN" \
      --destination-location-arn "$DEST_LOCATION_ARN" \
      --name "scd26-gcs-to-s3-transfer" \
      --options '{"VerifyMode":"ONLY_FILES_TRANSFERRED","OverwriteMode":"ALWAYS",
                  "Atime":"BEST_EFFORT","Mtime":"PRESERVE",
                  "PreserveDeletedFiles":"PRESERVE","TransferMode":"ALL"}' \
      --task-mode "ENHANCED" \
      --region "$REGION" --query 'TaskArn' --output text)

    EXECUTION_ARN=$(aws datasync start-task-execution \
      --task-arn "$TASK_ARN" --region "$REGION" \
      --query 'TaskExecutionArn' --output text)

    echo "  전송 완료 대기 중..."
    while true; do
      STATUS=$(aws datasync describe-task-execution \
        --task-execution-arn "$EXECUTION_ARN" \
        --region "$REGION" --query 'Status' --output text)
      [[ "$STATUS" == "SUCCESS" ]] && break
      [[ "$STATUS" == "ERROR" ]] && echo "✗ 전송 실패" && exit 1
      sleep 5
    done

    FILE_COUNT=$(aws s3 ls "s3://$S3_BUCKET/" --region "$REGION" | wc -l | tr -d ' ')
    echo "✓ DataSync 전송 완료! S3 버킷에 ${FILE_COUNT}개 파일"
    ```

---

**이전**: [Module 0 — 사전 준비](00-prerequisites.md) | **다음**: [Module 2 — Bedrock Knowledge Bases](02-bedrock-kb-create.md)

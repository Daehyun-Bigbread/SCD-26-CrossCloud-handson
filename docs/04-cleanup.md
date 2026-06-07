# Module 4 — 리소스 정리

> **소요 시간**: 약 15분
> **목표**: 실습에서 생성한 모든 AWS 리소스를 삭제하여 불필요한 과금을 방지합니다.

> **중요**: OpenSearch Serverless는 **시간당 $0.48** (2 OCU)이 과금됩니다.
> 실습이 끝나면 **즉시** 이 모듈을 진행하세요.

## 삭제 순서

리소스 간 의존성이 있으므로 **반드시 아래 순서대로** 삭제합니다:

```
1. Bedrock Knowledge Base  ←  먼저 삭제 (OpenSearch 컬렉션 자동 삭제)
2. DataSync 태스크 & 위치   ←  전송 리소스 삭제
3. S3 버킷                  ←  마지막 삭제 (객체 먼저 비우기)
```

## 4-1. Bedrock Knowledge Base 삭제

1. **Amazon Bedrock** 콘솔 → **Knowledge Bases**
2. `scd26-crosscloud-rag-kb` 선택
3. **Delete** 클릭
4. 확인 다이얼로그에서 Knowledge Base 이름을 입력하고 **Delete** 확인

<!-- ![KB 삭제](images/04-cleanup/delete-kb.png) -->

> Knowledge Base를 삭제하면 **Quick create로 자동 생성된 OpenSearch Serverless 컬렉션도 함께 삭제**됩니다.
> 이것이 과금의 주요 원인이므로 가장 먼저 삭제합니다.

### 확인: OpenSearch Serverless 컬렉션 삭제 확인

1. **Amazon OpenSearch Service** 콘솔로 이동
2. 좌측 메뉴에서 **Serverless** → **Collections**
3. Bedrock KB가 생성한 컬렉션이 **삭제 중** 또는 이미 사라졌는지 확인

> 만약 컬렉션이 남아있다면 수동으로 삭제합니다:
> 컬렉션 선택 → **Delete** → 확인

## 4-2. DataSync 태스크 삭제

1. **AWS DataSync** 콘솔 → **Tasks**
2. `scd26-gcs-to-s3-transfer` 태스크 선택
3. **Actions** → **Delete** 클릭
4. 확인 후 삭제

<!-- ![DataSync 태스크 삭제](images/04-cleanup/delete-datasync-task.png) -->

## 4-3. DataSync 위치 삭제

1. **AWS DataSync** 콘솔 → **Locations**
2. 생성한 위치 2개를 각각 선택하여 삭제:
   - Object storage 위치 (GCS 소스)
   - Amazon S3 위치 (대상)
3. 각각 **Actions** → **Delete** 클릭

## 4-4. S3 버킷 삭제

S3 버킷은 **비어있어야만** 삭제할 수 있습니다.

### 버킷 비우기

1. **S3** 콘솔 → `scd26-handson-rag-docs-{이니셜}` 버킷 클릭
2. 모든 객체를 선택 (체크박스) → **Delete** 클릭
3. `permanently delete` 입력 → **Delete objects** 확인

### 버킷 삭제

1. S3 콘솔의 버킷 목록으로 돌아갑니다
2. 버킷 이름 좌측 라디오 버튼 선택 → **Delete** 클릭
3. 버킷 이름을 입력 → **Delete bucket** 확인

<!-- ![S3 버킷 삭제](images/04-cleanup/delete-s3-bucket.png) -->

## 4-5. IAM 역할 삭제 (선택)

Bedrock KB와 DataSync가 자동 생성한 IAM 역할을 정리합니다.

1. **IAM** 콘솔 → **Roles**
2. 아래 패턴의 역할을 검색하여 삭제:
   - `AmazonBedrockExecutionRoleForKnowledgeBase_*`
   - `AWSDataSyncS3BucketAccess-*`
3. 해당 역할 선택 → **Delete** → 역할 이름 입력 → 삭제 확인

> 이 단계는 선택 사항이지만, 계정을 깔끔하게 유지하고 싶다면 진행하세요.

## 삭제 완료 체크리스트

모든 리소스가 삭제되었는지 최종 확인합니다:

- [ ] **Bedrock Knowledge Base** 삭제됨
- [ ] **OpenSearch Serverless** 컬렉션 삭제됨 (자동 삭제 확인)
- [ ] **DataSync 태스크** 삭제됨
- [ ] **DataSync 위치** 2개 삭제됨
- [ ] **S3 버킷** 비우기 + 삭제됨
- [ ] (선택) **IAM 역할** 삭제됨

## 비용 확인

삭제 후 예상 비용을 확인합니다:

1. AWS 콘솔 우측 상단 **계정 이름** 클릭 → **Billing and Cost Management**
2. 실습 당일 발생한 비용이 ~$1.50 이하인지 확인

> 다음 날 **Cost Explorer**에서 서비스별 상세 비용을 확인할 수 있습니다.

---

**수고하셨습니다!** Cross-Cloud RAG 챗봇 핸즈온을 완료했습니다.

**이전**: [Module 3 — RAG 챗봇 테스트](03-chatbot-test.md) | **처음으로**: [README](../README.md)

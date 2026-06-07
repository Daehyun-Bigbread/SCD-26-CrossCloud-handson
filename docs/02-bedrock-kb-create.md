# Module 2 — Amazon Bedrock Knowledge Bases 생성

> **소요 시간**: 약 30분
> **목표**: S3에 저장된 문서를 데이터 소스로 하는 Bedrock Knowledge Base를 생성하고, 문서를 임베딩하여 벡터 인덱스로 동기화합니다.

## 핵심 개념

**Amazon Bedrock Knowledge Bases**는 RAG 파이프라인을 자동으로 구축해주는 매니지드 서비스입니다.

```
S3 (문서) → Bedrock KB → [파싱 → 청킹 → 임베딩 → 벡터 저장] → 검색 가능한 지식 기반
```

기존에 직접 구현해야 했던 과정들을 Bedrock KB가 자동으로 처리합니다:

| 단계 | 직접 구현 시 | Bedrock KB 사용 시 |
|------|-------------|-------------------|
| 문서 파싱 | PyMuPDF, BeautifulSoup 등 | 자동 (PDF, TXT, HTML 등 지원) |
| 청킹 | kss, tiktoken 등으로 직접 분할 | 자동 (기본 300 토큰 청킹) |
| 임베딩 | OpenAI API 호출 등 | Titan Embeddings V2 자동 호출 |
| 벡터 저장 | FAISS, ChromaDB 등 직접 관리 | OpenSearch Serverless 자동 생성 |

## 사용하는 AWS 서비스

| 서비스 | 역할 | 비고 |
|--------|------|------|
| **Amazon Bedrock** | Knowledge Base 생성 및 관리 | 매니지드 RAG 파이프라인 |
| **Amazon Titan Text Embeddings V2** | 문서 → 1024차원 벡터 변환 | 임베딩 모델 |
| **Amazon OpenSearch Serverless** | 벡터 인덱스 저장 및 검색 | Quick Create로 자동 생성 |
| **Anthropic Claude 3.5 Sonnet** | 검색된 문서 기반 답변 생성 | KB 테스트 패널에서 사용 |

## 2-1. Knowledge Base 생성

1. AWS 콘솔에서 **Amazon Bedrock** 서비스로 이동합니다
2. 좌측 메뉴에서 **건축** → **지식 기반** 클릭
3. **지식 기반 생성** 클릭

### Step 1: 지식 기반 세부 정보

| 항목 | 값 |
|------|-----|
| Knowledge base name | `scd26-crosscloud-rag-kb` |
| Description | `Cross-Cloud RAG 핸즈온 - GCS에서 동기화한 문서 기반 Knowledge Base` |
| IAM permissions | **Create and use a new service role** (기본값) |

**다음** 클릭

### Step 2: 데이터 소스 구성

| 항목 | 값 |
|------|-----|
| Data source name | `s3-synced-docs` |
| S3 URI | **Browse S3** 클릭 → Module 1에서 생성한 버킷 선택 |

> S3 URI 형식: `s3://{본인 버킷 이름}/` (버킷 루트 전체 선택)

**Chunking strategy** (Advanced settings):

| 항목 | 값 |
|------|-----|
| Chunking strategy | **Default chunking** (기본값 권장) |

> 기본 청킹은 300 토큰 단위로 문서를 분할합니다. 입문 실습에서는 기본값이 적합합니다.

**다음** 클릭

### Step 3: 데이터 스토리지 및 처리 구성

| 항목 | 값 |
|------|-----|
| Embeddings model | **Titan Text Embeddings V2** |
| Vector dimensions | 1024 (기본값) |
| Vector database | **새로운 벡터 저장소 빠른 생성 - 권장** |
| Vector store | **Amazon OpenSearch Serverless** 선택 |

> **Quick create**를 선택하면 OpenSearch Serverless 컬렉션이 자동으로 생성됩니다.
> 수동 설정 대비 약 15분의 시간을 절약할 수 있습니다.

**다음** 클릭

### Step 4: 검토 및 생성

- 모든 설정을 확인하고 **지식 기반 생성** 클릭
- Knowledge Base 생성에 약 **3~5분**이 소요됩니다

> **주의**: OpenSearch Serverless 컬렉션이 함께 생성되므로 이 시점부터 **시간당 과금**이 시작됩니다.
> 실습이 끝나면 반드시 [Module 4 — 리소스 정리](04-cleanup.md)를 진행하세요.

## 2-2. 데이터 소스 동기화 (Sync)

Knowledge Base가 생성되면 S3의 문서를 임베딩하여 벡터 인덱스에 저장해야 합니다.

1. 생성된 Knowledge Base 상세 페이지로 이동합니다
2. **Data source** 섹션에서 `s3-synced-docs` 데이터 소스를 선택합니다
3. **Sync** 버튼을 클릭합니다
4. 동기화 상태가 진행됩니다:
   - **Syncing** → 문서 파싱 및 임베딩 중
   - **Available** → 동기화 완료

> 동기화는 약 **3~5분** 소요됩니다. 문서 수와 크기에 따라 다를 수 있습니다.

## 2-3. 동기화 결과 확인

동기화가 완료되면:

1. **Data source** 섹션에서 Sync 상태가 **Completed**인지 확인합니다
2. **Sync history**를 클릭하면 상세 결과를 볼 수 있습니다:
   - Number of source documents synced
   - Number of source documents failed
   - Number of new/modified/deleted chunks

> 만약 실패한 문서가 있다면 파일 형식이 지원되는지 확인하세요.
> Bedrock KB는 PDF, TXT, HTML, MD, CSV, DOC/DOCX, XLS/XLSX 형식을 지원합니다.

## 2-4. Knowledge Base 테스트 (간단 확인)

동기화가 완료되면 바로 테스트할 수 있습니다.

1. Knowledge Base 상세 페이지 우측의 **Test knowledge base** 패널을 확인합니다
2. **Select model** 에서 **Anthropic Claude 3.5 Sonnet** (또는 Claude 3 Haiku)를 선택합니다
3. 간단한 질문을 입력해봅니다:

```
이 문서들은 어떤 내용을 다루고 있나요?
```

4. 응답이 S3에 업로드한 문서 내용을 참조하여 답변하는지 확인합니다

> 이 단계에서는 간단히 동작 여부만 확인합니다.
> 자세한 챗봇 테스트는 Module 3에서 진행합니다.

## 내부 동작 이해

Bedrock KB가 내부적으로 수행하는 RAG 파이프라인:

```
1. 파싱 (Parsing)
   S3 문서 → 텍스트 추출 (PDF 구조, 테이블, 이미지 OCR 등)

2. 청킹 (Chunking)  
   텍스트 → 300 토큰 단위로 분할 (문맥 보존)

3. 임베딩 (Embedding)
   각 청크 → Titan Embeddings V2 → 1024차원 벡터

4. 인덱싱 (Indexing)
   벡터 → OpenSearch Serverless 컬렉션에 저장

5. 검색 (Retrieval) — 질의 시
   질문 → 임베딩 → 유사 벡터 검색 → 관련 청크 반환

6. 생성 (Generation) — 질의 시
   관련 청크 + 질문 → LLM → 답변 생성
```

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| KB 생성 시 "루트 사용자 지원 안 됨" | 루트 사용자로 로그인 | IAM 사용자로 로그인 후 재시도 (Module 0 참고) |
| KB 생성 시 IAM 오류 | 역할 생성 권한 없음 | Admin 권한 확인, 또는 수동으로 역할 생성 |
| Sync 실패 | S3 버킷 접근 불가 | S3 URI 경로 확인, 리전이 ap-northeast-2인지 확인 |
| Sync 시 문서 0건 | 폴더 경로 오류 | S3 URI가 `s3://버킷명/`인지 확인 (버킷 루트) |
| 테스트 시 "모델 접근 불가" | Bedrock 모델 미승인 | Module 0의 모델 액세스 상태 재확인 |
| 리전 불일치 | 다른 리전에서 KB 생성 | 콘솔 우측 상단 리전이 `ap-northeast-2`인지 확인 |

---

**이전**: [Module 1 — GCS → S3 전송](01-datasync-gcs-to-s3.md) | **다음**: [Module 3 — RAG 챗봇 테스트](03-chatbot-test.md)

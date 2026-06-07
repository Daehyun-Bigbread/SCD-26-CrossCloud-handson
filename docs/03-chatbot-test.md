# Module 3 — RAG 챗봇 테스트

> **소요 시간**: 약 15분
> **목표**: Knowledge Base 테스트 패널에서 RAG 챗봇을 테스트하고, RAG 유무에 따른 응답 차이를 비교합니다.

## 3-1. Knowledge Base 테스트 패널 사용

가장 간단한 테스트 방법은 Knowledge Base 상세 페이지의 내장 테스트 패널입니다.

1. **Amazon Bedrock** 콘솔 → **Knowledge Bases** → `scd26-crosscloud-rag-kb` 클릭
2. 우측의 **Test knowledge base** 패널에서:

| 항목 | 설정 |
|------|------|
| Select model | **Anthropic Claude 3.5 Sonnet** |
| Source details | **ON** (출처 문서 표시) |

<!-- ![테스트 패널 설정](images/03-chatbot-test/test-panel-setup.png) -->

## 3-2. 테스트 질문 — RAG 응답 확인

아래 질문들을 순서대로 입력하고, 응답이 **S3에 업로드한 문서 내용을 기반으로** 답변하는지 확인합니다.

### 질문 1: 기본 검색

```
Amazon S3란 무엇인가요?
```

**확인 포인트**:
- 응답이 업로드한 문서의 S3 관련 내용을 참조하는지
- 하단의 **Source** 섹션에 참조 문서와 청크가 표시되는지

### 질문 2: 구체적 정보 검색

```
Amazon Bedrock에서 지원하는 Foundation Model에는 어떤 것들이 있나요?
```

**확인 포인트**:
- 문서에 있는 구체적인 모델 목록을 답변하는지
- 일반 LLM 학습 데이터가 아닌, **업로드한 문서 기반** 답변인지

### 질문 3: 문서에 없는 내용

```
오늘 서울의 날씨는 어떤가요?
```

**확인 포인트**:
- "관련 정보를 찾을 수 없습니다" 또는 유사한 응답이 나오는지
- RAG가 잘 동작한다면, 문서에 없는 내용에 대해 환각(hallucination) 없이 답변을 거절해야 합니다

<!-- ![RAG 응답 예시](images/03-chatbot-test/rag-response-example.png) -->

## 3-3. RAG vs Non-RAG 비교 (선택)

RAG의 효과를 직접 체감해봅니다.

### Non-RAG 응답 확인

1. Bedrock 콘솔 좌측 메뉴에서 **Playgrounds** → **Chat** 클릭
2. 모델을 **Claude 3.5 Sonnet**으로 선택
3. Knowledge Base **연결 없이** 같은 질문을 입력합니다:

```
Amazon Bedrock에서 지원하는 Foundation Model에는 어떤 것들이 있나요?
```

### 비교 포인트

| 항목 | RAG 응답 | Non-RAG 응답 |
|------|---------|-------------|
| 정보 출처 | 업로드한 문서 기반 | 모델 학습 데이터 기반 |
| 최신성 | 문서가 최신이면 최신 정보 | 학습 시점까지의 정보만 |
| 정확도 | 문서에 있는 내용에 대해 높음 | 환각 가능성 있음 |
| 출처 표시 | Source 링크 제공 | 출처 불명 |

## 3-4. 검색 결과 상세 확인

Source details를 통해 RAG 파이프라인의 내부 동작을 확인합니다.

1. 응답 하단의 **Show source details** 클릭
2. 각 Source에서 확인할 수 있는 정보:

| 항목 | 설명 |
|------|------|
| **Source document** | 참조한 S3 문서 경로 |
| **Chunk** | 실제로 검색된 문서 조각 (청크) |
| **Relevance score** | 질문과의 관련도 점수 |

<!-- ![출처 상세](images/03-chatbot-test/source-details.png) -->

> 이 정보를 통해 RAG 파이프라인이 어떤 문서의 어느 부분을 참조하여 답변을 생성했는지 추적할 수 있습니다.

## 3-5. 실습 정리

축하합니다! Cross-Cloud RAG 챗봇 구축을 완료했습니다.

### 오늘 실습한 전체 흐름

```
Google Cloud Storage (GCS)
    │  ← 원본 문서 저장
    ▼
AWS DataSync (HMAC Key 인증)
    │  ← 크로스 클라우드 데이터 전송
    ▼
Amazon S3
    │  ← 문서 저장 (AWS 측)
    ▼
Amazon Bedrock Knowledge Bases
    │  ← 파싱 → 청킹 → 임베딩 → 벡터 인덱싱 (자동)
    │  ← OpenSearch Serverless (벡터 DB, 자동 생성)
    ▼
KB 테스트 패널 (Claude 3.5 Sonnet)
    │  ← 질의 → 검색 → 답변 생성 (RAG)
    ▼
사용자에게 답변 제공
```

### 핵심 학습 포인트

1. **크로스 클라우드 데이터 이동**: AWS DataSync + HMAC 키로 GCS↔S3 간 데이터 동기화
2. **매니지드 RAG 파이프라인**: Bedrock Knowledge Bases가 임베딩~검색~생성을 자동 처리
3. **RAG의 효과**: 문서 기반 답변으로 환각 감소, 출처 추적 가능

---

> **중요**: 다음 모듈에서 리소스를 삭제합니다. 과금 방지를 위해 반드시 진행하세요!

**이전**: [Module 2 — Bedrock Knowledge Bases](02-bedrock-kb-create.md) | **다음**: [Module 4 — 리소스 정리](04-cleanup.md)

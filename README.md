# Amazon Bedrock으로 만드는 Cross-Cloud RAG 챗봇

> **2026 AWS Student Community Day 핸즈온 워크숍**

Google Cloud Storage(GCS)에 저장된 문서를 AWS DataSync로 Amazon S3에 동기화한 뒤, Amazon Bedrock Knowledge Bases를 활용해 RAG 챗봇을 구축하는 실습입니다. 복잡한 코딩 없이 **AWS 콘솔 클릭만으로** 멀티클라우드 RAG 파이프라인의 전 과정을 체험합니다.

## 아키텍처

![Cross-Cloud RAG Architecture](docs/images/architecture.png)

## 실습 구성

| 모듈 | 내용 | 소요 시간 |
|------|------|----------|
| [Module 0 — 사전 준비](docs/00-prerequisites.md) | AWS 계정 설정, Bedrock 모델 액세스 요청 | **사전 완료** |
| [Module 1 — GCS → S3 전송](docs/01-datasync-gcs-to-s3.md) | AWS DataSync로 GCS 문서를 S3로 동기화 | ~10분 |
| [Module 2 — Bedrock Knowledge Bases](docs/02-bedrock-kb-create.md) | Knowledge Base 생성 & 데이터 소스 동기화 | ~15분 |
| [Module 3 — RAG 챗봇 테스트](docs/03-chatbot-test.md) | KB 테스트 패널에서 RAG 챗봇 검증 | ~10분 |
| [Module 4 — 리소스 정리](docs/04-cleanup.md) | 과금 방지를 위한 리소스 삭제 | ~5분 |

**총 소요 시간**: 약 40분

## 사전 준비 (필수)

실습 **최소 24시간 전**에 완료해야 합니다. Bedrock 모델 액세스 승인에 최대 24시간이 걸릴 수 있습니다.

1. **AWS 계정** 준비 (프리 티어 가능)
2. **IAM 사용자**로 로그인 (루트 사용자로는 Bedrock KB 생성 불가)
3. 리전을 **`ap-northeast-2` (서울)**로 설정
4. **Bedrock 모델 액세스 요청**
   - Anthropic Claude 3.5 Sonnet
   - Amazon Titan Text Embeddings V2
5. 자세한 안내: [Module 0 — 사전 준비](docs/00-prerequisites.md)

> 당일 진행자가 GCS 접속 정보(버킷 이름, HMAC 키)를 화면으로 안내합니다.

## 실습 흐름

| 단계 | 클라우드 | 설명 |
|------|---------|------|
| **1. 데이터 소스** | Google Cloud (GCS) | 진행자가 미리 준비한 RAG용 샘플 문서 |
| **2. 데이터 전송** | AWS DataSync | GCS → S3 크로스 클라우드 동기화 (HMAC 키 인증) |
| **3. RAG 파이프라인** | AWS (Bedrock KB) | 문서 파싱 → 청킹 → 임베딩 → 벡터 인덱싱 (자동) |
| **4. 챗봇 테스트** | AWS (Bedrock) | KB 테스트 패널에서 Claude 3.5 Sonnet으로 RAG 질의응답 |

## 사용 AWS 서비스

| 서비스 | 용도 |
|--------|------|
| **Amazon S3** | DataSync로 전송받은 문서 저장 |
| **AWS DataSync** | GCS → S3 크로스 클라우드 데이터 전송 |
| **Amazon Bedrock Knowledge Bases** | RAG 파이프라인 (파싱 → 청킹 → 임베딩 → 인덱싱) |
| **Amazon Titan Text Embeddings V2** | 문서를 벡터로 변환하는 임베딩 모델 |
| **Amazon OpenSearch Serverless** | 벡터 인덱스 저장 및 검색 (자동 생성) |
| **Anthropic Claude 3.5 Sonnet** | RAG 챗봇 응답 생성 모델 |

## 비용 안내

이 워크숍은 AWS에서 제공하는 핸즈온 계정을 사용합니다. **개인 계정**으로 진행하는 경우 소량의 비용이 발생할 수 있습니다.

> **중요**: 실습이 끝나면 반드시 [Module 4 — 리소스 정리](docs/04-cleanup.md)를 진행하세요.
> OpenSearch Serverless는 **시간당 과금**되므로, 삭제하지 않으면 비용이 계속 발생합니다.

## 기술 스택

| 구분 | 기술 |
|------|------|
| **워크숍 사이트** | MkDocs Material |
| **배포** | GitHub Pages |
| **크로스 클라우드 전송** | AWS DataSync + GCS HMAC 키 |
| **RAG 파이프라인** | Amazon Bedrock Knowledge Bases |
| **임베딩 모델** | Amazon Titan Text Embeddings V2 (1024차원) |
| **벡터 DB** | Amazon OpenSearch Serverless |
| **생성 모델** | Anthropic Claude 3.5 Sonnet |

## 프로젝트 구조

```
SCD-26-CrossCloud-handson/
├── docs/
│   ├── index.md                    # 워크숍 홈 (MkDocs 진입점)
│   ├── 00-prerequisites.md         # Module 0 — 사전 준비
│   ├── 01-datasync-gcs-to-s3.md   # Module 1 — GCS → S3 전송
│   ├── 02-bedrock-kb-create.md    # Module 2 — Bedrock Knowledge Bases
│   ├── 03-chatbot-test.md          # Module 3 — RAG 챗봇 테스트
│   ├── 04-cleanup.md               # Module 4 — 리소스 정리
│   ├── images/                     # 아키텍처 다이어그램 및 아이콘
│   ├── javascripts/
│   │   └── progress.js             # 모듈 진행 상태 추적 (localStorage)
│   └── stylesheets/
│       └── extra.css               # AWS Builder Style 커스텀 CSS
├── scripts/
│   ├── setup-module1-datasync.sh  # Module 1 CLI 폴백 스크립트
│   ├── setup-module2-bedrock-kb.sh # Module 2 CLI 폴백 스크립트
│   └── cleanup-aws.sh             # 리소스 정리 CLI 스크립트
├── overrides/                      # MkDocs Material 커스텀 HTML
├── mkdocs.yml                      # MkDocs 설정
└── requirements.txt                # Python 의존성 (MkDocs)
```

## 콘솔 조작이 어려운 경우 (폴백)

AWS CLI가 설치되어 있다면, 스크립트로 각 모듈을 자동 구축할 수 있습니다.

```bash
# Module 1: S3 버킷 생성 + DataSync로 GCS → S3 전송
./scripts/setup-module1-datasync.sh

# Module 2: Bedrock Knowledge Base 생성 + 데이터 소스 동기화
./scripts/setup-module2-bedrock-kb.sh

# 정리: 모든 리소스 삭제
./scripts/cleanup-aws.sh
```

> 스크립트 실행 후에도 Module 3 (챗봇 테스트)은 AWS 콘솔에서 직접 진행합니다.

## 로컬에서 워크숍 사이트 실행

```bash
pip install -r requirements.txt
mkdocs serve
```

브라우저에서 `http://127.0.0.1:8000` 으로 접속합니다.

## GitHub Pages 배포

워크숍 사이트는 GitHub Pages로 자동 배포됩니다.

- **URL**: https://daehyun-bigbread.github.io/SCD-26-CrossCloud-handson/
- **배포 방법**: `mkdocs gh-deploy` 또는 GitHub Actions

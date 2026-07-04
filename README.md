# Amazon Bedrock으로 만드는 Cross-Cloud RAG 챗봇

> **2026 AWS Student Community Day 핸즈온 워크숍**
>
> 행사 안내 및 신청: <https://event-us.kr/asbg/event/126886>

Google Cloud Storage(GCS)에 저장된 문서를 AWS DataSync로 Amazon S3에 동기화한 뒤, Amazon Bedrock Knowledge Bases를 활용해 RAG 챗봇을 구축하는 핸즈온입니다. 복잡한 코딩 없이 **AWS 콘솔 클릭만으로** 멀티클라우드 RAG 파이프라인의 전 과정을 체험합니다.

## 이 저장소는?

이 저장소는 위 워크숍에서 사용하는 **핸즈온 가이드(워크숍 사이트)와 보조 스크립트**를 담고 있습니다. 따로 실행되는 애플리케이션이 아니라, "따라 하면 멀티클라우드 RAG 파이프라인이 완성되는 안내서"가 핵심 산출물입니다.

- **`docs/`** — MkDocs Material로 작성된 단계별 워크숍 가이드 (GitHub Pages로 배포)
- **`scripts/`** — 콘솔 대신 AWS CLI로 각 모듈을 자동 구축/정리하는 폴백 스크립트
- **`sample-docs/`** — RAG에 사용할 샘플 문서 (실제 행사에서는 진행자가 GCS에 미리 적재)
- **`presenter/`** — 진행자용 운영 가이드(타임라인, 트러블슈팅 등)

참가자는 배포된 사이트(또는 로컬에서 띄운 사이트)의 안내를 따라 **AWS 콘솔에서** 실습을 진행합니다. GCS→S3 전송, Bedrock Knowledge Bases RAG 파이프라인 구축, Claude 3.5 Sonnet 챗봇 테스트까지 약 40분 동안 체험합니다.

> **워크숍 사이트(배포본)**: <https://daehyun-bigbread.github.io/SCD-26-CrossCloud-handson/>

## 아키텍처

![Cross-Cloud RAG Architecture](docs/images/architecture.png)

## 핸즈온 구성

| 모듈 | 내용 | 소요 시간 |
|------|------|----------|
| [Module 0: 사전 준비](docs/00-prerequisites.md) | Workshop Studio 접속, 리전·CloudShell·Bedrock 모델 확인 | 5분 |
| [Module 1: GCS → S3 전송](docs/01-datasync-gcs-to-s3.md) | AWS DataSync로 GCS 문서를 S3로 동기화 | ~10분 |
| [Module 2: Bedrock Knowledge Bases](docs/02-bedrock-kb-create.md) | Knowledge Base 생성 & 데이터 소스 동기화 | ~15분 |
| [Module 3: RAG 챗봇 테스트 & 리소스 정리](docs/03-chatbot-test.md) | KB 테스트 패널에서 RAG 챗봇 검증 후 과금 방지를 위한 리소스 삭제 | ~15분 |

**총 소요 시간**: 약 40분

## 사전 준비 (필수)

핸즈온 시작 전에 미리 점검해 두세요. 이번 핸즈온은 **AWS Workshop Studio**로 제공되는 실습 계정을 사용합니다. Bedrock 모델(Titan Embeddings V2, Anthropic Claude 3.5 Sonnet)은 실습 계정에서 대부분 사전 활성화되어 있습니다.

1. **Workshop Studio 참가 링크**로 접속 (진행자가 당일 안내) → **Open AWS console**
2. 콘솔 리전이 **`us-west-2` (오레곤)**인지 확인 (실습 계정 기본 리전)
3. 콘솔 상단의 **CloudShell** 열기 (이미 인증됨, 리전 자동 설정)
4. **Bedrock 모델 사용 가능 여부 확인**
   - Anthropic Claude 3.5 Sonnet
   - Amazon Titan Text Embeddings V2
5. 자세한 안내: [Module 0 — 사전 준비](docs/00-prerequisites.md)

> 당일 진행자가 GCS 접속 정보(버킷 이름, HMAC 키)를 화면으로 안내합니다.

## 핸즈온 흐름

| 단계 | Managed Service | 설명 |
|------|---------|------|
| **1. 데이터 소스** | Google Cloud Storage (GCS) | 진행자가 미리 준비한 RAG용 샘플 문서 |
| **2. 데이터 전송** | AWS DataSync | GCS → S3 크로스 클라우드 동기화 (HMAC 키 인증) |
| **3. RAG 파이프라인** | Amazon Bedrock Knowledge Bases | 문서 파싱 → 청킹 → 임베딩 → 벡터 인덱싱 (자동) |
| **4. 챗봇 테스트** | Amazon Bedrock | KB 테스트 패널에서 Claude 3.5 Sonnet으로 RAG 질의응답 |

## 사용 AWS 서비스

> 이번 핸즈온에서 우리가 직접 사용해볼 AWS의 Managed Service입니다.

| 서비스 | 용도 |
|--------|------|
| **Amazon S3** | DataSync로 전송받은 문서 저장 |
| **AWS DataSync** | GCS → S3 크로스 클라우드 데이터 전송 |
| **Amazon Bedrock Knowledge Bases** | RAG 파이프라인 (파싱 → 청킹 → 임베딩 → 인덱싱) |
| **Amazon Titan Text Embeddings V2** | 문서를 벡터로 변환하는 임베딩 모델 |
| **Amazon OpenSearch Serverless** | 벡터 인덱스 저장 및 검색 (자동 생성) |
| **Anthropic Claude 3.5 Sonnet** | RAG 챗봇 응답 생성 모델 |

## 사용 GCP 서비스

> 데이터 소스로 연결되는 GCP의 Managed Service입니다. **이번 핸즈온에서는 직접 구축하지 않으며**, 진행자가 미리 준비한 리소스를 데이터 소스로만 사용합니다.

| 서비스 | 용도 |
|--------|------|
| **Google Cloud Storage (GCS)** | RAG용 샘플 문서가 저장된 데이터 소스 (사전 준비됨) |
| **GCS HMAC 키 (Interoperability)** | S3 호환 인증으로 AWS DataSync가 GCS에 접근하도록 허용 (사전 준비됨) |

## 비용 안내

이 핸즈온은 OpenSearch Serverless, Amazon Bedrock 등 **과금되는 서비스**를 사용합니다. 특히 OpenSearch Serverless는 시간당 과금됩니다.

> **중요**: 핸즈온이 끝나면 반드시 [Module 3 — RAG 챗봇 테스트 & 리소스 정리](docs/03-chatbot-test.md)의 리소스 정리를 진행하세요.
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
│   ├── 03-chatbot-test.md          # Module 3 — RAG 챗봇 테스트 & 리소스 정리
│   ├── images/                     # 아키텍처 다이어그램 및 아이콘
│   ├── javascripts/
│   │   └── progress.js             # 모듈 진행 상태 추적 (localStorage)
│   └── stylesheets/
│       └── extra.css               # AWS Builder Style 커스텀 CSS
├── scripts/
│   ├── setup-module1-datasync.sh  # Module 1 CLI 폴백 스크립트
│   ├── setup-module2-bedrock-kb.sh # Module 2 CLI 폴백 스크립트
│   └── cleanup-aws.sh             # 리소스 정리 CLI 스크립트
├── sample-docs/                    # RAG용 샘플 문서 (행사 시 GCS에 적재)
├── presenter/                      # 진행자용 운영 가이드
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

가상환경(venv) 사용을 권장합니다 (최신 macOS·Linux는 시스템 파이썬에 직접 설치가 막혀 있습니다).

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
mkdocs serve
```

브라우저에서 `http://127.0.0.1:8000` 으로 접속합니다. 문서를 수정하면 자동으로 새로고침됩니다. 빌드만 검증하려면 `mkdocs build --strict`.

## GitHub Pages 배포

워크숍 사이트는 GitHub Pages로 자동 배포됩니다.

- **URL**: https://daehyun-bigbread.github.io/SCD-26-CrossCloud-handson/
- **배포 방법**: `mkdocs gh-deploy` 또는 GitHub Actions

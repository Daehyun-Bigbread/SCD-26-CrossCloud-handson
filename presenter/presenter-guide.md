# 발표자 가이드 — Cross-Cloud RAG 챗봇 핸즈온

> 이 문서는 핸즈온 진행자(발표자) 전용입니다.

## 사전 준비 (D-7)

### GCS 버킷 세팅

1. GCP 프로젝트에서 GCS 버킷을 생성합니다
2. `sample-docs/` 폴더의 8개 파일을 GCS 버킷의 `sample-docs/` 경로에 업로드합니다
3. GCS HMAC 키를 생성합니다:
   - GCP 콘솔 → Cloud Storage → Settings → Interoperability
   - **Create a key for a service account** 또는 User account용 키 생성
   - Access Key와 Secret Key를 안전하게 보관합니다

### 참가자 안내 발송 (D-3, D-1)

아래 내용을 참가자에게 이메일/슬랙으로 전달합니다:

```
[사전 준비 안내 — Cross-Cloud RAG 챗봇 핸즈온]

핸즈온 시작 전에 아래 준비를 완료해주세요:

1. AWS 계정 준비 (프리 티어 가능)
2. AWS 콘솔 로그인 → 리전을 ap-northeast-2 (서울)로 설정
3. Amazon Bedrock 모델 액세스 요청:
   - 콘솔에서 Bedrock → Model access → Modify model access
   - Amazon Titan Text Embeddings V2 체크
   - Anthropic Claude 3.5 Sonnet 체크
   - Submit

승인에 최대 수 시간 소요될 수 있으니 미리 요청해주세요.

상세 가이드: [Module 0 링크]
```

### 폴백 S3 버킷 준비

DataSync 실패 시를 대비하여 **이미 문서가 업로드된 S3 버킷**을 사전에 준비합니다:

1. `ap-northeast-2`에 S3 버킷 생성: `scd26-handson-fallback-docs`
2. `sample-docs/`의 8개 파일을 `docs/` 경로에 업로드
3. 버킷 정책에서 참가자 계정의 읽기 권한을 설정하거나, 퍼블릭 읽기를 허용

> 폴백 버킷을 사용하는 참가자는 Module 2에서 S3 URI를 이 버킷으로 변경하면 됩니다.

## 핸즈온 당일

### HMAC 키 배포

HMAC 키는 **복사 가능한 텍스트**로 배포합니다 (스크린샷 X):

- Notion 페이지, Google Docs, 또는 Slack 메시지로 공유
- 스크린에 QR 코드로 링크를 띄우는 것도 좋습니다

배포 내용:
```
[DataSync 설정용 — 복사해서 사용하세요]

Server URL: https://storage.googleapis.com
GCS Bucket Name: {실제 버킷 이름}
Access Key: {실제 Access Key}
Secret Key: {실제 Secret Key}
```

### 타임라인

| 시간 | 내용 | 비고 |
|------|------|------|
| 0:00 | 오프닝 & 아키텍처 설명 | 5분, 전체 흐름 소개 |
| 0:05 | Module 0 확인 | 5분, 모델 액세스 상태 확인 |
| 0:10 | Module 1 시작 | 25분, DataSync 실습 |
| 0:35 | Module 1 트러블슈팅 | 5분, 문제 있는 참가자 지원 |
| 0:40 | Module 2 시작 | 30분, Bedrock KB 생성 |
| 1:10 | Module 3 시작 | 30분, 챗봇 테스트 & 리소스 정리 |
| 1:40 | QnA & 마무리 | 10분 |

### 자주 발생하는 문제와 대응

| 문제 | 원인 | 대응 |
|------|------|------|
| Bedrock 모델 미승인 | 사전 준비 미완료 | 현장에서 즉시 요청 → Titan은 즉시 승인, Claude는 대기 |
| DataSync HMAC 인증 실패 | 키 오타 (특히 Secret Key) | 키를 다시 복사 → 앞뒤 공백 확인 |
| DataSync 전송 파일 0건 | 폴더 경로 오류 | GCS 폴더 경로 재확인 |
| KB 생성 후 Sync 실패 | S3 URI 오류 | `s3://버킷명/docs/` 형식 확인, 리전 일치 확인 |
| OpenSearch Serverless 프로비저닝 지연 | 서비스 용량 | 3~5분 대기, 최대 10분 |
| 리전 불일치 | 다른 리전에서 리소스 생성 | 콘솔 우측 상단 리전이 ap-northeast-2인지 확인 유도 |

### 참가자가 완전히 막힌 경우

1. **Module 1 실패**: 폴백 S3 버킷 정보 제공 → Module 2로 바로 진행
2. **Module 2 실패**: 발표자가 미리 생성해둔 KB의 Playground를 화면 공유로 시연
3. **모델 미승인**: Claude 3 Haiku로 대체 시도, 그래도 안 되면 시연으로 대체

## 핸즈온 종료 후

### 참가자 리소스 정리 확인

- Module 3 마지막 리소스 정리 체크리스트 완료 여부를 구두로 확인합니다
- **OpenSearch Serverless 컬렉션이 남아있으면 시간당 과금**되므로 특히 강조합니다

### 발표자 리소스 정리

- [ ] 폴백 S3 버킷 삭제
- [ ] GCS 버킷의 HMAC 키 삭제 (또는 비활성화)
- [ ] (필요 시) GCS 버킷의 샘플 문서 삭제

### 비용 정리

예상 비용 (발표자):
- GCS: 거의 무료 (소량 저장)
- 폴백 S3 버킷: ~$0.01
- HMAC 키: 무료

참가자 1인당 예상 비용: ~$1.50 (3시간 기준)

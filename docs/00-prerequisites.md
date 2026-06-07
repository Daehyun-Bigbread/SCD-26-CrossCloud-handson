# Module 0 — 사전 준비

> 이 모듈은 핸즈온 **최소 24시간 전에** 완료해야 합니다.
> Bedrock 모델 액세스 승인에 시간이 걸릴 수 있습니다.

## 0-1. AWS 계정 준비

AWS 계정이 없는 경우 [https://aws.amazon.com](https://aws.amazon.com)에서 생성합니다.

> 프리 티어 계정으로 충분합니다. 단, 결제 수단(신용카드) 등록이 필요합니다.

> **중요**: 이 핸즈온은 **IAM 사용자**로 로그인해야 합니다. **루트 사용자(Root user)로는 Bedrock Knowledge Base를 생성할 수 없습니다.**
> IAM 사용자가 없는 경우 아래 절차로 생성하세요.

### IAM 사용자 생성 (루트 사용자인 경우)

1. AWS 콘솔에서 **IAM** 서비스로 이동합니다
2. 좌측 메뉴에서 **Users** → **Create user** 클릭
3. 아래 설정으로 생성합니다:

| 항목 | 값 |
|------|-----|
| User name | `scd26-admin` (또는 원하는 이름) |
| Console access | **Provide user access to the AWS Management Console** 체크 |
| Password | 원하는 비밀번호 설정 |

4. **Permissions** 단계에서 **Attach policies directly** → `AdministratorAccess` 선택
5. **Create user** 클릭
6. 생성 완료 후, **루트 사용자에서 로그아웃**하고 **IAM 사용자로 다시 로그인**합니다

> 로그인 URL 형식: `https://{계정ID}.signin.aws.amazon.com/console`

## 0-2. 리전 설정

이번 핸즈온은 **`ap-northeast-2` (서울)** 리전에서 진행합니다.

1. AWS 콘솔 우측 상단의 리전 선택 드롭다운을 클릭합니다
2. **Asia Pacific (Seoul) ap-northeast-2**를 선택합니다

> **주의**: 모든 실습 과정에서 리전이 `ap-northeast-2`인지 반드시 확인하세요.
> 다른 리전에서 리소스를 생성하면 이후 단계에서 오류가 발생합니다.

<!-- ![리전 선택](images/00-prerequisites/region-select.png) -->

## 0-3. Bedrock 모델 액세스 요청

Amazon Bedrock은 Foundation Model에 대한 **별도 액세스 요청**이 필요합니다.

### 요청할 모델

| 모델 | 용도 | 필수 여부 |
|------|------|----------|
| **Amazon Titan Text Embeddings V2** | 문서 임베딩 (벡터 변환) | 필수 |
| **Anthropic Claude 3.5 Sonnet** | 챗봇 응답 생성 | 필수 |
| Anthropic Claude 3 Haiku | 대체 모델 (비용 절약) | 선택 |

### 요청 방법

1. AWS 콘솔에서 **Amazon Bedrock** 서비스로 이동합니다
2. 좌측 메뉴에서 **Bedrock configurations** → **Model access**를 클릭합니다
3. **Modify model access** 버튼을 클릭합니다
4. 위 표의 모델들을 체크하고 **Next** → **Submit** 합니다

<!-- ![모델 액세스 요청](images/00-prerequisites/model-access.png) -->

> **승인 소요 시간**: Amazon Titan은 즉시 승인, Anthropic Claude는 수 분~수 시간 소요될 수 있습니다.
> 핸즈온 당일 아침에 **Access granted** 상태인지 반드시 확인하세요.

## 0-4. IAM 권한 확인

핸즈온에서 사용하는 서비스에 대한 권한이 필요합니다.

### 개인 계정인 경우

Admin 권한이 있으므로 별도 설정이 필요 없습니다.

### 조직 계정인 경우

아래 서비스에 대한 접근 권한이 있는지 확인하세요:
- Amazon S3 (버킷 생성/삭제)
- AWS DataSync (태스크 생성/실행)
- Amazon Bedrock (Knowledge Base 생성, 모델 호출)
- IAM (역할 생성 — Bedrock이 S3에 접근하기 위해 필요)

## 0-5. 준비 완료 체크리스트

실습 당일 시작 전에 확인하세요:

- [ ] AWS 콘솔에 **IAM 사용자**로 로그인 완료 (루트 사용자 X)
- [ ] 리전이 `ap-northeast-2` (서울)로 설정됨
- [ ] Bedrock 모델 액세스 상태가 **Access granted**
  - [ ] Amazon Titan Text Embeddings V2
  - [ ] Anthropic Claude 3.5 Sonnet (또는 Claude 3 Haiku)
- [ ] S3, DataSync, Bedrock 서비스에 접근 가능

---

**다음 단계**: [Module 1 — GCS → S3 전송](01-datasync-gcs-to-s3.md)

# Module 0 — 사전 준비

!!! warning "사전 완료 필수"
    이 모듈은 핸즈온 **최소 24시간 전에** 완료해야 합니다.
    Bedrock 모델 액세스 승인에 시간이 걸릴 수 있습니다.

## 0-1. AWS 계정 준비

AWS 계정이 없는 경우 [https://aws.amazon.com](https://aws.amazon.com)에서 생성합니다.

> 프리 티어 계정으로 충분합니다. 단, 결제 수단(신용카드) 등록이 필요합니다.

!!! danger "필수 확인"
    이 핸즈온은 **IAM 사용자**로 로그인해야 합니다. **루트 사용자(Root user)로는 Bedrock Knowledge Base를 생성할 수 없습니다.**
    IAM 사용자가 없는 경우 아래 절차로 생성하세요.

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

## 0-2. AWS CLI 설치 및 자격증명 등록

핸즈온 스크립트를 사용하려면 AWS CLI가 설치되어 있고, IAM 사용자의 자격증명이 등록되어야 합니다.

### AWS CLI v2 설치

| OS | 설치 명령 |
|----|-----------|
| macOS (Homebrew) | `brew install awscli` |
| macOS (공식 설치 파일) | [AWS CLI macOS 설치 가이드](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Windows | [AWS CLI MSI 설치 파일 다운로드](https://awscli.amazonaws.com/AWSCLIV2.msi) |
| Linux | `curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && sudo ./aws/install` |

설치 확인:
```bash
aws --version
# aws-cli/2.x.x Python/3.x.x ...
```

### IAM 사용자 Access Key 생성

1. AWS 콘솔에서 **IAM** → **Users** → 위에서 만든 사용자 클릭
2. **Security credentials** 탭 → **Access keys** → **Create access key**
3. Use case에서 **Command Line Interface (CLI)** 선택 → **Next**
4. **Create access key** 클릭
5. **Access Key ID**와 **Secret Access Key**를 안전한 곳에 복사해 둡니다

!!! warning "주의"
    Secret Access Key는 이 화면에서만 확인 가능합니다. 반드시 복사해 두세요.

### AWS CLI 자격증명 등록

```bash
aws configure
```

아래 항목을 입력합니다:

```
AWS Access Key ID [None]: <위에서 복사한 Access Key ID>
AWS Secret Access Key [None]: <위에서 복사한 Secret Access Key>
Default region name [None]: ap-northeast-2
Default output format [None]: json
```

등록 확인:
```bash
aws sts get-caller-identity
```

아래와 같이 계정 정보가 출력되면 성공입니다:
```json
{
    "UserId": "AIDAXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/scd26-admin"
}
```

## 0-3. 리전 설정

이번 핸즈온은 **`ap-northeast-2` (서울)** 리전에서 진행합니다.

- `aws configure`에서 이미 `ap-northeast-2`를 입력했다면, CLI는 준비 완료입니다.
- **AWS 콘솔**에서도 우측 상단의 리전 선택 드롭다운에서 **Asia Pacific (Seoul) ap-northeast-2**를 선택하세요.

!!! warning "리전 주의"
    콘솔과 CLI 모두 리전이 `ap-northeast-2`인지 반드시 확인하세요.
    다른 리전에서 리소스를 생성하면 이후 단계에서 오류가 발생합니다.

<!-- ![리전 선택](images/00-prerequisites/region-select.png) -->

## 0-4. Bedrock 모델 액세스 요청

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

!!! info "승인 소요 시간"
    Amazon Titan은 즉시 승인, Anthropic Claude는 수 분~수 시간 소요될 수 있습니다.
    핸즈온 당일 아침에 **Access granted** 상태인지 반드시 확인하세요.

## 0-5. IAM 권한 확인

핸즈온에서 사용하는 서비스에 대한 권한이 필요합니다.

### 개인 계정인 경우

Admin 권한이 있으므로 별도 설정이 필요 없습니다.

### 조직 계정인 경우

아래 서비스에 대한 접근 권한이 있는지 확인하세요:
- Amazon S3 (버킷 생성/삭제)
- AWS DataSync (태스크 생성/실행)
- Amazon Bedrock (Knowledge Base 생성, 모델 호출)
- IAM (역할 생성 — Bedrock이 S3에 접근하기 위해 필요)

## 0-6. 준비 완료 체크리스트

실습 당일 시작 전에 확인하세요:

- [ ] AWS 콘솔에 **IAM 사용자**로 로그인 완료 (루트 사용자 X)
- [ ] AWS CLI v2 설치 완료 (`aws --version` 확인)
- [ ] `aws configure` 완료 (`aws sts get-caller-identity` 확인)
- [ ] 리전이 `ap-northeast-2` (서울)로 설정됨 (콘솔 + CLI 모두)
- [ ] Bedrock 모델 액세스 상태가 **Access granted**
  - [ ] Amazon Titan Text Embeddings V2
  - [ ] Anthropic Claude 3.5 Sonnet (또는 Claude 3 Haiku)
- [ ] S3, DataSync, Bedrock 서비스에 접근 가능

---

**다음 단계**: [Module 1 — GCS → S3 전송](01-datasync-gcs-to-s3.md)

# Module 0 - 사전 준비

!!! info "이 핸즈온은 AWS Workshop Studio 계정으로 진행합니다"
    별도의 개인 AWS 계정이나 결제 수단이 필요 없습니다. 진행자가 안내하는 **참가 링크**로 접속하면
    실습용 임시 AWS 계정이 자동으로 제공되며, **US West (Oregon) `us-west-2`** 리전에서 진행합니다.
    이 계정은 이벤트가 끝나면 자동으로 회수됩니다.

!!! warning "리전 고정 안내"
    실습 계정은 **`us-west-2` (오레곤)** 리전으로 제한되어 있습니다.
    다른 리전(예: 서울)에서 리소스를 만들려고 하면 조직 정책(SCP)에 의해 `s3:CreateBucket`,
    DataSync 등이 차단되어 실습이 실패합니다. **항상 리전이 오레곤(us-west-2)인지 확인**하세요.

## 0-1. Workshop Studio 접속

1. 진행자가 안내한 **참가 링크**로 접속합니다 (형식: `https://catalog.us-east-1.prod.workshops.aws/join?access-code={당일 안내}`)
2. 로그인 방식 선택 화면이 나오면 **Email one-time password (OTP)** 등 안내된 방식으로 로그인합니다
3. 약관에 동의하고 **Join event**를 진행합니다
4. 왼쪽 하단(또는 안내된 위치)의 **Open AWS console**을 클릭해 실습 계정 콘솔로 들어갑니다

!!! tip "access code는 당일 발급"
    참가 링크의 access code는 진행자가 세션 당일 화면으로 안내합니다. 미리 공유된 코드가 있으면 그대로 사용하세요.

## 0-2. 리전 확인 (필수)

콘솔에 들어오면 **우측 상단 리전 선택 드롭다운**이 **US West (Oregon) us-west-2** 인지 확인합니다.

- 실습 계정의 기본 리전은 오레곤(us-west-2)입니다.
- 다른 리전으로 보이면 드롭다운에서 **US West (Oregon) us-west-2**로 변경하세요.

![AWS region setting](images/00-prerequisites/region-setting.png)

!!! danger "리전이 오레곤이 아니면"
    서울 등 다른 리전에서 진행하면 SCP 차단으로 S3 버킷 생성·DataSync가 실패합니다.
    이후 모든 단계(콘솔·CloudShell)를 반드시 **us-west-2**에서 진행하세요.

## 0-3. CloudShell 열기

핸즈온의 CLI 스크립트는 브라우저 내 **AWS CloudShell**에서 바로 실행합니다. 별도 설치·`aws configure`가 필요 없습니다.

1. 콘솔 우측 상단의 **CloudShell**(터미널 아이콘)을 클릭합니다
2. AWS CLI v2 · `git` · 로그인 자격증명이 **자동 적용**됩니다 (리전도 자동으로 us-west-2)
3. 아래 명령으로 계정·리전을 확인합니다:

```bash
echo "$AWS_REGION"            # us-west-2 로 나와야 함
aws sts get-caller-identity   # Arn 에 WSParticipantRole 이 보이면 정상
```

출력 예시:
```json
{
    "UserId": "AROAxxxxxxxxxxxxx:Participant",
    "Account": "339713087615",
    "Arn": "arn:aws:sts::339713087615:assumed-role/WSParticipantRole/Participant"
}
```

## 0-4. Bedrock 모델 확인

이번 핸즈온에서 사용하는 모델입니다. 오레곤(us-west-2)은 두 모델 모두 지원합니다.

| 모델 | 용도 | 비고 |
|------|------|------|
| **Amazon Titan Text Embeddings V2** | 문서 임베딩 (벡터 변환) | 자동 활성화 |
| **Anthropic Claude 3.5 Sonnet** | 챗봇 응답 생성 | 실습 계정에서 대부분 사전 활성화 |

확인 방법:

1. AWS 콘솔에서 **Amazon Bedrock** 서비스로 이동합니다 (리전 us-west-2 확인)
2. 좌측 메뉴에서 **모델 카탈로그**를 클릭합니다
3. **Claude 3.5 Sonnet**을 검색해 목록에 보이는지 확인합니다

![Bedrock Claude](images/00-prerequisites/bedrock-claude.png)

!!! info "모델 접근이 막혀 있다면"
    실습 계정은 보통 모델이 사전 활성화되어 있습니다. 만약 KB 테스트에서 "모델 접근 불가"가 나오면,
    모델 카탈로그에서 해당 모델의 **Request model access**(또는 playground 진입 시 안내 양식)를 진행하세요.
    제출하면 대개 즉시 부여됩니다. 상황에 따라 진행자에게 문의하세요.

## 0-5. 준비 완료 체크리스트

핸즈온을 시작하기 전에 확인하세요:

- [ ] Workshop Studio 참가 링크로 접속 → **Open AWS console** 완료
- [ ] 콘솔 리전이 **US West (Oregon) us-west-2**로 설정됨
- [ ] **CloudShell**을 열고 `aws sts get-caller-identity`로 `WSParticipantRole` 확인
- [ ] Bedrock에서 **Anthropic Claude 3.5 Sonnet** / **Titan Text Embeddings V2** 사용 가능

---

**다음 단계**: [Module 1 : GCS → S3 전송](01-datasync-gcs-to-s3.md)

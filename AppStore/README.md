# App Store Assets

Mac App Store 제출용 메타데이터와 스크린샷 자산입니다.

## 생성

```bash
swift scripts/generate_app_store_assets.swift
```

생성 결과:

- `AppStore/icons/file-stack-app-store-icon-1024.png`
- `AppStore/screenshots/mac/ko-KR/*.png`

실촬영 스크린샷 생성:

```bash
scripts/capture_real_screenshots.sh
```

생성 결과:

- `AppStore/screenshots-real/mac/ko-KR/*.png`

## 현재 규격

Apple App Store Connect 공식 도움말 기준으로, 2026-05-04 시점의 Mac 스크린샷은 다음 16:10 규격 중 하나를 사용합니다.

- `1280 x 800`
- `1440 x 900`
- `2560 x 1600`
- `2880 x 1800`

이 프로젝트는 가장 여유 있는 `2560 x 1600`으로 생성합니다.

공식 참고:

- https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications

## 메타데이터

기본 한국어 초안:

- `AppStore/metadata/ko-KR.json`

업로드 전에 다음 값은 실제 운영 값으로 교체하세요.

- `privacyPolicyUrl`

## 의도

스크린샷은 실제 앱 UI인 `Resources/preview.png`를 기반으로 하되, App Store 소개용 문구와 강조 요소를 덧붙여 한눈에 핵심 가치를 전달하도록 구성합니다.

`scripts/capture_real_screenshots.sh`는 fixture 파일을 만든 뒤 앱을 screenshot mode로 실행해 실제 렌더링된 UI를 `2560x1600` 이미지로 저장합니다.

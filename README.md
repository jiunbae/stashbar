## File Stack

![File Stack Hero](Resources/hero.png)

Mac 메뉴 막대에서 빠르게 최근 파일을 모아보는 파일 관리 도구입니다. 감시할 폴더를 지정하면 스크린샷이나 다운로드 파일을 즉시 확인하고, 미리보기 크기 조절·빠른 선택·클립보드 작업 등을 Finder처럼 자연스럽게 사용할 수 있습니다.

### 미리보기

![File Stack 미리보기](Resources/preview.png)

### 주요 기능

- 여러 감시 폴더를 등록하고 폴더별로 최신 파일을 표시
- 이름·종류·수정 날짜·크기 기준 오름/내림차순 정렬
- 아이콘/목록/계층 보기 모드 전환 및 슬라이더로 미리보기 크기 조절
- Finder 스타일의 다중 선택, `⌘C/⌘X/⌘V`, `⌘⌫`(휴지통), Space(Quick Look) 단축키 지원
- 선택한 항목을 더블 클릭하거나 컨텍스트 메뉴로 바로 열기/찾아보기
- 로그인 시 자동 실행, 기본 보기 모드, 감시 폴더 관리를 설정 화면에서 구성

### 시스템 요구사항

- macOS 13.0 이상

### 빌드 및 실행

개발 중 실행:

```bash
swift build
swift run
```

배포용 `.app` 번들 생성:

```bash
scripts/build_app.sh
# 결과물: dist/File Stack.app
```

또는 Xcode에서 프로젝트를 열어 `FileStackApp` 타깃을 실행하면 됩니다.

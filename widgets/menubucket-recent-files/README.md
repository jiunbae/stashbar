# Stashbar Recent Files — BarShelf 위젯

[Stashbar](https://github.com/jiunbae/stashbar) 스타일의 "최근 파일" 경험을 [BarShelf](https://github.com/Open330/barshelf) 메뉴바 위젯으로 제공합니다. 지정한 폴더(기본: `~/Downloads`)의 최근 파일을 QuickLook 썸네일과 함께 세 가지 보기 모드로 보여주고, 클릭으로 열기·드래그로 다른 앱에 바로 옮길 수 있습니다.

## 설치

BarShelf가 설치되어 있다면:

```bash
barshelf install https://github.com/jiunbae/stashbar
```

[![BarShelf 설치](https://img.shields.io/badge/BarShelf-Install-0A84FF)](barshelf://install?url=https%3A%2F%2Fgithub.com%2Fjiunbae%2Fstashbar)

설치 후 위젯 설정에서 감시할 폴더, 보기 모드, 최대 파일 개수, 썸네일 크기를 변경할 수 있습니다.

## 기능

- **3가지 보기 모드** — 미리보기(최신 파일 히어로 카드 + 나머지 목록), 그리드(썸네일 타일), 리스트(검색 가능한 행)
- 폴더의 최근 파일을 수정 시각 순으로 표시 (파일 시스템 watch로 자동 갱신)
- QuickLook 기반 파일 썸네일, 썸네일 크기 조절
- 리스트 모드 로컬 검색 (위젯 재실행 없이 행 필터링)
- 클릭으로 파일 열기, 돋보기 버튼으로 Finder에서 보기
- 드래그 앤 드롭으로 다른 앱/Finder로 바로 이동

## Stashbar 앱과의 관계

이 위젯은 네이티브 macOS 앱인 **Stashbar**(이 저장소)의 핵심 경험을 BarShelf 워크플로우로 옮긴 경량 버전입니다. 다중 폴더 감시, Finder 단축키(⌘C/⌘X/⌘V, ⌘⌫), Space Quick Look, 디스크 썸네일 캐시 등 전체 기능이 필요하다면 [Stashbar 앱](https://github.com/jiunbae/stashbar)을 사용하세요.

- 위젯 스펙: [BarShelf docs](https://github.com/Open330/barshelf)
- 라이선스: 저장소 루트의 [LICENSE](../../LICENSE) (MIT)

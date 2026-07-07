# Stashbar — App Store Review Support

## Overview

Stashbar is a lightweight menu bar utility for macOS that lets users pin frequently-accessed folders to the menu bar and instantly browse their recent files. It is built entirely within the macOS App Sandbox and uses only Apple-approved APIs.

---

## Review Notes for App Store Connect

### English

> Stashbar is a menu bar utility (LSUIElement) for macOS that lets users watch selected folders and browse recent files from the menu bar.
>
> **Sandbox & Folder Access:**
> - The app uses NSOpenPanel to let users explicitly select folders they want to watch. No folders are accessed without explicit user action.
> - Folder access permissions are persisted using security-scoped bookmarks (NSData with .withSecurityScope) so the app can continue monitoring across launches within the App Sandbox.
> - The app does not access any system folders, home directory contents, or user files outside of the folders explicitly chosen by the user.
>
> **Network & Data:**
> - The app does not make any network requests. All functionality is local.
> - No user data, analytics, crash reports, or diagnostics are collected or transmitted.
> - Thumbnail caching is performed entirely on-device using QuickLookThumbnailing and a local disk cache in ~/Library/Caches/.
>
> **Launch at Login:**
> - The "Launch at Login" feature uses Apple's modern SMAppService API (ServiceManagement framework), which is the recommended approach for sandboxed Mac apps.
>
> **Quick Look & File Operations:**
> - Quick Look previews use the standard QLPreviewPanel system API.
> - Copy, cut, paste, and trash operations use standard NSPasteboard and NSWorkspace APIs.
>
> **Localization:** The app is localized in Korean and English.

### Korean

> Stashbar는 macOS 메뉴바 유틸리티(LSUIElement)로, 사용자가 선택한 폴더를 감시하고 메뉴바에서 최근 파일을 탐색할 수 있습니다.
>
> **샌드박스 및 폴더 접근:**
> - NSOpenPanel을 통해 사용자가 직접 폴더를 선택해야만 감시가 시작됩니다. 사용자의 명시적 동의 없이는 어떤 폴더에도 접근하지 않습니다.
> - 폴더 접근 권한은 security-scoped bookmark(NSData with .withSecurityScope)를 사용하여 영속화되며, App Sandbox 내에서 앱 재실행 후에도 접근이 유지됩니다.
> - 사용자가 명시적으로 선택한 폴더 외의 시스템 폴더, 홈 디렉토리 내용, 기타 사용자 파일에 접근하지 않습니다.
>
> **네트워크 및 데이터:**
> - 앱은 어떤 네트워크 요청도 수행하지 않습니다. 모든 기능은 로컬에서 동작합니다.
> - 사용자 데이터, 분석, 충돌 보고서, 진단 정보를 수집하거나 전송하지 않습니다.
> - 썸네일 캐싱은 QuickLookThumbnailing과 ~/Library/Caches/ 내 로컬 디스크 캐시를 사용하여 기기 내에서만 수행됩니다.
>
> **로그인 시 자동 실행:**
> - "로그인 시 자동 실행" 기능은 Apple의 현대적인 SMAppService API(ServiceManagement 프레임워크)를 사용하며, 샌드박스 Mac 앱에 권장되는 방식입니다.
>
> **퀵 룩 및 파일 작업:**
> - 퀵 룩 미리보기는 표준 QLPreviewPanel 시스템 API를 사용합니다.
> - 복사, 잘라내기, 붙여넣기, 휴지통 이동은 표준 NSPasteboard 및 NSWorkspace API를 사용합니다.
>
> **현지화:** 한국어 및 영어를 지원합니다.

---

## Testing Account / Demo Data

No account is required. The app works entirely with the user's local file system.

To test the app:
1. Launch Stashbar from the menu bar.
2. Click the + button or drop a folder into the popover to add a watched folder.
3. Browse recent files, switch folders, sort, change view modes, use Quick Look (Space), and perform file operations (copy/paste/trash).

---

## Known Issues / Notes for Reviewer

- The app is a menu bar utility (LSUIElement = true). It does not appear in the Dock and has no main application window. Access it via the menu bar icon.
- On first launch, the user must add at least one folder via NSOpenPanel before any files are displayed.
- The "Launch at Login" toggle in Settings requires the user to approve the helper in System Settings → General → Login Items.

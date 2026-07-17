(() => {
  "use strict";

  const copy = {
    ko: {
      documentTitle: "Stashbar — 메뉴바의 최근 파일",
      metaDescription: "자주 보는 폴더의 최근 파일을 메뉴바에서 한눈에. macOS 전용 생산성 유틸리티.",
      ogTitle: "Stashbar — 메뉴바의 최근 파일",
      ogDescription: "자주 보는 폴더의 최근 파일을 메뉴바에서 한눈에. macOS 전용 생산성 유틸리티.",
      languageLabel: "언어 선택",
      navScreens: "스크린샷",
      navFeatures: "기능",
      navPrivacy: "개인정보",
      storeAria: "Mac App Store에서 Stashbar 받기",
      heroKicker: "macOS menu bar utility",
      heroTitle: '<span class="headline-line">최근 파일은</span><span class="headline-line">Finder보다 가까이.</span>',
      heroTagline: "자주 보는 폴더를 메뉴바에 고정하세요. 최신 파일을 확인하고, 미리 보고, 필요한 작업까지 한곳에서 이어갑니다.",
      storeCTA: "Mac App Store에서 받기",
      githubCTA: "GitHub 바로가기",
      factsAria: "Stashbar 주요 정보",
      factFree: "무료",
      factMenuBar: "메뉴바 전용",
      factNoData: "데이터 수집 없음",
      heroAlt: "Stashbar에서 Screenshots 폴더의 최근 파일을 아이콘 보기로 표시한 메뉴바 팝오버",
      screensEyebrow: "화면 보기",
      screensTitle: "폴더마다 편한 방식으로",
      screensDescription: "아이콘, 목록, 계층 보기를 전환하고 여러 폴더를 같은 자리에서 확인하세요.",
      shot1Alt: "아이콘 그리드 보기",
      shot1Caption: "아이콘 보기 — 썸네일로 한눈에 파악",
      shot2Alt: "다중 폴더 전환",
      shot2Caption: "다중 폴더 — 드롭다운으로 즉시 전환",
      shot3Alt: "목록 보기",
      shot3Caption: "목록 보기 — 정렬과 메타데이터 한눈에",
      shot4Alt: "계층 보기",
      shot4Caption: "계층 보기 — 하위 폴더까지 펼쳐서",
      featuresEyebrow: "기능",
      featuresTitle: "꼭 필요한 것만, 잘 만들어진",
      featuresDescription: "반복적으로 파일을 열고 확인하는 흐름을 더 짧고 자연스럽게 만드는 데 집중했습니다.",
      feature1Title: "여러 폴더 동시 감시",
      feature1Body: "스크린샷, 다운로드, 작업 폴더처럼 자주 여는 위치를 추가하면 실시간으로 변경사항이 반영됩니다.",
      feature2Title: "3가지 보기 모드",
      feature2Body: "아이콘, 목록, 계층 보기 — 상황에 맞게 전환하고 슬라이더로 미리보기 크기를 조절합니다.",
      feature3Title: "Quick Look 미리보기",
      feature3Body: "<kbd>Space</kbd> 키로 선택한 파일을 즉시 미리보기 — 선택을 바꾸면 자동으로 갱신됩니다.",
      feature4Title: "Finder 단축키 그대로",
      feature4Body: "복사(<kbd>⌘C</kbd>), 잘라내기(<kbd>⌘X</kbd>), 붙여넣기(<kbd>⌘V</kbd>), 휴지통(<kbd>⌘⌫</kbd>) — 익숙한 그대로.",
      feature5Title: "드래그 앤 드롭",
      feature5Body: "메뉴바 팝오버에서 다른 앱이나 Finder 창으로 파일을 바로 드래그할 수 있습니다.",
      feature6Title: "디스크 썸네일 캐시",
      feature6Body: "썸네일이 디스크에 저장되어 앱을 재실행해도 즉시 표시됩니다.",
      feature7Title: "로그인 시 자동 실행",
      feature7Body: "모던 <code>SMAppService</code> 기반 — 부팅 후 항상 메뉴바에서 대기합니다.",
      feature8Title: "App Sandbox 호환",
      feature8Body: "Security-scoped bookmark로 사용자가 선택한 폴더 접근만 안전하게 영속화합니다.",
      privacyTitle: "설계부터 프라이버시 우선",
      privacyBody: "Stashbar은 데이터를 수집하지 않으며 네트워크 연결도 사용하지 않습니다. 여러분이 선택한 폴더만, 여러분의 Mac 안에서만 처리합니다.",
      privacyCTA: "개인정보 처리방침 보기 →",
      footerPrivacy: "개인정보 처리방침",
      footerSupport: "지원"
    },
    en: {
      documentTitle: "Stashbar — Recent files in your menu bar",
      metaDescription: "Pin your favorite folders to the menu bar and open recent files without a Finder detour. A private macOS utility.",
      ogTitle: "Stashbar — Recent files in your menu bar",
      ogDescription: "Pin favorite folders to the menu bar, preview recent files, and keep Finder shortcuts within reach.",
      languageLabel: "Language",
      navScreens: "Screens",
      navFeatures: "Features",
      navPrivacy: "Privacy",
      storeAria: "Get Stashbar on the Mac App Store",
      heroKicker: "macOS menu bar utility",
      heroTitle: '<span class="headline-line">Recent files.</span><span class="headline-line">Closer than Finder.</span>',
      heroTagline: "Pin the folders you check most to the menu bar. Find the latest file, preview it, and continue working without opening a Finder window first.",
      storeCTA: "Get it on the Mac App Store",
      githubCTA: "View on GitHub",
      factsAria: "Stashbar highlights",
      factFree: "Free",
      factMenuBar: "Built for the menu bar",
      factNoData: "No data collection",
      heroAlt: "Stashbar menu bar popover showing recent files from the Screenshots folder in icon view",
      screensEyebrow: "Screens",
      screensTitle: "A view for every folder",
      screensDescription: "Switch between icon, list, and hierarchy views while keeping every pinned folder in the same place.",
      shot1Alt: "Icon grid view",
      shot1Caption: "Icon view — scan thumbnails at a glance",
      shot2Alt: "Switching between pinned folders",
      shot2Caption: "Pinned folders — switch instantly from the menu",
      shot3Alt: "List view",
      shot3Caption: "List view — sort and compare metadata",
      shot4Alt: "Hierarchy view",
      shot4Caption: "Hierarchy view — expand nested folders in place",
      featuresEyebrow: "Features",
      featuresTitle: "The file tools you need, close at hand",
      featuresDescription: "Stashbar shortens the repeated work of finding, previewing, and acting on files throughout the day.",
      feature1Title: "Watch multiple folders",
      feature1Body: "Add screenshots, downloads, and project folders. Changes appear as they happen.",
      feature2Title: "Three view modes",
      feature2Body: "Switch between icon, list, and hierarchy views, then tune preview size with the slider.",
      feature3Title: "Quick Look previews",
      feature3Body: "Press <kbd>Space</kbd> to preview the selected file. The preview follows as your selection changes.",
      feature4Title: "Familiar Finder shortcuts",
      feature4Body: "Copy (<kbd>⌘C</kbd>), cut (<kbd>⌘X</kbd>), paste (<kbd>⌘V</kbd>), and move to Trash (<kbd>⌘⌫</kbd>) without relearning anything.",
      feature5Title: "Drag and drop",
      feature5Body: "Drag files straight from the menu bar popover into Finder or another app.",
      feature6Title: "On-disk thumbnail cache",
      feature6Body: "Cached thumbnails appear immediately, even after relaunching the app.",
      feature7Title: "Launch at login",
      feature7Body: "Built on <code>SMAppService</code>, Stashbar is ready in the menu bar after you sign in.",
      feature8Title: "App Sandbox ready",
      feature8Body: "Security-scoped bookmarks preserve access only to the folders you explicitly choose.",
      privacyTitle: "Private by design",
      privacyBody: "Stashbar collects no data and makes no network requests. Only the folders you choose are accessed, entirely on your Mac.",
      privacyCTA: "Read the privacy policy →",
      footerPrivacy: "Privacy Policy",
      footerSupport: "Support"
    }
  };

  const supportedLanguages = new Set(Object.keys(copy));
  const requestedLanguage = new URLSearchParams(window.location.search).get("lang");
  let savedLanguage = null;

  try {
    savedLanguage = window.localStorage.getItem("stashbar-language");
  } catch (_) {
    // Storage can be unavailable in strict privacy modes; the URL still works.
  }

  const language = supportedLanguages.has(requestedLanguage)
    ? requestedLanguage
    : supportedLanguages.has(savedLanguage)
      ? savedLanguage
      : "ko";
  const strings = copy[language];

  document.documentElement.lang = language;
  document.title = strings.documentTitle;

  const description = document.querySelector('meta[name="description"]');
  const ogTitle = document.querySelector('meta[property="og:title"]');
  const ogDescription = document.querySelector('meta[property="og:description"]');
  if (description) description.content = strings.metaDescription;
  if (ogTitle) ogTitle.content = strings.ogTitle;
  if (ogDescription) ogDescription.content = strings.ogDescription;

  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const value = strings[element.dataset.i18n];
    if (value !== undefined) element.textContent = value;
  });

  document.querySelectorAll("[data-i18n-html]").forEach((element) => {
    const value = strings[element.dataset.i18nHtml];
    if (value !== undefined) element.innerHTML = value;
  });

  document.querySelectorAll("[data-i18n-alt]").forEach((element) => {
    const value = strings[element.dataset.i18nAlt];
    if (value !== undefined) element.alt = value;
  });

  document.querySelectorAll("[data-i18n-aria]").forEach((element) => {
    const value = strings[element.dataset.i18nAria];
    if (value !== undefined) element.setAttribute("aria-label", value);
  });

  document.querySelectorAll("[data-language]").forEach((link) => {
    if (link.dataset.language === language) {
      link.setAttribute("aria-current", "page");
    } else {
      link.removeAttribute("aria-current");
    }
  });

  document.querySelectorAll("[data-language-href]").forEach((link) => {
    link.href = `${link.dataset.languageHref}?lang=${language}`;
  });

  try {
    window.localStorage.setItem("stashbar-language", language);
  } catch (_) {
    // No persistence is required for the page to remain fully functional.
  }
})();

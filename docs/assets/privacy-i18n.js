(() => {
  "use strict";

  const copy = {
    ko: {
      documentTitle: "개인정보 처리방침 — Stashbar",
      metaDescription: "Stashbar 개인정보 처리방침 — 데이터 수집 없음, 네트워크 연결 없음, 모든 처리는 기기 안에서만.",
      languageLabel: "언어 선택",
      heading: "개인정보 처리방침",
      effectiveDate: "시행일: 2026년 5월 5일",
      intro: "Stashbar은 개인정보 보호를 핵심 원칙으로 설계된 macOS 메뉴바 유틸리티입니다. 이 방침은 앱이 어떤 데이터를 다루며 어떻게 보호하는지 설명합니다.",
      section1Title: "1. 수집하는 데이터",
      section1Paragraph1: "Stashbar은 개인정보, 분석 데이터 또는 사용 통계를 <strong>수집하지 않습니다.</strong>",
      section1Paragraph2: "앱은 사용자가 명시적으로 선택한 폴더에만 접근합니다. 선택한 폴더 경로는 앱 재실행 후에도 샌드박스 접근을 유지하기 위해 security-scoped bookmark 형태로 Mac에만 저장됩니다. 파일 내용은 기기 밖에서 읽거나 전송하거나 저장하지 않습니다.",
      section2Title: "2. 데이터 사용 방식",
      section2Paragraph: "저장된 폴더 경로는 메뉴바에서 선택한 폴더를 표시하고 관리하는 앱의 핵심 기능에만 사용됩니다.",
      thumbnailCache: "<strong>썸네일 캐시:</strong> 성능 향상을 위해 생성된 썸네일을 <code>~/Library/Caches/</code>에 저장할 수 있습니다. 캐시는 기기에만 보관되며 전송되지 않습니다.",
      launchAtLogin: "<strong>로그인 시 자동 실행:</strong> 이 기능을 켜면 macOS가 <code>SMAppService</code>를 통해 설정을 관리합니다. 계정이나 개인정보는 사용하지 않습니다.",
      section3Title: "3. 데이터 공유",
      section3Paragraph: "Stashbar은 어떤 데이터도 제3자와 <strong>공유하지 않습니다.</strong> 앱에는 네트워크 연결 기능이 없으며 기기 밖으로 정보를 전송하지 않습니다.",
      section4Title: "4. 사용자의 권리와 제어",
      section4Paragraph: "모든 폴더 접근 권한은 사용자가 직접 제어합니다.",
      control1: "Stashbar에 추가할 폴더를 사용자가 직접 선택합니다.",
      control2: "폴더를 언제든 제거할 수 있으며, 제거 즉시 해당 폴더에 대한 앱의 접근 권한이 해제됩니다.",
      control3: "표준 macOS 방식으로 Stashbar을 삭제할 수 있으며, 북마크와 캐시를 포함한 로컬 저장 데이터도 함께 제거됩니다.",
      section5Title: "5. 보안",
      section5Paragraph: "Stashbar은 macOS App Sandbox 안에서 동작합니다. 폴더 접근 권한은 Apple의 security-scoped bookmark 기술로 부여하고 유지하므로 사용자가 명시적으로 허용한 폴더로만 접근 범위가 제한됩니다.",
      section6Title: "6. 문의",
      section6Paragraph1: "개인정보 처리방침이나 Stashbar의 데이터 처리 방식에 관해 궁금한 점이 있으면 아래 주소로 문의해 주세요.",
      section6Paragraph2: "투명한 운영을 약속하며 문의에 가능한 한 신속하게 답변하겠습니다.",
      footerNote: "이 개인정보 처리방침은 필요에 따라 변경될 수 있으며, 변경 시 시행일과 함께 이 페이지에 게시합니다.",
      backToStashbar: "← Stashbar로 돌아가기"
    },
    en: {
      documentTitle: "Privacy Policy — Stashbar",
      metaDescription: "Stashbar privacy policy — no data collection, no network, all processing stays on your Mac.",
      languageLabel: "Language",
      heading: "Privacy Policy",
      effectiveDate: "Effective Date: May 5, 2026",
      intro: "Stashbar is a menu bar utility for macOS designed with privacy as a core principle. This policy explains what data is handled and how it is protected.",
      section1Title: "1. Data We Collect",
      section1Paragraph1: "Stashbar does <strong>not</strong> collect personal data, analytics, or usage statistics.",
      section1Paragraph2: "The app accesses <strong>only</strong> the folders you explicitly select within the app. The paths of these selected folders are stored locally on your Mac as security-scoped bookmarks to maintain sandbox access across app launches. No file contents are ever read, transmitted, or stored outside of your device.",
      section2Title: "2. How Data Is Used",
      section2Paragraph: "All stored folder paths are used <strong>solely</strong> to provide the app's core functionality: displaying and managing your selected folders from the menu bar.",
      thumbnailCache: "<strong>Thumbnail Cache:</strong> The app may cache generated thumbnails locally in <code>~/Library/Caches/</code> to improve performance. This cache is stored on your device and is never transmitted.",
      launchAtLogin: "<strong>Launch at Login:</strong> If enabled, macOS manages this preference via <code>SMAppService</code>. No account or personal data is involved.",
      section3Title: "3. Data Sharing",
      section3Paragraph: "Stashbar <strong>does not</strong> share any data with third parties. The app has no network connectivity and does not transmit any information off your device.",
      section4Title: "4. Your Rights and Control",
      section4Paragraph: "You have full control over all folder access:",
      control1: "You choose which folders to add to Stashbar.",
      control2: "You may remove folders from Stashbar at any time, which immediately revokes the app's access to those folders.",
      control3: "You can uninstall Stashbar at any time via standard macOS methods, which removes all locally stored data including bookmarks and caches.",
      section5Title: "5. Security",
      section5Paragraph: "Stashbar operates within the macOS app sandbox. Folder access is granted and persisted using Apple's security-scoped bookmark technology, ensuring access is limited to only the folders you explicitly authorize.",
      section6Title: "6. Contact Information",
      section6Paragraph1: "If you have any questions or concerns about this privacy policy or Stashbar's data practices, please contact us at:",
      section6Paragraph2: "We are committed to transparency and will respond to inquiries as promptly as possible.",
      footerNote: "This privacy policy may be updated occasionally. Any changes will be posted here with an updated effective date.",
      backToStashbar: "← Back to Stashbar"
    }
  };

  const supportedLanguages = new Set(Object.keys(copy));
  const requestedLanguage = new URLSearchParams(window.location.search).get("lang");
  let savedLanguage = null;

  try {
    savedLanguage = window.localStorage.getItem("stashbar-language");
  } catch (_) {
    // The URL parameter remains sufficient when storage is unavailable.
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
  if (description) description.content = strings.metaDescription;

  document.querySelectorAll("[data-i18n]").forEach((element) => {
    const value = strings[element.dataset.i18n];
    if (value !== undefined) element.textContent = value;
  });

  document.querySelectorAll("[data-i18n-html]").forEach((element) => {
    const value = strings[element.dataset.i18nHtml];
    if (value !== undefined) element.innerHTML = value;
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

  document.querySelectorAll("[data-language-home]").forEach((link) => {
    link.href = `./?lang=${language}`;
  });

  try {
    window.localStorage.setItem("stashbar-language", language);
  } catch (_) {
    // Persistence is optional.
  }
})();

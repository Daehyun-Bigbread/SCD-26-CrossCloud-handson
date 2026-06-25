const STORAGE_KEY = "scd26-workshop-progress";
const MODULES = ["0", "1", "2", "3"];

const MODULE_DATA = [
  {
    id: "0",
    title: "Module 0 - 사전 준비",
    url: "00-prerequisites/",
    sections: [
      { title: "AWS 계정 준비", sub: "IAM 사용자 생성 및 콘솔 로그인" },
      { title: "AWS CLI 설치", sub: "자격증명 등록 및 리전 설정" },
      { title: "Bedrock 모델 액세스", sub: "Claude 3.5 Sonnet, Titan Embeddings 요청" },
    ],
  },
  {
    id: "1",
    title: "Module 1 - GCS → S3 전송",
    url: "01-datasync-gcs-to-s3/",
    sections: [
      { title: "S3 버킷 생성", sub: "DataSync 대상 버킷 준비" },
      { title: "DataSync 설정", sub: "GCS 위치 및 HMAC 키 연결" },
      { title: "데이터 동기화", sub: "GCS 문서를 S3로 전송" },
    ],
  },
  {
    id: "2",
    title: "Module 2 - Bedrock Knowledge Bases",
    url: "02-bedrock-kb-create/",
    sections: [
      { title: "Knowledge Base 생성", sub: "S3 데이터 소스 연결" },
      { title: "임베딩 모델 설정", sub: "Titan Text Embeddings V2 선택" },
      { title: "데이터 동기화", sub: "문서 파싱 → 청킹 → 임베딩 → 인덱싱" },
    ],
  },
  {
    id: "3",
    title: "Module 3 - RAG 챗봇 테스트 & 리소스 정리",
    url: "03-chatbot-test/",
    sections: [
      { title: "KB 테스트 패널", sub: "Claude 3.5 Sonnet으로 RAG 질의응답" },
      { title: "RAG 응답 검증", sub: "출처 확인 및 환각 거절 테스트" },
      { title: "리소스 정리", sub: "KB / OpenSearch / S3 / DataSync 삭제 (과금 방지)" },
    ],
  },
];

function getProgress() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {};
  } catch {
    return {};
  }
}

function saveProgress(data) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  } catch {
    // private browsing or storage full
  }
}

function getCurrentModule() {
  const path = window.location.pathname;
  const match = path.match(/0(\d)-/);
  return match ? match[1] : null;
}

function isHomePage() {
  const path = window.location.pathname;
  const homePatterns = [
    /\/SCD-26-CrossCloud-handson\/?$/,
    /\/handson\/?$/,
    /^\/$/,
  ];
  if (homePatterns.some((p) => p.test(path))) return true;
  if (path.endsWith("/index.html") && !path.match(/0\d-/)) return true;
  return !!document.querySelector(".asb-course-page");
}

function getModuleStatus(modId, progress) {
  if (progress[modId]) return "completed";
  const firstIncomplete = MODULES.find((m) => !progress[m]);
  if (modId === firstIncomplete) return "active";
  return "pending";
}

function statusLabel(status) {
  if (status === "completed") return "완료";
  if (status === "active") return "진행 중";
  return "시작되지 않음";
}

function getResumeModule(progress) {
  const firstIncomplete = MODULES.find((m) => !progress[m]);
  const modId = firstIncomplete || MODULES[MODULES.length - 1];
  return MODULE_DATA.find((m) => m.id === modId);
}

function renderTimeline(activeId) {
  const timeline = document.getElementById("asb-timeline");
  if (!timeline) return;

  const progress = getProgress();
  timeline.innerHTML = MODULE_DATA.map((mod) => {
    const status = getModuleStatus(mod.id, progress);
    const isActive = mod.id === activeId;
    const cls = [
      "asb-timeline-item",
      status === "active" || isActive ? "is-active" : "",
      status === "completed" ? "is-completed" : "",
    ].filter(Boolean).join(" ");

    return `
      <button class="${cls}" data-module-id="${mod.id}" type="button">
        <span class="asb-timeline-dot"></span>
        <span class="asb-timeline-status">${statusLabel(isActive ? "active" : status)}</span>
        <span class="asb-timeline-title">${mod.title}</span>
      </button>`;
  }).join("");

  timeline.querySelectorAll(".asb-timeline-item").forEach((btn) => {
    btn.addEventListener("click", () => {
      renderModulePanel(btn.getAttribute("data-module-id"));
      renderTimeline(btn.getAttribute("data-module-id"));
    });
  });
}

function renderModulePanel(modId) {
  const panel = document.getElementById("asb-module-panel");
  if (!panel) return;

  const mod = MODULE_DATA.find((m) => m.id === modId);
  if (!mod) return;

  const sectionsHtml = mod.sections.map((s) => `
    <div class="asb-panel-section">
      <p class="asb-panel-section-title">${s.title}</p>
      <p class="asb-panel-section-sub">${s.sub}</p>
    </div>`).join("");

  panel.innerHTML = `
    <h2 class="asb-panel-title">${mod.title}</h2>
    <a href="${mod.url}" class="asb-btn asb-btn-primary">이어서 하기</a>
    <div class="asb-panel-sections">${sectionsHtml}</div>`;
}

function updateResumeCard() {
  const progress = getProgress();
  const mod = getResumeModule(progress);
  if (!mod) return;

  const heading = document.getElementById("asb-resume-module");
  const link = document.getElementById("asb-resume-link");
  if (heading) heading.textContent = mod.title;
  if (link) link.href = mod.url;
}

function updateProgressBar() {
  const progress = getProgress();
  const completed = MODULES.filter((m) => progress[m]).length;
  const pct = (completed / MODULES.length) * 100;

  const bar = document.getElementById("workshop-progress-bar");
  if (!bar) return;

  if (isHomePage()) {
    bar.style.display = "none";
    return;
  }

  bar.style.display = "";
  const fill = document.getElementById("progress-fill");
  if (fill) fill.style.width = pct + "%";

  const count = document.getElementById("progress-count");
  if (count) count.textContent = completed + " / " + MODULES.length + " 모듈";

  document.querySelectorAll("#progress-steps .step").forEach((el) => {
    const mod = el.getAttribute("data-module");
    el.classList.toggle("completed", !!progress[mod]);
  });
}

function updateSidebarProgress() {
  // sidebar title is hidden; no-op
}

function updateSidebarIcons() {
  const progress = getProgress();
  document.querySelectorAll(".md-nav__link").forEach((link) => {
    const href = link.getAttribute("href") || "";
    const match = href.match(/0(\d)-/);
    if (match) {
      link.classList.toggle("module-done", !!progress[match[1]]);
    }
  });
}

function updateCompleteButton() {
  const mod = getCurrentModule();
  const section = document.getElementById("module-complete-section");
  if (!mod || !section) return;

  section.style.display = "";
  const progress = getProgress();
  const done = !!progress[mod];

  const icon = document.getElementById("btn-complete-icon");
  const text = document.getElementById("btn-complete-text");
  const btn = document.getElementById("btn-complete-module");

  if (icon) icon.textContent = done ? "✅" : "☐";
  if (text) text.textContent = done ? "완료됨 (클릭하여 해제)" : "이 모듈을 완료로 표시";
  if (btn) btn.classList.toggle("is-completed", done);
}

function handleTabClick(e) {
  const tab = e.currentTarget;
  const target = tab.getAttribute("data-tab");
  document.querySelectorAll(".asb-tab").forEach((t) => {
    t.classList.toggle("asb-tab-active", t === tab);
    t.setAttribute("aria-selected", t === tab ? "true" : "false");
  });
  document.getElementById("asb-panel-overview")?.classList.toggle("asb-hidden", target !== "overview");
  document.getElementById("asb-panel-details")?.classList.toggle("asb-hidden", target !== "details");
}

function initTabs() {
  const tabs = document.querySelectorAll(".asb-tab");
  if (!tabs.length) return;

  tabs.forEach((tab) => {
    tab.removeEventListener("click", handleTabClick);
    tab.addEventListener("click", handleTabClick);
  });
}

function initHomePage() {
  const isHome = !!document.querySelector(".asb-course-page");
  document.body.classList.toggle("asb-home", isHome);
  if (!isHome) return;
  const progress = getProgress();
  const resumeMod = getResumeModule(progress);
  const activeId = resumeMod ? resumeMod.id : "0";

  renderTimeline(activeId);
  renderModulePanel(activeId);
  updateResumeCard();
  initTabs();
}

function toggleModule(mod) {
  const progress = getProgress();
  progress[mod] = !progress[mod];
  saveProgress(progress);
  refreshAll();
}

function refreshAll() {
  updateProgressBar();
  updateSidebarProgress();
  updateSidebarIcons();
  updateCompleteButton();
  updateResumeCard();
  initHomePage();
}

window.workshopProgress = {
  toggleCurrentModule: function () {
    const mod = getCurrentModule();
    if (mod) toggleModule(mod);
  },
};

function init() {
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", refreshAll);
  } else {
    refreshAll();
  }
}

init();

if (typeof document$ !== "undefined") {
  document$.subscribe(refreshAll);
}

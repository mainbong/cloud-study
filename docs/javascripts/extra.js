// 커스텀 JavaScript

// 페이지 로드 완료 후 실행
document.addEventListener('DOMContentLoaded', function() {
  console.log('클라우드 엔지니어 학습 가이드 로드 완료');

  // 외부 링크에 아이콘 추가
  const links = document.querySelectorAll('.md-content a[href^="http"]');
  links.forEach(link => {
    if (!link.hostname.includes(window.location.hostname)) {
      link.setAttribute('target', '_blank');
      link.setAttribute('rel', 'noopener noreferrer');
    }
  });

  // 코드 블록 언어 표시 개선
  const codeBlocks = document.querySelectorAll('.highlight');
  codeBlocks.forEach(block => {
    const lang = block.className.match(/language-(\w+)/);
    if (lang && lang[1]) {
      const label = document.createElement('div');
      label.className = 'code-language-label';
      label.textContent = lang[1].toUpperCase();
      label.style.cssText = `
        position: absolute;
        top: 0.5rem;
        right: 0.5rem;
        font-size: 0.7rem;
        color: var(--md-default-fg-color--light);
        text-transform: uppercase;
        letter-spacing: 0.05em;
      `;
      block.style.position = 'relative';
      block.insertBefore(label, block.firstChild);
    }
  });

  // 체크리스트 진행률 표시 (선택사항)
  const checklists = document.querySelectorAll('.task-list');
  checklists.forEach(list => {
    const items = list.querySelectorAll('.task-list-item');
    const checked = list.querySelectorAll('input[type="checkbox"]:checked');
    if (items.length > 0) {
      const progress = Math.round((checked.length / items.length) * 100);
      const progressBar = document.createElement('div');
      progressBar.className = 'checklist-progress';
      progressBar.innerHTML = `
        <div style="margin-bottom: 0.5rem; font-size: 0.8rem; color: var(--md-default-fg-color--light);">
          진행률: ${checked.length}/${items.length} (${progress}%)
        </div>
        <div style="height: 4px; background: var(--md-default-fg-color--lightest); border-radius: 2px; overflow: hidden;">
          <div style="width: ${progress}%; height: 100%; background: var(--md-primary-fg-color); transition: width 0.3s;"></div>
        </div>
      `;
      list.parentNode.insertBefore(progressBar, list);
    }
  });

  // 테이블에 스크롤 힌트 추가
  const tables = document.querySelectorAll('table');
  tables.forEach(table => {
    const wrapper = table.parentElement;
    if (wrapper && table.offsetWidth > wrapper.offsetWidth) {
      wrapper.style.position = 'relative';
      const hint = document.createElement('div');
      hint.textContent = '← 좌우로 스크롤 →';
      hint.style.cssText = `
        text-align: center;
        font-size: 0.7rem;
        color: var(--md-default-fg-color--lighter);
        padding: 0.25rem;
        margin-top: 0.25rem;
      `;
      wrapper.appendChild(hint);
    }
  });

  // 이미지 확대 기능 (라이트박스)
  const images = document.querySelectorAll('.md-content img');
  images.forEach(img => {
    img.style.cursor = 'pointer';
    img.addEventListener('click', function() {
      const overlay = document.createElement('div');
      overlay.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0, 0, 0, 0.9);
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 9999;
        cursor: zoom-out;
      `;

      const enlargedImg = document.createElement('img');
      enlargedImg.src = this.src;
      enlargedImg.style.cssText = `
        max-width: 90%;
        max-height: 90%;
        object-fit: contain;
      `;

      overlay.appendChild(enlargedImg);
      overlay.addEventListener('click', () => overlay.remove());
      document.body.appendChild(overlay);
    });
  });
});

// 스크롤 진행률 표시 (선택사항)
window.addEventListener('scroll', function() {
  const winScroll = document.body.scrollTop || document.documentElement.scrollTop;
  const height = document.documentElement.scrollHeight - document.documentElement.clientHeight;
  const scrolled = (winScroll / height) * 100;

  let progressBar = document.getElementById('reading-progress');
  if (!progressBar) {
    progressBar = document.createElement('div');
    progressBar.id = 'reading-progress';
    progressBar.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: ${scrolled}%;
      height: 3px;
      background: var(--md-primary-fg-color);
      z-index: 9999;
      transition: width 0.1s;
    `;
    document.body.appendChild(progressBar);
  } else {
    progressBar.style.width = scrolled + '%';
  }
});

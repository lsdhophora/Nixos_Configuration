// ==UserScript==
// @name         Pixiv Novel Copy
// @name:zh-CN   Pixiv 小说复制
// @namespace    http://tampermonkey.net/
// @version      0.5
// @description  Copy novel content to clipboard on Pixiv novel pages
// @description:zh-CN 在 Pixiv 小说页面点击图标复制全文到剪贴板
// @author       you
// @license      GPL-3.0
// @match        https://www.pixiv.net/*
// @icon         data:image/png;base64,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
// @grant        none
// @run-at       document-end
// ==/UserScript==

(function () {
  'use strict';

  const i18n = {
    copy: '复制全文',
    copied: '已复制！',
    failed: '复制失败',
    fetching: '获取中...',
  };

  let currentBtn = null;
  let currentNovelId = null;

  function isNovelPage() {
    return /\/novel\/show\.php\?id=(\d+)/.test(window.location.href);
  }

  function getNovelId() {
    const exec = /\/novel\/show\.php\?id=(\d+)/.exec(window.location.href);
    return exec ? exec[1] : null;
  }

  function removeBtn() {
    if (currentBtn) {
      currentBtn.remove();
      currentBtn = null;
      currentNovelId = null;
    }
  }

  function createBtn() {
    const novelId = getNovelId();
    if (!novelId || currentNovelId === novelId) return;
    removeBtn();
    currentNovelId = novelId;

    const btn = document.createElement('button');
    btn.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
        <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
      </svg>
    `;
    btn.title = i18n.copy;
    Object.assign(btn.style, {
      position: 'fixed',
      left: '20px',
      bottom: '20px',
      zIndex: '999999',
      width: '48px',
      height: '48px',
      borderRadius: '50%',
      border: 'none',
      background: '#0096fa',
      color: '#fff',
      cursor: 'pointer',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      boxShadow: '0 2px 8px rgba(0,0,0,0.3)',
      transition: 'transform 0.2s, background 0.2s',
    });
    document.body.appendChild(btn);
    currentBtn = btn;

    btn.addEventListener('mouseenter', () => {
      btn.style.transform = 'scale(1.1)';
      btn.style.background = '#007acc';
    });
    btn.addEventListener('mouseleave', () => {
      btn.style.transform = 'scale(1)';
      btn.style.background = '#0096fa';
    });

    async function copyNovel() {
      const originalHTML = btn.innerHTML;
      btn.innerHTML = '<span style="font-size:12px;">...</span>';
      btn.disabled = true;

      try {
        const res = await fetch(`/ajax/novel/${novelId}`, { credentials: 'include' });
        const json = await res.json();
        if (json.error) throw new Error(json.message);
        const body = json.body;

        const lines = [];
        lines.push(`标题：${body.title}`);
        lines.push(`作者：${body.userName}`);
        lines.push(`作品ID：${body.id}`);
        lines.push(`字数：${body.content.length}`);
        lines.push(`标签：${body.tags.tags.map(t => t.tag).join(' ')}`);
        lines.push('');
        lines.push('');

        let pageCount = 1;
        const content = body.content
          .replace(/\\n/g, '\n')
          .replace(/\[jump:(\d+)\]/g, (_, n) => `[第${n}页]`)
          .replace(/\[newpage\]/g, () => `\n\n[第${++pageCount}页]\n\n`);

        lines.push(content);
        const text = lines.join('\n');

        await navigator.clipboard.writeText(text);

        btn.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>';
        btn.style.background = '#28a745';
        setTimeout(() => {
          btn.innerHTML = originalHTML;
          btn.style.background = '#0096fa';
          btn.disabled = false;
        }, 1500);

      } catch (err) {
        console.error(err);
        alert(i18n.failed + ': ' + err.message);
        btn.innerHTML = originalHTML;
        btn.disabled = false;
      }
    }

    btn.addEventListener('click', copyNovel);
  }

  function check() {
    if (isNovelPage()) {
      createBtn();
    } else {
      removeBtn();
    }
  }

  check();

  let lastUrl = location.href;
  new MutationObserver(() => {
    const url = location.href;
    if (url !== lastUrl) {
      lastUrl = url;
      check();
    }
  }).observe(document, { subtree: true, childList: true });
})();

// ==UserScript==
// @name         Bilibili Comment Section Avatar Border
// @match        https://www.bilibili.com/*
// @grant        none
// @run-at       document-start
// ==/UserScript==
(function() {
    'use strict';

    const CSS = `
        /* 正方形 a#user-avatar 保持原样 */
        a#user-avatar {
            display: inline-block !important;
            box-shadow: 0 0 0 2px #00a1d6, inset 0 0 0 1.25px #00a1d6 !important;
            border-radius: 50% !important;
            line-height: 0 !important;
        }
        a#user-avatar bili-avatar {
            display: block !important;
        }
        a#user-avatar img:not([data-avatar-bordered]),
        bili-avatar:not([data-avatar-bordered]) {
            display: inline-block !important;
            box-shadow: 0 0 0 2px #00a1d6, inset 0 0 0 1.25px #00a1d6 !important;
            border-radius: 50% !important;
            box-sizing: border-box !important;
        }
        bili-comment-renderer a#user-avatar img:not([data-avatar-bordered]),
        bili-comment-renderer bili-avatar:not([data-avatar-bordered]) {
            box-shadow: 1px -1px 0 2px #00a1d6, inset 0 0 0 1.25px #00a1d6 !important;
            border-radius: 50% !important;
            box-sizing: border-box !important;
        }
    `;

    // 不等宽高时的 overlay 样式
    const OVERLAY_CSS = `
        .avatar-border-overlay {
            position: absolute !important;
            top: 0 !important;
            left: 0 !important;
            width: 50px !important;
            height: 48px !important;
            box-shadow: inset 0 0 0 2px #00a1d6 !important;
            border-radius: 50% !important;
            pointer-events: none !important;
            z-index: 9999 !important;
            box-sizing: border-box !important;
        }
    `;

    // 给不等宽高的 div#user-avatar 去阴影的样式
    const NO_SHADOW_CSS = `
        div#user-avatar[data-avatar-no-shadow] {
            box-shadow: none !important;
        }
    `;

    const injected = new WeakSet();

    function injectToShadow(root) {
        if (!root || injected.has(root)) return;
        injected.add(root);
        const style = document.createElement('style');
        style.setAttribute('data-avatar-border', '1');
        style.textContent = CSS;
        root.appendChild(style);
        root.querySelectorAll('a#user-avatar img, div#user-avatar img, bili-avatar').forEach(el => {
            el.setAttribute('data-avatar-bordered', '1');
        });
        root.querySelectorAll('*').forEach(el => {
            if (el.shadowRoot) {
                injectToShadow(el.shadowRoot);
            }
        });
    }

    // ========== 核心：处理 div#user-avatar，宽高不等时去阴影 + 注入 overlay ==========
    function handleUserAvatar(userAvatar) {
        if (!userAvatar) return;
        const rect = userAvatar.getBoundingClientRect();
        const w = Math.round(rect.width);
        const h = Math.round(rect.height);

        // 宽高相等，不需要 overlay（原 CSS 处理）
        if (w === h) return;

        // 宽高不等：给 div#user-avatar 标记去阴影
        userAvatar.setAttribute('data-avatar-no-shadow', '1');

        // 给内部所有 bili-avatar 注入 overlay
        userAvatar.querySelectorAll('bili-avatar').forEach(avatar => {
            if (!avatar.shadowRoot) return;
            if (avatar.shadowRoot.querySelector('.avatar-border-overlay')) return;

            const style = document.createElement('style');
            style.textContent = OVERLAY_CSS;
            avatar.shadowRoot.appendChild(style);

            const overlay = document.createElement('div');
            overlay.className = 'avatar-border-overlay';
            overlay.setAttribute('data-avatar-border', '1');
            avatar.shadowRoot.appendChild(overlay);
        });
    }

    function scanAllUserAvatars(node) {
        if (!node) return;
        if (node.querySelectorAll) {
            node.querySelectorAll('div#user-avatar, a#user-avatar').forEach(handleUserAvatar);
        }
        if (node.shadowRoot) {
            node.shadowRoot.querySelectorAll('div#user-avatar, a#user-avatar').forEach(handleUserAvatar);
        }
        if (node.querySelectorAll) {
            node.querySelectorAll('*').forEach(el => {
                if (el.shadowRoot) {
                    scanAllUserAvatars(el.shadowRoot);
                }
            });
        }
    }
    // =================================================================

    function walkAllShadows(node = document.body) {
        if (node.shadowRoot) {
            injectToShadow(node.shadowRoot);
        }
        node.querySelectorAll('*').forEach(el => {
            if (el.shadowRoot) {
                injectToShadow(el.shadowRoot);
            }
        });
    }

    const orig = Element.prototype.attachShadow;
    Element.prototype.attachShadow = function(init) {
        const root = orig.call(this, init);
        setTimeout(() => {
            injectToShadow(root);
            walkAllShadows(this);
            if (this.shadowRoot) {
                this.shadowRoot.querySelectorAll('div#user-avatar, a#user-avatar').forEach(handleUserAvatar);
            }
        }, 300);
        return root;
    };

    const observer = new MutationObserver((mutations) => {
        mutations.forEach(m => {
            m.addedNodes.forEach(node => {
                if (node.nodeType !== 1) return;
                if (node.matches?.('a#user-avatar img, div#user-avatar img, bili-avatar')) {
                    node.setAttribute('data-avatar-bordered', '1');
                }
                node.querySelectorAll?.('a#user-avatar img, div#user-avatar img, bili-avatar').forEach(img => {
                    img.setAttribute('data-avatar-bordered', '1');
                });
                walkAllShadows(node);
                if (node.shadowRoot) {
                    injectToShadow(node.shadowRoot);
                }
                scanAllUserAvatars(node);
            });
        });
    });

    function init() {
        const mainStyle = document.createElement('style');
        // 合并 CSS + NO_SHADOW_CSS
        mainStyle.textContent = CSS + NO_SHADOW_CSS;
        document.head.appendChild(mainStyle);
        observer.observe(document.body, { childList: true, subtree: true });
        walkAllShadows(document.body);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

    setInterval(() => {
        scanAllUserAvatars(document.body);
    }, 500);
})();

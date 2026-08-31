// ==UserScript==
// @name         Reddit Search Gradient Border Fix
// @namespace    http://tampermonkey.net/
// @version      2.0
// @description  Fix reddit-search-large gradient border z-index
// @author       You
// @match        https://www.reddit.com/*
// @match        https://old.reddit.com/*
// @grant        GM_addStyle
// @run-at       document-start
// ==/UserScript==

(function() {
    'use strict';

    const css = `
reddit-header-large reddit-search-large[show-ask-button]:defined {
    position: relative !important;
}

reddit-header-large reddit-search-large[show-ask-button]:defined:not(:focus-within)::before {
    position: absolute !important;
    inset: -1px !important;
    border: 1px solid transparent !important;
    border-radius: var(--radius-full) !important;
    background: linear-gradient(var(--color-neutral-background), var(--color-neutral-background)) padding-box,
                linear-gradient(90deg, var(--color-global-brand-orangered), var(--color-input-search-yellow-gradient)) border-box !important;
    content: "" !important;
    z-index: 0 !important;
}

reddit-header-large reddit-search-large[show-ask-button]:defined:not(:focus-within)::after {
    position: absolute !important;
    inset: -1px !important;
    border: 1px solid transparent !important;
    border-radius: var(--radius-full) !important;
    background: linear-gradient(var(--color-neutral-background), var(--color-neutral-background)) padding-box,
                linear-gradient(90deg, var(--color-global-brand-orangered), var(--color-input-search-yellow-gradient)) border-box !important;
    content: "" !important;
    z-index: -1 !important;
    filter: blur(4px) !important;
    opacity: .75 !important;
}

reddit-header-large reddit-search-large[show-ask-button]:defined:focus-within::before {
    position: absolute !important;
    inset: -3px !important;
    border: 2.5px solid transparent !important;
    border-radius: var(--radius-full) !important;
    background: linear-gradient(var(--color-neutral-background), var(--color-neutral-background)) padding-box,
                linear-gradient(90deg, var(--color-global-brand-orangered), var(--color-input-search-yellow-gradient)) border-box !important;
    content: "" !important;
    z-index: 2 !important;
}

reddit-header-large reddit-search-large[show-ask-button]:defined:focus-within::after {
    display: none !important;
}

reddit-header-large reddit-search-large[show-ask-button]:defined:not(:focus-within)::before,
reddit-header-large reddit-search-large[show-ask-button]:defined:not(:focus-within)::after {
    border-width: 2.5px !important;
    inset: -3px !important;
}

html body reddit-header-large reddit-search-large[show-ask-button]:defined:focus-within [slot="leadingIcon"],
html body reddit-header-large reddit-search-large[show-ask-button]:defined:focus-within [slot="leadingIcon"] > *,
html body reddit-header-large reddit-search-large[show-ask-button]:defined:focus-within [slot="leadingIcon"] svg,
html body reddit-header-large reddit-search-large[show-ask-button]:defined:focus-within [slot="trailingIcon"],
html body reddit-header-large reddit-search-large[show-ask-button]:defined:focus-within [slot="trailingIcon"] > *,
html body reddit-header-large reddit-search-large[show-ask-button]:defined:focus-within [slot="trailingIcon"] svg,
html body reddit-header-large reddit-search-large[show-ask-button]:defined:focus-within [slot="chips"],
html body reddit-header-large reddit-search-large[show-ask-button]:defined:focus-within [slot="chips"] > * {
    position: relative !important;
    z-index: 9999 !important;
}
    `;

    if (typeof GM_addStyle !== 'undefined') {
        GM_addStyle(css);
    } else {
        const style = document.createElement('style');
        style.textContent = css;
        document.head.appendChild(style);
    }

    function walkShadowTree(root, callback) {
        callback(root);
        if (root.querySelectorAll) {
            root.querySelectorAll('*').forEach(el => {
                if (el.shadowRoot) {
                    walkShadowTree(el.shadowRoot, callback);
                }
            });
        }
    }

    const SHADOW_SELECTORS = [
        '.leadingIcon',
        '.leadingIcon *',
        'span.input-container.activated',
        'span.input-container.activated *',
        '#search-input-remove-filter',
        '#search-input-remove-filter *',
        '.text-neutral-content',
        '.text-neutral-content *',
        '.clear-icon-container',
        '.clear-icon-container *',
        '.trailing-divider',
        '.trailing-divider *'
    ].join(', ');

    function applyZIndex(root) {
        root.querySelectorAll(SHADOW_SELECTORS).forEach(node => {
            if (node.nodeType !== Node.ELEMENT_NODE) return;
            node.style.setProperty('position', 'relative', 'important');
            node.style.setProperty('z-index', '9999', 'important');
        });
    }

    function removeZIndex(root) {
        root.querySelectorAll(SHADOW_SELECTORS).forEach(node => {
            node.style.removeProperty('position');
            node.style.removeProperty('z-index');
        });
    }

    function fixZIndex(element) {
        const shadow = element.shadowRoot;
        if (!shadow) return;
        walkShadowTree(shadow, applyZIndex);

        element.querySelectorAll(':scope > [slot]').forEach(node => {
            node.style.setProperty('position', 'relative', 'important');
            node.style.setProperty('z-index', '9999', 'important');
            node.querySelectorAll('*').forEach(child => {
                child.style.setProperty('position', 'relative', 'important');
                child.style.setProperty('z-index', '9999', 'important');
            });
        });

        ['leadingIcon', 'trailingIcon', 'chips'].forEach(slotName => {
            document.querySelectorAll(`[slot="${slotName}"]`).forEach(node => {
                if (element.contains(node) || node.closest('reddit-search-large') === element) {
                    node.style.setProperty('position', 'relative', 'important');
                    node.style.setProperty('z-index', '9999', 'important');
                    node.querySelectorAll('*').forEach(child => {
                        child.style.setProperty('position', 'relative', 'important');
                        child.style.setProperty('z-index', '9999', 'important');
                    });
                }
            });
        });
    }

    function resetZIndex(element) {
        const shadow = element.shadowRoot;
        if (!shadow) return;
        walkShadowTree(shadow, removeZIndex);

        element.querySelectorAll(':scope > [slot], :scope > [slot] *').forEach(node => {
            node.style.removeProperty('position');
            node.style.removeProperty('z-index');
        });
    }

    function init() {
        document.querySelectorAll('reddit-search-large').forEach(el => setupElement(el));

        const observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
                mutation.addedNodes.forEach((node) => {
                    if (node.nodeType === Node.ELEMENT_NODE) {
                        if (node.matches && node.matches('reddit-search-large')) {
                            setupElement(node);
                        }
                        if (node.querySelectorAll) {
                            node.querySelectorAll('reddit-search-large').forEach(el => setupElement(el));
                        }
                    }
                });
            });
        });

        observer.observe(document.body, { childList: true, subtree: true });
    }

    function setupElement(element) {
        const checkShadow = () => {
            if (element.shadowRoot) {
                attachListeners(element);
                return true;
            }
            return false;
        };

        if (!checkShadow()) {
            const interval = setInterval(() => {
                if (checkShadow()) clearInterval(interval);
            }, 100);
            setTimeout(() => clearInterval(interval), 5000);
        }
    }

    function attachListeners(element) {
        element.removeEventListener('focusin', onFocusIn);
        element.removeEventListener('focusout', onFocusOut);
        element.addEventListener('focusin', onFocusIn);
        element.addEventListener('focusout', onFocusOut);
    }

    function onFocusIn(e) {
        fixZIndex(e.currentTarget);
    }

    function onFocusOut(e) {
        setTimeout(() => {
            if (!e.currentTarget.matches(':focus-within')) {
                resetZIndex(e.currentTarget);
            }
        }, 100);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }

})();

// ==UserScript==
// @name         Font Weight Minimum 500
// @namespace    font-weight-min-500
// @version      1.0
// @description  Traverse all elements, calculate the actually rendered font-weight, force anything below 500 up to 500; headings/bold elements minimum 700
// @match        *://*/*
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    const MIN_WEIGHT = 500;
    const BOLD_WEIGHT = 700;
    const BOLD_TAGS = 'h1,h2,h3,h4,h5,h6,strong,b,th,thead td';

    // Use WeakSet to track already-processed elements, preventing duplicate work and memory leaks
    const processed = new WeakSet();

    // Get the element's real numeric font weight (getComputedStyle returns computed absolute values like "400")
    function getRealWeight(el) {
        try {
            const w = window.getComputedStyle(el).fontWeight;
            const n = parseInt(w, 10);
            return isNaN(n) ? (w === 'bold' ? 700 : 400) : n;
        } catch (e) {
            return 400;
        }
    }

    // Process a single element: compute first, then decide whether to override
    function fixElement(el) {
        if (!el || processed.has(el)) return;
        processed.add(el);

        const realWeight = getRealWeight(el);
        const needBold = el.matches && el.matches(BOLD_TAGS);

        if (needBold) {
            // Heading/bold tags: if actual rendering is below 700, force it to 700
            if (realWeight < BOLD_WEIGHT) {
                el.style.setProperty('font-weight', BOLD_WEIGHT, 'important');
            }
        } else {
            // Normal elements: if actual rendering is below 500, force it to 500
            if (realWeight < MIN_WEIGHT) {
                el.style.setProperty('font-weight', MIN_WEIGHT, 'important');
            }
        }
    }

    // Batch processing to avoid stuttering on large pages from one-shot traversal
    function processBatch(nodeList, start, batchSize) {
        const end = Math.min(start + batchSize, nodeList.length);
        for (let i = start; i < end; i++) {
            fixElement(nodeList[i]);
        }

        if (end < nodeList.length) {
            // Continue next batch when browser is idle
            if (typeof requestIdleCallback === 'function') {
                requestIdleCallback(() => processBatch(nodeList, end, batchSize), { timeout: 200 });
            } else {
                setTimeout(() => processBatch(nodeList, end, batchSize), 0);
            }
        }
    }

    function run() {
        processBatch(document.querySelectorAll('*'), 0, 150);
    }

    // Watch for dynamically inserted content later (e.g. lazy loading, SPA route changes)
    const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
            mutation.addedNodes.forEach((node) => {
                if (node.nodeType === 1) { // Only process element nodes
                    fixElement(node);
                    if (node.querySelectorAll) {
                        node.querySelectorAll('*').forEach(fixElement);
                    }
                }
            });
        });
    });

    // Startup timing
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => {
            run();
            if (document.body) observer.observe(document.body, { childList: true, subtree: true });
        });
    } else {
        run();
        if (document.body) {
            observer.observe(document.body, { childList: true, subtree: true });
        } else {
            // Edge case where body hasn't been created yet
            const htmlObs = new MutationObserver(() => {
                if (document.body) {
                    htmlObs.disconnect();
                    observer.observe(document.body, { childList: true, subtree: true });
                }
            });
            htmlObs.observe(document.documentElement, { childList: true });
        }
    }
})();

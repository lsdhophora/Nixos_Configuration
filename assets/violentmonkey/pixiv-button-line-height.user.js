// ==UserScript==
// @name         Pixiv Icon Button Line Height
// @namespace    pixiv-button-line-height
// @version      1.0
// @description  Set line-height 1.5 on the Pixiv bookmark icon button
// @match        https://www.pixiv.net/*
// @grant        none
// @run-at       document-start
// ==/UserScript==

(function() {
    'use strict';

    // The generated class names change when Pixiv ships a new build.
    // The bookmark SVG shape stays stable, so match it as a fallback.
    const CSS = `
        button.sc-ac478b8a-4.wzfVV,
        button:has(> svg[viewBox="0 0 10 13"]) {
            line-height: 1.5 !important;
        }
    `;

    // Append the style before the page builds. documentElement exists at
    // document-start, so the style applies from the first paint.
    const style = document.createElement('style');
    style.textContent = CSS;
    document.documentElement.appendChild(style);
})();
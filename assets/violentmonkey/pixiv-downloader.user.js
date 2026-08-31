// ==UserScript==
// @name         Pixiv Downloader
// @namespace    http://tampermonkey.net/
// @version      3.5.1
// @description  Download Pixiv illustrations and manga (SPA-compatible)
// @author       you
// @license      GPL-3.0-only
// @match        https://www.pixiv.net/*
// @grant        GM_xmlhttpRequest
// @grant        GM_download
// @grant        GM_addStyle
// @grant        GM_registerMenuCommand
// @grant        GM_notification
// @connect      pixiv.net
// @connect      pximg.net
// @connect      i.pximg.net
// @run-at       document-end
// @noframes
// ==/UserScript==

(function () {
    'use strict';

    const HAS_DIR_PICKER = typeof window.showDirectoryPicker === 'function';

    const CONFIG = {
        RETRY: 4,
        RETRY_DELAY: 1200,
        TIMEOUT: 90000,
        NOTIFY_TIME: 3500,
        CACHE_TIME: 12 * 60 * 60 * 1000,
    };

    const cache = new Map();
    let rootHandle = null;
    let initialized = false;
    let lastPath = location.pathname;

    const utils = {
        sleep: (ms) => new Promise((r) => setTimeout(r, ms)),

        async retry(fn, times = CONFIG.RETRY) {
            let lastErr;
            for (let i = 0; i < times; i++) {
                try {
                    return await fn();
                } catch (e) {
                    lastErr = e;
                    if (e?.retryable === false) throw e;
                    if (i < times - 1) await utils.sleep(CONFIG.RETRY_DELAY * (i + 1));
                }
            }
            throw lastErr;
        },

        fetch(url, options = {}) {
            if (!options.noCache) {
                const cached = cache.get(url);
                if (cached && Date.now() - cached.time < CONFIG.CACHE_TIME) {
                    return Promise.resolve(cached.data);
                }
            }
            return new Promise((resolve, reject) => {
                GM_xmlhttpRequest({
                    method: options.method || 'GET',
                    url,
                    responseType: options.responseType || 'json',
                    headers: {
                        Referer: 'https://www.pixiv.net/',
                        'User-Agent': navigator.userAgent,
                        Accept: options.responseType === 'blob' ? '*/*' : 'application/json',
                    },
                    timeout: CONFIG.TIMEOUT,
                    onload: (res) => {
                        if (res.status >= 200 && res.status < 300) {
                            let data;
                            if (options.responseType === 'blob') {
                                data = res.response;
                            } else {
                                try { data = JSON.parse(res.responseText); }
                                catch { data = res.responseText; }
                            }
                            if (!options.noCache) cache.set(url, { data, time: Date.now() });
                            resolve(data);
                        } else {
                            const err = new Error(`HTTP ${res.status}`);
                            err.retryable = res.status >= 500;
                            reject(err);
                        }
                    },
                    onerror: () => reject(new Error('Network error')),
                    ontimeout: () => reject(new Error('Timeout')),
                });
            });
        },

        extractId(str) {
            if (!str) return null;
            const m = str.trim().match(/(?:artworks\/|^)(\d+)/);
            return m ? m[1] : null;
        },

        sanitize(name) {
            return String(name)
                .replace(/[\\/:*?"<>|]/g, '_')
                .replace(/\s+/g, ' ')
                .replace(/[. ]+$/g, '')
                .trim()
                .slice(0, 100);
        },

        basename(url) {
            try {
                return decodeURIComponent(new URL(url).pathname.split('/').pop() || 'file');
            } catch { return 'file'; }
        },

        notify(text) {
            GM_notification({ text, title: 'Pixiv Downloader', timeout: CONFIG.NOTIFY_TIME });
        },
    };

    function idbOpen() {
        return new Promise((resolve, reject) => {
            const req = indexedDB.open('pixiv-downloader', 1);
            req.onupgradeneeded = () => req.result.createObjectStore('handles');
            req.onsuccess = () => resolve(req.result);
            req.onerror = () => reject(req.error);
        });
    }

    async function idbGet(key) {
        try {
            const db = await idbOpen();
            return await new Promise((resolve, reject) => {
                const req = db.transaction('handles', 'readonly').objectStore('handles').get(key);
                req.onsuccess = () => resolve(req.result || null);
                req.onerror = () => reject(req.error);
            });
        } catch { return null; }
    }

    async function idbSet(key, val) {
        try {
            const db = await idbOpen();
            await new Promise((resolve, reject) => {
                const req = db.transaction('handles', 'readwrite').objectStore('handles').put(val, key);
                req.onsuccess = () => resolve();
                req.onerror = () => reject(req.error);
            });
        } catch { /* non-fatal */ }
    }

    async function idbDel(key) {
        try {
            const db = await idbOpen();
            await new Promise((resolve, reject) => {
                const tx = db.transaction('handles', 'readwrite');
                tx.objectStore('handles').delete(key);
                tx.oncomplete = () => resolve();
                tx.onerror = () => reject(tx.error);
            });
        } catch { /* non-fatal */ }
    }

    const fs = {
        async getRoot() {
            if (rootHandle) return rootHandle;

            const saved = await idbGet('root');
            if (saved) {
                try {
                    const perm = await saved.queryPermission({ mode: 'readwrite' });
                    if (perm === 'granted') { rootHandle = saved; return rootHandle; }
                    if (perm === 'prompt') {
                        const p = await saved.requestPermission({ mode: 'readwrite' });
                        if (p === 'granted') { rootHandle = saved; return rootHandle; }
                    }
                } catch { /* stale handle */ }
            }

            try {
                const handle = await window.showDirectoryPicker({ mode: 'readwrite', startIn: 'downloads' });
                rootHandle = handle;
                idbSet('root', handle);
                return handle;
            } catch (e) {
                if (e.name === 'AbortError') throw e;
                if (e.name === 'SecurityError' || e.name === 'NotAllowedError') {
                    throw new Error('请先在页面任意位置点击一次，再从菜单下载');
                }
                throw e;
            }
        },

        async getDir(parent, name, create = true) {
            return parent.getDirectoryHandle(name, { create });
        },

        async writeFile(dirHandle, filename, blob) {
            const fileHandle = await dirHandle.getFileHandle(filename, { create: true });
            const writable = await fileHandle.createWritable();
            await writable.write(blob);
            await writable.close();
        },
    };

    const dl = {
        gm(url, name, headers) {
            return new Promise((resolve) => {
                let done = false;
                const finish = (err) => { if (!done) { done = true; resolve(err || null); } };
                try {
                    GM_download({
                        url,
                        name,
                        saveAs: false,
                        headers,
                        onload: () => finish(null),
                        onerror: (r) => finish(new Error(`GM_download failed${r?.status ? ' HTTP ' + r.status : ''}`)),
                        ontimeout: () => finish(new Error('GM_download timeout')),
                        onabort: () => finish(new Error('GM_download aborted')),
                    });
                } catch (e) { finish(e); }
                setTimeout(() => finish(new Error('GM_download timeout')), CONFIG.TIMEOUT);
            });
        },

        async download(url, name) {
            const err = await this.gm(url, name, { Referer: 'https://www.pixiv.net/' });
            if (!err) return;

            const blob = await utils.retry(() => utils.fetch(url, { responseType: 'blob', noCache: true }));
            const objUrl = URL.createObjectURL(blob);
            try {
                const err2 = await this.gm(objUrl, name);
                if (err2) throw err2;
            } finally {
                setTimeout(() => URL.revokeObjectURL(objUrl), 60000);
            }
        },
    };

    const ui = {
        container: null,
        statusEl: null,
        progressEl: null,
        barEl: null,

        init() {
            GM_addStyle(`
                .pd-box {
                    position: fixed;
                    bottom: 24px;
                    right: 24px;
                    z-index: 99999;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
                    font-size: 14px;
                }
                .pd-status, .pd-progress {
                    background: rgba(255, 255, 255, 0.95);
                    color: #1f2937;
                    padding: 12px 16px;
                    border-radius: 10px;
                    margin-top: 10px;
                    border: 1px solid #e5e7eb;
                    box-shadow: 0 4px 20px rgba(0,0,0,0.15);
                    display: none;
                    min-width: 280px;
                }
                .pd-progress {
                    padding: 6px;
                    height: 28px;
                    background: #e5e7eb;
                }
                .pd-progress-bar {
                    height: 100%;
                    background: linear-gradient(90deg, #0096fa, #00c4b4);
                    border-radius: 6px;
                    transition: width 0.3s ease;
                    width: 0%;
                }
                .pd-dialog {
                    position: fixed;
                    top: 50%;
                    left: 50%;
                    transform: translate(-50%, -50%);
                    background: #ffffff;
                    color: #1f2937;
                    padding: 24px;
                    border-radius: 14px;
                    border: 1px solid #e5e7eb;
                    box-shadow: 0 8px 32px rgba(0,0,0,0.2);
                    z-index: 100000;
                    width: 520px;
                    max-width: 92vw;
                }
                .pd-dialog h3 { margin: 0 0 16px; font-size: 18px; }
                .pd-dialog textarea {
                    width: 100%; height: 220px; background: #ffffff;
                    border: 1px solid #d1d5db; border-radius: 8px; color: #1f2937;
                    padding: 10px; font-size: 13px; resize: vertical; box-sizing: border-box;
                }
                .pd-dialog .btn-row { margin-top: 16px; display: flex; gap: 10px; }
                .pd-dialog button {
                    padding: 8px 18px; border: none; border-radius: 6px;
                    cursor: pointer; font-size: 14px;
                }
                .pd-dialog .btn-primary { background: #0096fa; color: #fff; }
                .pd-dialog .btn-primary:hover { background: #0077cc; }
                .pd-dialog .btn-secondary { background: #f3f4f6; color: #374151; border: 1px solid #d1d5db; }
            `);

            this.container = document.createElement('div');
            this.container.className = 'pd-box';
            document.body.appendChild(this.container);

            this.statusEl = document.createElement('div');
            this.statusEl.className = 'pd-status';
            this.container.appendChild(this.statusEl);

            this.progressEl = document.createElement('div');
            this.progressEl.className = 'pd-progress';
            this.barEl = document.createElement('div');
            this.barEl.className = 'pd-progress-bar';
            this.progressEl.appendChild(this.barEl);
            this.container.appendChild(this.progressEl);
        },

        status(msg) {
            this.statusEl.textContent = msg;
            this.statusEl.style.display = 'block';
        },

        progress(percent) {
            this.progressEl.style.display = 'block';
            this.barEl.style.width = Math.min(100, Math.max(0, percent)) + '%';
        },

        hide() {
            this.statusEl.style.display = 'none';
            this.progressEl.style.display = 'none';
            this.barEl.style.width = '0%';
        },

        showBatchDialog() {
            const dialog = document.createElement('div');
            dialog.className = 'pd-dialog';
            dialog.innerHTML = `
                <h3>Batch Download</h3>
                <p style="margin:0 0 10px;color:#6b7280;font-size:13px;">Enter one artwork ID or URL per line</p>
                <textarea placeholder="Example:&#10;146772312&#10;https://www.pixiv.net/artworks/12345678"></textarea>
                <div class="btn-row">
                    <button class="btn-primary download">Start</button>
                    <button class="btn-secondary cancel">Cancel</button>
                </div>
            `;
            document.body.appendChild(dialog);

            dialog.querySelector('.download').onclick = async () => {
                const text = dialog.querySelector('textarea').value;
                const ids = text.split('\n').map((l) => utils.extractId(l)).filter(Boolean);
                if (ids.length === 0) {
                    utils.notify('No valid ID found');
                    return;
                }
                dialog.remove();
                await app.batchDownload(ids);
            };
            dialog.querySelector('.cancel').onclick = () => dialog.remove();
        },
    };

    const app = {
        async getIllust(id) {
            const data = await utils.retry(() => utils.fetch(`https://www.pixiv.net/ajax/illust/${id}`));
            if (data.error || !data.body) throw new Error(data.message || 'Failed to get artwork info');
            return data.body;
        },

        async downloadIllust(illust) {
            const total = illust.pageCount || 1;
            const titleName = utils.sanitize(illust.title || 'untitled').slice(0, 60);
            // 每个作品一个文件夹，以作品标题命名（附 id 防重名）
            const targetName = `${titleName} (${illust.id})`;
            const baseUrl = illust.urls?.original;
            if (!baseUrl) throw new Error('No original image URL in artwork data');

            ui.status(`Preparing: ${illust.title} (${total} pages)`);
            ui.progress(0);

            let targetDir = null;
            if (HAS_DIR_PICKER) {
                const root = await fs.getRoot();
                let dir = root;
                for (const part of targetName.split('/')) {
                    dir = await fs.getDir(dir, part);
                }
                targetDir = dir;
            }

            const hasP0 = baseUrl.includes('_p0');
            const ext = (baseUrl.match(/\.([a-zA-Z0-9]+)(?:[?#]|$)/) || [])[1] || 'jpg';
            let done = 0;

            for (let i = 0; i < total; i++) {
                const url = hasP0 ? baseUrl.replace('_p0', `_p${i}`) : baseUrl;
                const filename = hasP0 ? `${String(i).padStart(3, '0')}.${ext}` : utils.basename(url);

                if (targetDir) {
                    const blob = await utils.retry(() => utils.fetch(url, { responseType: 'blob', noCache: true }));
                    await fs.writeFile(targetDir, filename, blob);
                } else {
                    // Firefox：GM_download 的 name 支持子目录，自动创建 作品标题 (id)/ 文件夹
                    await dl.download(url, `${targetName}/${filename}`);
                }

                done++;
                ui.status(`Downloading ${done}/${total}: ${illust.title}`);
                ui.progress((done / total) * 100);
                if (i < total - 1) await utils.sleep(300);
            }

            utils.notify(targetDir ? `Saved to: ${targetName}` : `Saved ${done} file(s) into download folder`);
            ui.hide();
        },

        async downloadCurrent() {
            try {
                const id = location.pathname.match(/artworks\/(\d+)/)?.[1];
                if (!id) {
                    utils.notify('Not an artwork page');
                    return;
                }
                ui.status('Getting artwork info...');
                const illust = await this.getIllust(id);
                await this.downloadIllust(illust);
            } catch (e) {
                if (e.name === 'AbortError') return;
                console.error(e);
                utils.notify('Download failed: ' + e.message);
                ui.hide();
            }
        },

        async batchDownload(ids) {
            let success = 0;
            const failed = [];
            ui.status(`Batch 0/${ids.length}`);
            ui.progress(0);

            if (HAS_DIR_PICKER) {
                try { await fs.getRoot(); }
                catch (e) {
                    if (e.name === 'AbortError') return;
                    utils.notify('Need directory permission');
                    return;
                }
            }

            for (let i = 0; i < ids.length; i++) {
                const id = ids[i];
                try {
                    ui.status(`Batch ${i + 1}/${ids.length} (ID: ${id})`);
                    const illust = await this.getIllust(id);
                    await this.downloadIllust(illust);
                    success++;
                } catch (e) {
                    if (e.name === 'AbortError') { utils.notify('Batch cancelled'); return; }
                    console.error(`ID ${id} failed:`, e);
                    failed.push(id);
                    utils.notify(`Artwork ${id} failed`);
                }
                ui.progress(((i + 1) / ids.length) * 100);
                await utils.sleep(600);
            }

            ui.hide();
            if (failed.length) {
                utils.notify(`Done ${success}, failed ${failed.length}`);
                console.warn('Failed IDs:', failed);
            } else {
                utils.notify(`Batch complete (${success})`);
            }
        },

        init() {
            if (initialized) return;
            initialized = true;

            ui.init();
            GM_registerMenuCommand('Download Current', () => this.downloadCurrent());
            GM_registerMenuCommand('Batch Download', () => ui.showBatchDialog());
            GM_registerMenuCommand('Reset Directory', () => {
                if (!HAS_DIR_PICKER) { utils.notify('Not applicable on this browser'); return; }
                rootHandle = null;
                idbDel('root');
                utils.notify('Directory reset. Next download will ask again.');
            });

            const observer = new MutationObserver(() => {
                if (location.pathname !== lastPath) {
                    lastPath = location.pathname;
                }
            });
            observer.observe(document.documentElement, { subtree: true, childList: true });
            window.addEventListener('popstate', () => { lastPath = location.pathname; });
        },
    };

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', () => app.init());
    } else {
        app.init();
    }
})();

import Foundation

/// JavaScript function bodies executed with `callAsyncJavaScript` in an isolated content world.
/// Every script returns a JSON string.
enum PageScripts {
    /// Extracts readable text from the page for chat context. Args: maxChars
    static let extractContent = #"""
    const root = document.querySelector('article') || document.querySelector('main, [role=main]');
    const pick = (root && root.innerText && root.innerText.length > 400) ? root : document.body;
    const raw = (pick && pick.innerText) || '';
    const text = raw.replace(/[ \t ]+/g, ' ').replace(/\n\s*\n\s*\n+/g, '\n\n').trim().slice(0, maxChars);
    const sel = window.getSelection ? String(window.getSelection()).trim().slice(0, 4000) : '';
    const meta = document.querySelector('meta[name="description"], meta[property="og:description"]');
    return JSON.stringify({
      url: location.href,
      title: document.title || '',
      text: text,
      selection: sel,
      description: meta ? (meta.getAttribute('content') || '') : ''
    });
    """#

    /// Labels visible interactive elements with data-orbit-id and returns a snapshot for the agent.
    static let snapshot = #"""
    const MAX = 250;
    const vh = window.innerHeight;
    const clean = (t, n) => String(t || '').replace(/\s+/g, ' ').trim().slice(0, n);
    const visible = (el) => {
      const r = el.getBoundingClientRect();
      if (r.width < 2 || r.height < 2) return false;
      const s = getComputedStyle(el);
      return s.visibility !== 'hidden' && s.display !== 'none' && parseFloat(s.opacity || '1') > 0.05;
    };
    const labelOf = (el) => {
      const img = el.querySelector && el.querySelector('img[alt]');
      return clean(
        el.getAttribute('aria-label') || el.innerText || el.getAttribute('placeholder') ||
        el.getAttribute('title') || el.getAttribute('alt') || (img && img.getAttribute('alt')) ||
        el.getAttribute('name') || '', 80);
    };
    document.querySelectorAll('[data-orbit-id]').forEach(e => e.removeAttribute('data-orbit-id'));
    const selector = 'a[href], button, input:not([type=hidden]), textarea, select, summary, ' +
      '[role=button], [role=link], [role=tab], [role=menuitem], [role=checkbox], [role=switch], ' +
      '[role=option], [role=combobox], [contenteditable=""], [contenteditable=true], [onclick]';
    const nodes = Array.from(document.querySelectorAll(selector)).filter(visible);
    const elements = [];
    let n = 0;
    for (const el of nodes) {
      if (n >= MAX) break;
      n += 1;
      el.setAttribute('data-orbit-id', String(n));
      const tag = el.tagName.toLowerCase();
      const r = el.getBoundingClientRect();
      const item = { id: n, tag: tag, label: labelOf(el), inView: r.bottom > 0 && r.top < vh };
      const role = el.getAttribute('role');
      if (role) item.role = role;
      if (tag === 'input') {
        item.inputType = (el.type || 'text').toLowerCase();
        item.value = item.inputType === 'password' ? (el.value ? '••••' : '') : clean(el.value, 60);
        if (item.inputType === 'checkbox' || item.inputType === 'radio') item.checked = !!el.checked;
      } else if (tag === 'textarea') {
        item.value = clean(el.value, 60);
      } else if (tag === 'select') {
        const o = el.options[el.selectedIndex];
        item.value = clean(o ? o.text : '', 40);
        item.options = Array.from(el.options).slice(0, 15).map(x => clean(x.text, 30));
      } else if (tag === 'a') {
        item.href = clean(el.getAttribute('href'), 120);
      }
      elements.push(item);
    }
    const root = document.querySelector('main, [role=main], article') || document.body;
    const text = String((root && root.innerText) || '')
      .replace(/[ \t ]+/g, ' ').replace(/\n\s*\n\s*\n+/g, '\n\n').trim().slice(0, 12000);
    return JSON.stringify({
      url: location.href,
      title: document.title || '',
      scrollY: Math.round(window.scrollY),
      scrollHeight: Math.round(document.documentElement.scrollHeight),
      viewportHeight: Math.round(vh),
      elements: elements,
      text: text
    });
    """#

    /// Clicks an element. Args: id
    static let click = #"""
    const el = document.querySelector('[data-orbit-id="' + id + '"]');
    if (!el) return JSON.stringify({ ok: false, error: '要素が見つかりません。read_page で最新の状態を取得してください。' });
    el.scrollIntoView({ block: 'center', inline: 'center' });
    const prevOutline = el.style.outline, prevOffset = el.style.outlineOffset;
    el.style.outline = '3px solid #8B5CF6';
    el.style.outlineOffset = '2px';
    setTimeout(() => { el.style.outline = prevOutline; el.style.outlineOffset = prevOffset; }, 900);
    const r = el.getBoundingClientRect();
    const opts = { bubbles: true, cancelable: true, clientX: r.left + r.width / 2, clientY: r.top + r.height / 2 };
    try {
      el.dispatchEvent(new PointerEvent('pointerdown', opts));
      el.dispatchEvent(new MouseEvent('mousedown', opts));
      el.dispatchEvent(new PointerEvent('pointerup', opts));
      el.dispatchEvent(new MouseEvent('mouseup', opts));
    } catch (e) {}
    if (typeof el.focus === 'function') el.focus();
    el.click();
    return JSON.stringify({ ok: true });
    """#

    /// Types into an input / textarea / contenteditable, or picks a <select> option. Args: id, text, submit
    static let typeText = #"""
    const el = document.querySelector('[data-orbit-id="' + id + '"]');
    if (!el) return JSON.stringify({ ok: false, error: '要素が見つかりません。read_page で最新の状態を取得してください。' });
    el.scrollIntoView({ block: 'center' });
    if (typeof el.focus === 'function') el.focus();
    const tag = el.tagName;
    const fire = (type) => el.dispatchEvent(new Event(type, { bubbles: true }));
    if (tag === 'SELECT') {
      const opts = Array.from(el.options);
      const want = String(text).trim();
      const opt = opts.find(o => o.text.trim() === want || o.value === want) || opts.find(o => o.text.includes(want));
      if (!opt) return JSON.stringify({ ok: false, error: '一致する選択肢がありません: ' + opts.map(o => o.text.trim()).join(' | ') });
      el.value = opt.value;
      fire('input'); fire('change');
    } else if (tag === 'INPUT' || tag === 'TEXTAREA') {
      const proto = tag === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
      const desc = Object.getOwnPropertyDescriptor(proto, 'value');
      if (desc && desc.set) desc.set.call(el, text); else el.value = text;
      fire('input'); fire('change');
    } else if (el.isContentEditable) {
      const range = document.createRange();
      range.selectNodeContents(el);
      const s = window.getSelection();
      s.removeAllRanges(); s.addRange(range);
      if (!document.execCommand('insertText', false, text)) el.textContent = text;
      fire('input');
    } else {
      return JSON.stringify({ ok: false, error: 'この要素には入力できません（' + tag.toLowerCase() + '）' });
    }
    if (submit) {
      const kd = { key: 'Enter', code: 'Enter', bubbles: true, cancelable: true };
      const notCancelled = el.dispatchEvent(new KeyboardEvent('keydown', kd));
      el.dispatchEvent(new KeyboardEvent('keypress', kd));
      el.dispatchEvent(new KeyboardEvent('keyup', kd));
      if (notCancelled && el.form) {
        if (typeof el.form.requestSubmit === 'function') el.form.requestSubmit(); else el.form.submit();
      }
    }
    return JSON.stringify({ ok: true });
    """#

    /// Scrolls the page. Args: direction ("up" | "down" | "top" | "bottom")
    static let scroll = #"""
    const h = window.innerHeight * 0.8;
    if (direction === 'down') window.scrollBy(0, h);
    else if (direction === 'up') window.scrollBy(0, -h);
    else if (direction === 'top') window.scrollTo(0, 0);
    else if (direction === 'bottom') window.scrollTo(0, document.documentElement.scrollHeight);
    return JSON.stringify({ ok: true, scrollY: Math.round(window.scrollY), scrollHeight: Math.round(document.documentElement.scrollHeight) });
    """#
}

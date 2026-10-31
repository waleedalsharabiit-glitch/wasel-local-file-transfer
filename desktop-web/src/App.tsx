import { useEffect, useRef, useState } from "react";
import "./index.css";

type PhoneFile = { name: string; size: number; sha256: string };
type QueueFile = { id: string; file: File; progress: number; state: "waiting" | "sending" | "done" | "error" | "cancelled"; transferId?: string; speed?: number; eta?: number; error?: string };
const CHUNK_SIZE = 4 * 1024 * 1024;

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 ** 3) return `${(bytes / 1024 ** 2).toFixed(1)} MB`;
  return `${(bytes / 1024 ** 3).toFixed(2)} GB`;
}
function formatDuration(seconds = 0): string {
  if (!Number.isFinite(seconds) || seconds <= 0) return "أقل من ثانية";
  if (seconds < 60) return `${Math.ceil(seconds)} ث`;
  return `${Math.floor(seconds / 60)} د ${Math.ceil(seconds % 60)} ث`;
}

function App() {
  const pickerRef = useRef<HTMLInputElement>(null);
  const [baseUrl, setBaseUrl] = useState("");
  const [token, setToken] = useState("");
  const [connected, setConnected] = useState(false);
  const [connecting, setConnecting] = useState(false);
  const [files, setFiles] = useState<QueueFile[]>([]);
  const [phoneFiles, setPhoneFiles] = useState<PhoneFile[]>([]);
  const [downloadProgress, setDownloadProgress] = useState<Record<string, { progress: number; speed: number; eta: number }>>({});
  const [activeTab, setActiveTab] = useState("send");
  const [dragging, setDragging] = useState(false);
  const [message, setMessage] = useState("");
  const activeUploads = useRef(new Map<string, XMLHttpRequest>());
  const cancelledUploads = useRef(new Set<string>());

  const requestHeaders = { Authorization: `Bearer ${token}` };
  const refreshFiles = async () => {
    if (!connected) return;
    try {
      const response = await fetch(`${baseUrl}/api/files`, { headers: requestHeaders });
      if (!response.ok) throw new Error(response.status === 401 ? "رمز الجلسة غير صحيح أو انتهت صلاحيته." : "تعذر تحميل ملفات الهاتف.");
      const result = (await response.json()) as { files: PhoneFile[] };
      setPhoneFiles(result.files);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "تعذر الاتصال بالهاتف.");
    }
  };

  useEffect(() => {
    if (!connected) return;
    void refreshFiles();
    const timer = window.setInterval(() => void refreshFiles(), 5000);
    return () => window.clearInterval(timer);
  }, [connected, baseUrl, token]);

  const connect = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    let parsedUrl: URL;
    try { parsedUrl = new URL(baseUrl.trim()); } catch {
      setMessage("أدخل عنوان الهاتف كما يظهر في التطبيق، مثل http://192.168.1.20:8080");
      return;
    }
    if (parsedUrl.protocol !== "http:") {
      setMessage("عنوان الجلسة المحلية يبدأ بـ http://");
      return;
    }
    const normalizedUrl = `${parsedUrl.protocol}//${parsedUrl.host}`;
    const sessionToken = token.trim() || parsedUrl.searchParams.get("token") || "";
    if (!sessionToken) { setMessage("أدخل رمز الجلسة أو الصق رابط الهاتف كاملًا."); return; }
    setConnecting(true);
    setMessage("");
    try {
      const response = await fetch(`${normalizedUrl}/api/status`, { headers: { Authorization: `Bearer ${sessionToken}` } });
      if (!response.ok) throw new Error(response.status === 401 ? "رمز الجلسة غير صحيح." : "لم يستجب خادم الهاتف.");
      setBaseUrl(normalizedUrl);
      setToken(sessionToken);
      setConnected(true);
      setMessage("تم الاتصال بالهاتف عبر الشبكة المحلية.");
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "تعذر الاتصال. تأكد من الشبكة والعنوان ورمز الجلسة.");
    } finally {
      setConnecting(false);
    }
  };

  const addFiles = (selected: FileList | File[]) => {
    const incoming = Array.from(selected);
    setFiles((current) => {
      const known = new Set(current.map((item) => `${item.file.name}:${item.file.size}:${item.file.lastModified}`));
      return [...current, ...incoming.filter((file) => !known.has(`${file.name}:${file.size}:${file.lastModified}`)).map((file) => ({ id: crypto.randomUUID(), file, progress: 0, state: "waiting" as const }))];
    });
  };

  const xhrRequest = (url: string, method: string, body?: Document | XMLHttpRequestBodyInit | null, headers: Record<string, string> = {}, onProgress?: (loaded: number) => void, id?: string) => new Promise<XMLHttpRequest>((resolve, reject) => {
    const xhr = new XMLHttpRequest(); xhr.open(method, url); xhr.responseType = "json";
    Object.entries({ Authorization: `Bearer ${token}`, ...headers }).forEach(([key, value]) => xhr.setRequestHeader(key, value));
    if (id) activeUploads.current.set(id, xhr);
    xhr.upload.onprogress = (event) => { if (event.lengthComputable) onProgress?.(event.loaded); };
    xhr.onload = () => { if (id) activeUploads.current.delete(id); if (xhr.status >= 200 && xhr.status < 300) resolve(xhr); else reject(new Error(xhr.status === 401 ? "انتهت صلاحية رمز الجلسة." : `استجاب الهاتف بالرمز ${xhr.status}.`)); };
    xhr.onerror = () => { if (id) activeUploads.current.delete(id); reject(new Error("انقطع الاتصال بالشبكة.")); };
    xhr.onabort = () => { if (id) activeUploads.current.delete(id); reject(new DOMException("تم إلغاء النقل.", "AbortError")); };
    xhr.send(body ?? null);
  });

  const patchFile = (id: string, patch: Partial<QueueFile>) => setFiles((current) => current.map((file) => file.id === id ? { ...file, ...patch } : file));
  const cancelFile = (item: QueueFile) => { cancelledUploads.current.add(item.id); activeUploads.current.get(item.id)?.abort(); if (!activeUploads.current.has(item.id)) patchFile(item.id, { state: "cancelled" }); };
  const uploadFile = async (item: QueueFile) => {
    cancelledUploads.current.delete(item.id);
    const clientId = `${item.file.name}:${item.file.size}:${item.file.lastModified}`;
    let transferId = item.transferId;
    try {
      patchFile(item.id, { state: "sending", error: undefined });
      if (!transferId) {
        const created = await xhrRequest(`${baseUrl}/api/v1/transfers`, "POST", JSON.stringify({ name: item.file.name, size: item.file.size, clientId }), { "Content-Type": "application/json" }, undefined, item.id);
        transferId = created.response.transferId as string;
        patchFile(item.id, { transferId });
      }
      let status = await xhrRequest(`${baseUrl}/api/v1/transfers/${transferId}`, "GET", null, {}, undefined, item.id);
      let offset = Number(status.response.offset ?? 0); const started = performance.now(); let lastAt = started; let lastBytes = offset;
      while (offset < item.file.size) {
        if (cancelledUploads.current.has(item.id)) throw new DOMException("تم إلغاء النقل.", "AbortError");
        const end = Math.min(offset + CHUNK_SIZE, item.file.size); const chunk = item.file.slice(offset, end);
        let retries = 0;
        while (true) {
          try {
            await xhrRequest(`${baseUrl}/api/v1/transfers/${transferId}`, "PUT", chunk, { "Content-Range": `bytes ${offset}-${end - 1}/${item.file.size}`, "Content-Type": "application/octet-stream" }, (loaded) => {
              const current = offset + loaded; const now = performance.now(); const elapsed = (now - lastAt) / 1000;
              const speed = elapsed >= .4 ? Math.max(0, (current - lastBytes) / elapsed) : undefined;
              if (speed !== undefined) { lastAt = now; lastBytes = current; }
              patchFile(item.id, { progress: item.file.size ? current / item.file.size * 100 : 100, speed, eta: speed ? (item.file.size - current) / speed : undefined });
            }, item.id);
            offset = end; break;
          } catch (error) {
            if (error instanceof DOMException && error.name === "AbortError") throw error;
            if (cancelledUploads.current.has(item.id)) throw new DOMException("تم إلغاء النقل.", "AbortError");
            status = await xhrRequest(`${baseUrl}/api/v1/transfers/${transferId}`, "GET", null, {}, undefined, item.id);
            offset = Number(status.response.offset ?? offset);
            if (offset >= end) break;
            if (++retries >= 4) throw error;
            await new Promise((resolve) => window.setTimeout(resolve, 500 * retries));
          }
        }
      }
      await xhrRequest(`${baseUrl}/api/v1/transfers/${transferId}/complete`, "POST", null, {}, undefined, item.id);
      cancelledUploads.current.delete(item.id); patchFile(item.id, { progress: 100, state: "done", speed: 0, eta: 0 });
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") {
        patchFile(item.id, { state: "cancelled" });
        if (transferId) {
          let removed = false;
          for (let attempt = 0; attempt < 20; attempt++) {
            try { await xhrRequest(`${baseUrl}/api/v1/transfers/${transferId}`, "DELETE"); removed = true; break; }
            catch (deleteError) { if (deleteError instanceof Error && deleteError.message.includes("404")) { removed = true; break; } await new Promise((resolve) => window.setTimeout(resolve, 250)); }
          }
          if (!removed) setMessage(`أُوقف إرسال ${item.file.name}، لكن الهاتف لم يؤكد حذف الجزء المؤقت. أعد الاتصال ثم أعد المحاولة.`);
        }
      } else { const detail = error instanceof Error ? error.message : "فشل النقل."; patchFile(item.id, { state: "error", error: detail }); setMessage(`تعذر إرسال ${item.file.name}: ${detail} يمكنك إعادة المحاولة وسيُستكمل من آخر جزء وصل.`); }
    }
  };
  const sendFiles = async (selected = files.filter((item) => item.state === "waiting" || item.state === "error" || item.state === "cancelled")) => {
    if (!connected) { setMessage("اتصل بالهاتف أولًا لإرسال الملفات."); return; }
    const workers = Array.from({ length: Math.min(2, selected.length) }, async () => { while (selected.length) { const next = selected.shift(); if (next) await uploadFile(next); } });
    await Promise.all(workers); await refreshFiles();
  };

  const downloadFile = async (file: PhoneFile) => {
    try {
      const saveWindow = window as typeof window & { showSaveFilePicker?: (options: { suggestedName: string }) => Promise<{ getFile: () => Promise<File>; createWritable: (options?: { keepExistingData?: boolean }) => Promise<{ write: (data: Uint8Array) => Promise<void>; seek: (position: number) => Promise<void>; close: () => Promise<void> }> }> };
      if (saveWindow.showSaveFilePicker) {
        const handle = await saveWindow.showSaveFilePicker({ suggestedName: file.name }); const resumeKey = `wasel-download:${baseUrl}:${file.name}:${file.size}:${file.sha256}`;
        const existing = await handle.getFile(); const savedOffset = Number(localStorage.getItem(resumeKey) ?? 0);
        let offset = Number.isSafeInteger(savedOffset) && savedOffset >= 0 && savedOffset <= existing.size && savedOffset <= file.size ? savedOffset : 0;
        const startedAt = performance.now();
        const writable = await handle.createWritable({ keepExistingData: true }); await writable.seek(offset);
        try {
          while (offset < file.size) {
            const end = Math.min(offset + CHUNK_SIZE, file.size); const response = await fetch(`${baseUrl}/api/download?name=${encodeURIComponent(file.name)}`, { headers: { ...requestHeaders, Range: `bytes=${offset}-${end - 1}` } });
            if (!response.ok) throw new Error("تعذر تنزيل جزء من الملف."); const bytes = new Uint8Array(await response.arrayBuffer());
            if (bytes.length !== end - offset) throw new Error("وصل جزء ناقص؛ أعد التنزيل للاستكمال.");
            await writable.write(bytes); offset = end; localStorage.setItem(resumeKey, String(offset));
            const speed = Math.max(1, (offset - savedOffset) / Math.max(.001, (performance.now() - startedAt) / 1000));
            setDownloadProgress((current) => ({ ...current, [file.name]: { progress: offset / file.size * 100, speed, eta: (file.size - offset) / speed } }));
          }
          await writable.close(); localStorage.removeItem(resumeKey); setDownloadProgress((current) => ({ ...current, [file.name]: { progress: 100, speed: 0, eta: 0 } })); setMessage(`اكتمل تنزيل ${file.name} مباشرة إلى القرص.`);
        } catch (error) {
          await writable.close().catch(() => undefined); setMessage(`توقف تنزيل ${file.name} عند ${formatBytes(offset)}. أعد التنزيل واختر الملف نفسه لاستكماله.`); return;
        }
      } else {
        const ticketResponse = await fetch(`${baseUrl}/api/download-ticket`, { method: "POST", headers: { ...requestHeaders, "Content-Type": "application/json" }, body: JSON.stringify({ name: file.name }) });
        if (!ticketResponse.ok) throw new Error("تعذر تهيئة التنزيل الآمن.");
        const { ticket } = await ticketResponse.json() as { ticket: string };
        const link = document.createElement("a"); link.href = `${baseUrl}/api/download?name=${encodeURIComponent(file.name)}&ticket=${encodeURIComponent(ticket)}`; link.download = file.name; link.click();
        setMessage(`بدأ تنزيل ${file.name} عبر المتصفح مباشرةً دون تحميله كاملًا إلى ذاكرة الصفحة.`);
      }
    } catch (error) { setMessage(error instanceof Error ? error.message : "فشل التنزيل."); }
  };

  const deleteFile = async (file: PhoneFile) => {
    if (!window.confirm(`حذف ${file.name} من الهاتف؟`)) return;
    const response = await fetch(`${baseUrl}/api/files?name=${encodeURIComponent(file.name)}`, { method: "DELETE", headers: requestHeaders });
    if (response.ok) { setMessage("تم حذف الملف من الهاتف."); await refreshFiles(); }
    else setMessage("تعذر حذف الملف.");
  };

  const totalBytes = files.reduce((sum, item) => sum + item.file.size, 0);
  const doneCount = files.filter((item) => item.state === "done").length;

  return (
    <div className="app-shell" dir="rtl">
      <aside className="sidebar">
        <a className="brand" href="#home" aria-label="Wasel home"><span className="brand-mark">↔</span><span><strong>واصل</strong><small>WASEL TRANSFER</small></span></a>
        <div className="sidebar-label">مساحة العمل</div>
        <nav className="nav-list" aria-label="التنقل الرئيسي">
          <button className={activeTab === "send" ? "nav-item active" : "nav-item"} onClick={() => setActiveTab("send")}><span>↑</span> إرسال ملفات</button>
          <button className={activeTab === "receive" ? "nav-item active" : "nav-item"} onClick={() => setActiveTab("receive")}><span>↓</span> ملفات الهاتف</button>
          <button className={activeTab === "history" ? "nav-item active" : "nav-item"} onClick={() => setActiveTab("history")}><span>◷</span> سجل النقل</button>
        </nav>
        <div className="sidebar-bottom"><div className="security-mini"><span className="security-icon">⌑</span><div><strong>اتصال محلي</strong><small>لا حاجة إلى خادم سحابي</small></div></div><div className="version">WASEL · LOCAL TRANSFER</div></div>
      </aside>

      <main className="main-content" id="home">
        <header className="topbar"><div><div className="eyebrow">نقل الملفات بين أجهزتك</div><h1>{activeTab === "send" ? "أرسل ملفاتك بسهولة" : activeTab === "receive" ? "ملفات الهاتف" : "حالة النقل"}</h1></div>
          <div className="connection-pill"><span className="status-dot" style={{ background: connected ? "#22c55e" : undefined }} />{connected ? "متصل بالهاتف" : "غير متصل · أدخل بيانات الجلسة"}</div>
        </header>

        <section className="connection-panel">
          <div><h2>{connected ? "جلسة الهاتف" : "الاتصال بالهاتف"}</h2><p>{connected ? `العنوان: ${baseUrl}` : "شغّل الاستقبال في تطبيق Wasel على الهاتف، ثم أدخل العنوان ورمز الجلسة الظاهرين."}</p></div>
          {connected ? <button className="secondary-button" onClick={() => { setConnected(false); setToken(""); setPhoneFiles([]); setMessage("تم إنهاء الجلسة على هذا الكمبيوتر."); }}>قطع الاتصال</button> : <form className="connect-form" onSubmit={connect}>
            <label>عنوان الهاتف<input required inputMode="url" placeholder="http://192.168.1.20:8080" value={baseUrl} onChange={(event) => setBaseUrl(event.target.value)} /></label>
            <label>رمز الجلسة<input type="password" autoComplete="off" placeholder="أو الصق رابط الجلسة كاملًا" value={token} onChange={(event) => setToken(event.target.value)} /></label>
            <button className="primary-button" disabled={connecting}>{connecting ? "جارٍ الاتصال…" : "اتصال"}</button>
          </form>}
          {message && <p className="connection-message" role="status">{message}</p>}
        </section>

        {activeTab === "send" && <>
          <section className="hero"><div className="hero-copy"><span className="hero-tag"><span className="tag-dot" /> بسيط، محلي، مباشر</span><h2>ملفاتك تنتقل<br /><span>معك أينما تحتاج.</span></h2><p>انقل الصور والمستندات والفيديوهات بين الكمبيوتر وهاتفك عبر شبكة Wi-Fi أو نقطة الاتصال.</p><div className="hero-points"><span>✓ بدون حساب إلزامي</span><span>✓ ملفاتك تبقى على أجهزتك</span></div></div>
            <div className="hero-visual" aria-hidden="true"><div className="orbit orbit-one" /><div className="orbit orbit-two" /><div className="device-card phone-card"><div className="phone-notch" /><div className="device-symbol">▣</div><strong>هاتفك</strong><small>Android</small></div><div className="transfer-arrow">↔</div><div className="device-card computer-card"><div className="monitor-screen">⌘</div><strong>الكمبيوتر</strong><small>Browser</small></div><div className="floating-file file-a">JPG <span>صورة</span></div><div className="floating-file file-b">PDF <span>مستند</span></div></div>
          </section>
          <section className="section-heading"><div><h2>إرسال ملفات إلى الهاتف</h2><p>اختر ملفاتًا أو اسحبها، ثم ابدأ الإرسال عبر الاتصال المحلي.</p></div><span className="file-count">{files.length} ملفات · {formatBytes(totalBytes)}</span></section>
          <section className={dragging ? "drop-zone dragging" : "drop-zone"} onDragOver={(event) => { event.preventDefault(); setDragging(true); }} onDragLeave={() => setDragging(false)} onDrop={(event) => { event.preventDefault(); setDragging(false); addFiles(event.dataTransfer.files); }}>
            <input ref={pickerRef} className="visually-hidden" type="file" multiple onChange={(event) => { if (event.target.files) addFiles(event.target.files); event.target.value = ""; }} />
            <div className="upload-icon">↑</div><h3>اسحب ملفاتك وأفلتها هنا</h3><p>أو اختر الملفات من جهازك</p><button className="primary-button" onClick={() => pickerRef.current?.click()}><span>＋</span> اختيار الملفات</button><small>يتم إرسال الملفات مباشرة إلى الهاتف دون وسيط سحابي.</small>
          </section>
          {files.length > 0 && <section className="file-panel"><div className="file-panel-header"><div><h3>قائمة الإرسال</h3><p>{doneCount} من {files.length} مكتمل · {formatBytes(totalBytes)} · نقل متوازٍ لملفين</p></div><button className="primary-button" disabled={!connected || files.every((item) => item.state === "done" || item.state === "sending")} onClick={() => void sendFiles()}>إرسال إلى الهاتف</button></div>
            <div className="file-list">{files.map((item) => <div className="file-row transfer-row" key={item.id}><div className={`file-type ${item.state === "done" ? "done" : item.state === "error" ? "failed" : ""}`}>{item.state === "done" ? "✓" : "ملف"}</div><div className="file-meta"><strong title={item.file.name}>{item.file.name}</strong><small>{formatBytes(item.file.size)} · {item.state === "done" ? "اكتمل وتحقق الهاتف من SHA-256" : item.state === "sending" ? `جارٍ الإرسال ${Math.round(item.progress)}%${item.speed ? ` · ${formatBytes(item.speed)}/ث · متبقٍ ${formatDuration(item.eta)}` : " · تحضير النقل"}` : item.state === "error" ? `تعذر النقل · ${item.error ?? "أعد المحاولة للاستكمال"}` : item.state === "cancelled" ? "أُلغي · يمكن استكماله عند إعادة الإرسال" : "بانتظار الإرسال"}</small>{(item.state === "sending" || item.progress > 0) && <progress className="file-progress" max="100" value={item.progress} />}</div>{item.state === "sending" ? <button className="control-button cancel-button" aria-label={`إلغاء ${item.file.name}`} onClick={() => cancelFile(item)}>إيقاف</button> : item.state === "error" || item.state === "cancelled" ? <button className="control-button retry-button" onClick={() => void sendFiles([item])}>إعادة</button> : <button className="remove-file" aria-label={`إزالة ${item.file.name}`} onClick={() => setFiles((current) => current.filter((file) => file.id !== item.id))}>×</button>}</div>)}</div>
          </section>}
          <section className="feature-grid"><article className="feature-card"><div className="feature-icon blue">⌁</div><h3>نقل محلي</h3><p>يعمل عبر شبكة Wi-Fi أو نقطة اتصال الهاتف.</p></article><article className="feature-card"><div className="feature-icon green">✓</div><h3>تحقق من الملفات</h3><p>يتحقق الهاتف من سلامة الملفات باستخدام SHA-256.</p></article><article className="feature-card"><div className="feature-icon violet">▤</div><h3>تدفق مباشر</h3><p>ترسل الملفات إلى الهاتف دون تحميلها كاملة في الذاكرة.</p></article></section>
        </>}

        {activeTab === "receive" && <section className="file-panel phone-file-panel"><div className="file-panel-header"><div><h3>الملفات المتاحة على الهاتف</h3><p>{phoneFiles.length} ملفًا</p></div><button className="secondary-button" disabled={!connected} onClick={() => void refreshFiles()}>تحديث</button></div>{phoneFiles.length === 0 ? <div className="empty-state compact"><div className="empty-icon">↓</div><h2>{connected ? "لا توجد ملفات على الهاتف" : "اتصل بالهاتف لعرض ملفاته"}</h2><p>ستظهر هنا الملفات التي اخترتها من التطبيق على الهاتف. يمكنك تنزيلها إلى الكمبيوتر أو حذفها.</p></div> : <div className="file-list">{phoneFiles.map((file) => <div className="file-row" key={file.name}><div className="file-type">ملف</div><div className="file-meta"><strong title={file.name}>{file.name}</strong><small>{formatBytes(file.size)} · SHA-256 {file.sha256.slice(0, 12)}…</small>{downloadProgress[file.name] && <><progress className="file-progress" max="100" value={downloadProgress[file.name].progress} /><small>{downloadProgress[file.name].progress >= 100 ? "اكتمل التنزيل" : `${Math.round(downloadProgress[file.name].progress)}% · ${formatBytes(downloadProgress[file.name].speed)}/ث · متبقٍ ${formatDuration(downloadProgress[file.name].eta)}`}</small></>}</div><button className="secondary-button" onClick={() => void downloadFile(file)}>تنزيل</button><button className="remove-file" aria-label={`حذف ${file.name}`} onClick={() => void deleteFile(file)}>×</button></div>)}</div>}</section>}

        {activeTab === "history" && <section className="file-panel"><div className="file-panel-header"><div><h3>سجل النقل في هذه الجلسة</h3><p>{doneCount} مكتمل · {files.filter((item) => item.state === "error" || item.state === "cancelled").length} يحتاج متابعة</p></div><button className="secondary-button" onClick={() => setActiveTab("send")}>العودة إلى الإرسال</button></div>{files.length ? <div className="file-list">{files.map((item) => <div className="file-row" key={item.id}><div className={`file-type ${item.state === "done" ? "done" : ""}`}>{item.state === "done" ? "✓" : "↔"}</div><div className="file-meta"><strong>{item.file.name}</strong><small>{formatBytes(item.file.size)} · {item.state === "done" ? "اكتمل" : item.state === "error" ? "فشل" : item.state === "cancelled" ? "أُلغي" : item.state === "sending" ? "جارٍ النقل" : "بالانتظار"}</small></div></div>)}</div> : <div className="empty-state compact"><div className="empty-icon">◷</div><h2>لا توجد عمليات نقل بعد</h2></div>}</section>}
        <footer className="footer"><span>Wasel — واصل</span><span>نقل محلي مباشر · دون خادم سحابي</span></footer>
      </main>
    </div>
  );
}

export default App;

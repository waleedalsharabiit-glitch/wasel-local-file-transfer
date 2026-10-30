import { useRef, useState } from "react";
import "./index.css";

type LocalFile = {
  id: string;
  file: File;
};

function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 * 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

function fileKind(file: File): string {
  if (file.type.startsWith("image/")) return "صورة";
  if (file.type.startsWith("video/")) return "فيديو";
  if (file.type.startsWith("audio/")) return "صوت";
  if (file.type.includes("pdf")) return "PDF";
  return "ملف";
}

function App() {
  const pickerRef = useRef<HTMLInputElement>(null);
  const [files, setFiles] = useState<LocalFile[]>([]);
  const [activeTab, setActiveTab] = useState("send");
  const [dragging, setDragging] = useState(false);

  const addFiles = (selected: FileList | File[]) => {
    const incoming = Array.from(selected);
    setFiles((current) => {
      const known = new Set(current.map((item) => `${item.file.name}:${item.file.size}:${item.file.lastModified}`));
      const additions = incoming
        .filter((file) => !known.has(`${file.name}:${file.size}:${file.lastModified}`))
        .map((file) => ({
          id: `${file.name}-${file.size}-${file.lastModified}-${Math.random()}`,
          file,
        }));
      return [...current, ...additions];
    });
  };

  const totalBytes = files.reduce((sum, item) => sum + item.file.size, 0);

  return (
    <div className="app-shell" dir="rtl">
      <aside className="sidebar">
        <a className="brand" href="#home" aria-label="Wasel home">
          <span className="brand-mark">↔</span>
          <span>
            <strong>واصل</strong>
            <small>WASEL TRANSFER</small>
          </span>
        </a>

        <div className="sidebar-label">مساحة العمل</div>
        <nav className="nav-list" aria-label="التنقل الرئيسي">
          <button className={activeTab === "send" ? "nav-item active" : "nav-item"} onClick={() => setActiveTab("send")}>
            <span>↑</span> إرسال ملفات
          </button>
          <button className={activeTab === "receive" ? "nav-item active" : "nav-item"} onClick={() => setActiveTab("receive")}>
            <span>↓</span> استقبال ملفات
          </button>
          <button className={activeTab === "history" ? "nav-item active" : "nav-item"} onClick={() => setActiveTab("history")}>
            <span>◷</span> سجل النقل
          </button>
        </nav>

        <div className="sidebar-bottom">
          <div className="security-mini">
            <span className="security-icon">⌑</span>
            <div>
              <strong>اتصال محلي</strong>
              <small>لا حاجة إلى خادم سحابي</small>
            </div>
          </div>
          <div className="version">WASEL · PHASE 02</div>
        </div>
      </aside>

      <main className="main-content" id="home">
        <header className="topbar">
          <div>
            <div className="eyebrow">نقل الملفات بين أجهزتك</div>
            <h1>
              {activeTab === "send" && "أرسل ملفاتك بسهولة"}
              {activeTab === "receive" && "استقبال الملفات"}
              {activeTab === "history" && "سجل النقل"}
            </h1>
          </div>
          <div className="connection-pill">
            <span className="status-dot" />
            واجهة جاهزة · بانتظار ربط الهاتف
          </div>
        </header>

        {activeTab === "send" && (
          <>
            <section className="hero">
              <div className="hero-copy">
                <span className="hero-tag"><span className="tag-dot" /> بسيط، محلي، مباشر</span>
                <h2>ملفاتك تنتقل<br /><span>معك أينما تحتاج.</span></h2>
                <p>واجهة واحدة لتجهيز نقل الصور والمستندات والفيديوهات بين الكمبيوتر وهاتفك، عبر الشبكة المحلية.</p>
                <div className="hero-points">
                  <span>✓ بدون حساب إلزامي</span>
                  <span>✓ ملفاتك تبقى على أجهزتك</span>
                </div>
              </div>
              <div className="hero-visual" aria-hidden="true">
                <div className="orbit orbit-one" />
                <div className="orbit orbit-two" />
                <div className="device-card phone-card">
                  <div className="phone-notch" />
                  <div className="device-symbol">▣</div>
                  <strong>هاتفك</strong>
                  <small>Android</small>
                </div>
                <div className="transfer-arrow">↔</div>
                <div className="device-card computer-card">
                  <div className="monitor-screen">⌘</div>
                  <strong>الكمبيوتر</strong>
                  <small>Browser</small>
                </div>
                <div className="floating-file file-a">JPG <span>صورة</span></div>
                <div className="floating-file file-b">PDF <span>مستند</span></div>
              </div>
            </section>

            <section className="section-heading">
              <div>
                <h2>تجهيز الملفات</h2>
                <p>اختر الملفات من جهاز الكمبيوتر. لم يبدأ النقل إلى الهاتف بعد.</p>
              </div>
              <span className="file-count">{files.length} ملفات محددة</span>
            </section>

            <section
              className={dragging ? "drop-zone dragging" : "drop-zone"}
              onDragOver={(event) => {
                event.preventDefault();
                setDragging(true);
              }}
              onDragLeave={() => setDragging(false)}
              onDrop={(event) => {
                event.preventDefault();
                setDragging(false);
                addFiles(event.dataTransfer.files);
              }}
            >
              <input
                ref={pickerRef}
                className="visually-hidden"
                type="file"
                multiple
                onChange={(event) => {
                  if (event.target.files) addFiles(event.target.files);
                  event.target.value = "";
                }}
              />
              <div className="upload-icon">↑</div>
              <h3>اسحب ملفاتك وأفلتها هنا</h3>
              <p>أو اختر الملفات من جهازك لتجهيز قائمة الإرسال</p>
              <button className="primary-button" onClick={() => pickerRef.current?.click()}>
                <span>＋</span> اختيار الملفات
              </button>
              <small>يتم اختيار الملفات محليًا داخل المتصفح في هذه المرحلة.</small>
            </section>

            {files.length > 0 && (
              <section className="file-panel">
                <div className="file-panel-header">
                  <div>
                    <h3>الملفات المختارة</h3>
                    <p>{files.length} ملفات · {formatBytes(totalBytes)}</p>
                  </div>
                  <button className="text-button" onClick={() => setFiles([])}>مسح القائمة</button>
                </div>
                <div className="file-list">
                  {files.map(({ id, file }) => (
                    <div className="file-row" key={id}>
                      <div className="file-type">{fileKind(file)}</div>
                      <div className="file-meta">
                        <strong title={file.name}>{file.name}</strong>
                        <small>{formatBytes(file.size)} · {file.type || "نوع غير محدد"}</small>
                      </div>
                      <button
                        className="remove-file"
                        aria-label={`إزالة ${file.name}`}
                        onClick={() => setFiles((current) => current.filter((item) => item.id !== id))}
                      >×</button>
                    </div>
                  ))}
                </div>
                <div className="notice">
                  <span>ⓘ</span>
                  قائمة الملفات محلية فقط. سيُفعّل زر الإرسال بعد بناء الخادم المحلي والإقران في المراحل القادمة.
                </div>
              </section>
            )}

            <section className="feature-grid">
              <article className="feature-card">
                <div className="feature-icon blue">⌁</div>
                <h3>نقل محلي</h3>
                <p>التصميم موجّه للعمل عبر شبكة Wi-Fi أو نقطة اتصال الهاتف.</p>
              </article>
              <article className="feature-card">
                <div className="feature-icon green">✓</div>
                <h3>تحقق من الملفات</h3>
                <p>سيُضاف التحقق من سلامة الملفات باستخدام SHA-256 إلى محرك النقل.</p>
              </article>
              <article className="feature-card">
                <div className="feature-icon violet">▤</div>
                <h3>ملفات كبيرة</h3>
                <p>ستُنفّذ آلية التدفق والأجزاء والاستئناف ضمن نواة النقل.</p>
              </article>
            </section>
          </>
        )}

        {activeTab === "receive" && (
          <section className="empty-state">
            <div className="empty-icon">↓</div>
            <h2>استقبال الملفات من الهاتف</h2>
            <p>بعد تنفيذ الخادم المحلي والإقران، ستظهر هنا حالة الاتصال والملفات التي يرسلها الهاتف.</p>
            <div className="inline-notice">هذه الواجهة لا تستقبل الملفات عبر الشبكة حتى الآن.</div>
            <button className="secondary-button" onClick={() => setActiveTab("send")}>العودة إلى إرسال الملفات</button>
          </section>
        )}

        {activeTab === "history" && (
          <section className="empty-state">
            <div className="empty-icon">◷</div>
            <h2>لا يوجد سجل نقل بعد</h2>
            <p>سيُعرض هنا اسم الملف وحجمه واتجاه النقل وحالته ووقت اكتماله بعد بناء محرك النقل.</p>
            <button className="secondary-button" onClick={() => setActiveTab("send")}>تجهيز ملفات جديدة</button>
          </section>
        )}

        <footer className="footer">
          <span>Wasel — واصل</span>
          <span>واجهة المرحلة الثانية · وظائف النقل قيد التنفيذ</span>
        </footer>
      </main>
    </div>
  );
}

export default App;

const S3_BASE = "https://inputalk.s3.us-east-1.amazonaws.com";

interface ReleaseInfo {
  version: string;
  date: string;
  dmg: { url: string; size: number; filename: string };
}

async function getRelease(): Promise<ReleaseInfo | null> {
  try {
    const res = await fetch(`${S3_BASE}/releases/latest.json`, {
      next: { revalidate: 60 },
    });
    if (!res.ok) return null;
    return res.json();
  } catch {
    return null;
  }
}

function mb(bytes: number) {
  return `${(bytes / 1048576).toFixed(1)} MB`;
}

export default async function Page() {
  const release = await getRelease();

  return (
    <div className="grain min-h-screen flex flex-col">
      {/* ── Nav ──────────────────────────────────────────────── */}
      <nav className="relative z-10 flex items-center justify-between px-6 lg:px-10 py-6 max-w-[1080px] mx-auto w-full">
        <span className="font-[family-name:var(--font-mono)] text-[13px] tracking-wide text-[var(--color-text-primary)]">
          inputalk
        </span>
        <div className="flex items-center gap-6">
          <a
            href="https://github.com/sebi75/inputalk"
            className="text-[13px] text-[var(--color-text-secondary)] hover:text-[var(--color-text-primary)] transition-colors duration-200"
          >
            source
          </a>
        </div>
      </nav>

      {/* ── Hero ─────────────────────────────────────────────── */}
      <main className="relative z-10 flex-1 flex flex-col items-center justify-center px-6 pt-16 sm:pt-24 pb-32">
        {/* Waveform accent */}
        <div className="flex items-end gap-[3px] h-8 mb-10">
          {[0.4, 0.7, 1, 0.8, 0.5, 0.9, 0.6, 1, 0.45, 0.75, 0.55, 0.85].map(
            (h, i) => (
              <div
                key={i}
                className="w-[2px] rounded-full bg-[var(--color-accent)]"
                style={{
                  height: `${h * 28}px`,
                  opacity: 0.4 + h * 0.4,
                  animation: `waveform-bar ${1.2 + i * 0.15}s ease-in-out infinite`,
                  animationDelay: `${i * 0.08}s`,
                }}
              />
            )
          )}
        </div>

        <h1 className="font-[family-name:var(--font-syne)] text-[var(--color-text-primary)] text-4xl sm:text-[52px] font-bold tracking-[-0.03em] leading-[1.08] text-center max-w-xl">
          Dictation for macOS
        </h1>

        <p className="mt-5 text-base sm:text-[17px] leading-relaxed text-center max-w-md text-[var(--color-text-secondary)]">
          Hold{" "}
          <Key>fn</Key>, speak, release.
          Text appears wherever your cursor is.
          {" "}Transcription runs on&#8209;device — no accounts, no cloud, no cost.
        </p>

        {/* CTA */}
        <div className="mt-10 flex flex-col items-center gap-3">
          <a
            href={release?.dmg.url ?? "#"}
            className="group inline-flex items-center gap-2 px-5 py-2.5 rounded-lg bg-[var(--color-text-primary)] text-[var(--color-surface)] text-sm font-medium hover:opacity-90 transition-opacity"
          >
            <svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
            </svg>
            Download for Mac
          </a>
          <span className="font-[family-name:var(--font-mono)] text-[11px] text-[var(--color-text-tertiary)]">
            {release
              ? `v${release.version} · ${mb(release.dmg.size)} · macOS 15+`
              : "macOS 15+ · Apple Silicon & Intel"}
          </span>
        </div>

        {/* ── Flow ───────────────────────────────────────────── */}
        <div className="mt-28 sm:mt-36 w-full max-w-2xl">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-px bg-[var(--color-border-subtle)] rounded-xl overflow-hidden">
            <FlowStep
              step="01"
              title="Hold Fn and speak"
              detail="Push-to-talk dictation. Or double-press Fn for hands-free mode."
            />
            <FlowStep
              step="02"
              title="Transcribed on-device"
              detail="Speech-to-text runs locally on Apple Neural Engine. Nothing is sent anywhere."
            />
            <FlowStep
              step="03"
              title="Pasted at your cursor"
              detail="Release Fn. Text appears in whatever app you're using — Slack, VS Code, email, anywhere."
            />
          </div>
        </div>

        {/* ── Details ────────────────────────────────────────── */}
        <div className="mt-20 sm:mt-28 w-full max-w-2xl">
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-8 sm:gap-6">
            <Detail label="Engine" value="WhisperKit" />
            <Detail label="Processing" value="On-device" />
            <Detail label="Cost" value="Free" />
            <Detail label="License" value="Open source" />
          </div>
        </div>

        {/* ── Supported models ────────────────────────────────── */}
        <div className="mt-20 sm:mt-28 w-full max-w-2xl">
          <p className="font-[family-name:var(--font-mono)] text-[11px] text-[var(--color-text-tertiary)] uppercase tracking-widest mb-4">
            Models
          </p>
          <div className="flex flex-wrap gap-2">
            {[
              { name: "tiny", size: "75 MB", speed: "fastest" },
              { name: "base", size: "142 MB", speed: "default" },
              { name: "small", size: "466 MB", speed: "balanced" },
              { name: "medium", size: "1.5 GB", speed: "accurate" },
            ].map((m) => (
              <div
                key={m.name}
                className="flex items-center gap-3 px-3.5 py-2 rounded-lg border border-[var(--color-border-subtle)] bg-[var(--color-surface-raised)]"
              >
                <span className="font-[family-name:var(--font-mono)] text-[13px] text-[var(--color-text-primary)]">
                  {m.name}
                </span>
                <span className="text-[11px] text-[var(--color-text-tertiary)]">
                  {m.size}
                </span>
              </div>
            ))}
          </div>
          <p className="mt-3 text-[13px] text-[var(--color-text-tertiary)]">
            Models download on first use. Stored locally, deleted when you
            uninstall.
          </p>
        </div>
      </main>

      {/* ── Footer ───────────────────────────────────────────── */}
      <footer className="relative z-10 border-t border-[var(--color-border-subtle)]">
        <div className="max-w-[1080px] mx-auto px-6 lg:px-10 py-6 flex items-center justify-between">
          <span className="font-[family-name:var(--font-mono)] text-[11px] text-[var(--color-text-tertiary)]">
            built with whisperkit
          </span>
          <a
            href="https://github.com/sebi75/inputalk"
            className="font-[family-name:var(--font-mono)] text-[11px] text-[var(--color-text-tertiary)] hover:text-[var(--color-text-secondary)] transition-colors"
          >
            github.com/sebi75/inputalk
          </a>
        </div>
      </footer>
    </div>
  );
}

/* ── Components ──────────────────────────────────────────────── */

function Key({ children }: { children: React.ReactNode }) {
  return (
    <kbd className="inline-flex items-center justify-center min-w-[1.6em] px-1.5 py-0.5 rounded-[5px] border border-[var(--color-border-subtle)] bg-[var(--color-surface-raised)] font-[family-name:var(--font-mono)] text-[13px] text-[var(--color-text-primary)] leading-none align-baseline translate-y-[-0.5px]">
      {children}
    </kbd>
  );
}

function FlowStep({
  step,
  title,
  detail,
}: {
  step: string;
  title: string;
  detail: string;
}) {
  return (
    <div className="bg-[var(--color-surface-raised)] p-5 sm:p-6">
      <span className="font-[family-name:var(--font-mono)] text-[11px] text-[var(--color-text-tertiary)]">
        {step}
      </span>
      <h3 className="mt-2 text-[15px] font-medium text-[var(--color-text-primary)]">
        {title}
      </h3>
      <p className="mt-1.5 text-[13px] leading-relaxed text-[var(--color-text-secondary)]">
        {detail}
      </p>
    </div>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="font-[family-name:var(--font-mono)] text-[11px] text-[var(--color-text-tertiary)] uppercase tracking-widest">
        {label}
      </p>
      <p className="mt-1 text-[15px] text-[var(--color-text-primary)]">
        {value}
      </p>
    </div>
  );
}

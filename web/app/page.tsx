const S3_BASE = "https://inputalk.s3.us-east-1.amazonaws.com";
const LATEST_JSON_URL = `${S3_BASE}/releases/latest.json`;

interface ReleaseInfo {
  version: string;
  date: string;
  dmg: {
    url: string;
    size: number;
    filename: string;
  };
}

async function getLatestRelease(): Promise<ReleaseInfo | null> {
  try {
    const res = await fetch(LATEST_JSON_URL, {
      next: { revalidate: 60 },
    });
    if (!res.ok) return null;
    return res.json();
  } catch {
    return null;
  }
}

function formatBytes(bytes: number): string {
  const mb = bytes / (1024 * 1024);
  return `${mb.toFixed(1)} MB`;
}

export default async function Home() {
  const release = await getLatestRelease();

  return (
    <div className="min-h-screen flex flex-col">
      {/* Ambient glow */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-[-20%] left-1/2 -translate-x-1/2 w-[800px] h-[600px] bg-blue-500/[0.07] rounded-full blur-[120px]" />
        <div className="absolute bottom-[-10%] right-[-10%] w-[500px] h-[500px] bg-purple-500/[0.05] rounded-full blur-[100px]" />
      </div>

      {/* Nav */}
      <nav className="relative z-10 flex items-center justify-between px-6 py-5 max-w-5xl mx-auto w-full">
        <div className="flex items-center gap-2.5">
          <Waveform className="w-6 h-6 text-blue-400" />
          <span className="text-lg font-semibold tracking-tight">
            Inputalk
          </span>
        </div>
        <a
          href="https://github.com/sebi75/inputalk"
          target="_blank"
          rel="noopener noreferrer"
          className="text-sm text-zinc-400 hover:text-white transition-colors"
        >
          GitHub
        </a>
      </nav>

      {/* Hero */}
      <main className="relative z-10 flex-1 flex flex-col items-center justify-center px-6 pb-24">
        <div className="text-center max-w-2xl mx-auto">
          {/* Badge */}
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/[0.06] border border-white/[0.08] text-xs text-zinc-400 mb-8">
            <span className="inline-block w-1.5 h-1.5 rounded-full bg-green-400 animate-pulse" />
            100% local &middot; 100% free &middot; 100% private
          </div>

          {/* Headline */}
          <h1 className="text-5xl sm:text-6xl font-bold tracking-tight leading-[1.1] mb-6">
            Voice to text,{" "}
            <span className="bg-gradient-to-r from-blue-400 via-cyan-300 to-blue-400 bg-clip-text text-transparent">
              everywhere
            </span>
          </h1>

          {/* Subheadline */}
          <p className="text-lg sm:text-xl text-zinc-400 leading-relaxed mb-10 max-w-lg mx-auto">
            Hold{" "}
            <kbd className="px-1.5 py-0.5 rounded bg-white/[0.08] border border-white/[0.1] text-sm font-mono text-zinc-300">
              Fn
            </kbd>{" "}
            to talk, release to paste. Works in any app. Powered by on-device
            AI &mdash; no API keys, no cloud, no cost.
          </p>

          {/* CTA */}
          <div className="flex flex-col items-center gap-3">
            <a
              href={release?.dmg.url ?? "#"}
              className="group inline-flex items-center gap-2.5 px-7 py-3.5 rounded-xl bg-white text-black font-semibold text-base hover:bg-zinc-100 transition-all hover:scale-[1.02] active:scale-[0.98]"
            >
              <AppleLogo className="w-5 h-5" />
              Download for Mac
              {release && (
                <span className="text-zinc-500 text-sm font-normal">
                  ({formatBytes(release.dmg.size)})
                </span>
              )}
            </a>
            <span className="text-xs text-zinc-500">
              {release
                ? `v${release.version} · macOS 15+ · Apple Silicon & Intel`
                : "macOS 15+ · Apple Silicon & Intel"}
            </span>
          </div>
        </div>

        {/* Feature cards */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 mt-20 max-w-3xl mx-auto w-full">
          <FeatureCard
            icon={<FnKey />}
            title="Hold Fn to dictate"
            description="Push-to-talk with the Globe key. Or double-press for hands-free mode."
          />
          <FeatureCard
            icon={<CpuIcon />}
            title="Runs on-device"
            description="Whisper AI models run locally on your Mac. Nothing leaves your machine."
          />
          <FeatureCard
            icon={<ZapIcon />}
            title="Works everywhere"
            description="Slack, VS Code, Messages, Chrome — any text field, any app."
          />
        </div>

        {/* How it works */}
        <div className="mt-24 max-w-2xl mx-auto w-full text-center">
          <h2 className="text-2xl font-semibold mb-10 text-zinc-200">
            How it works
          </h2>
          <div className="flex flex-col sm:flex-row items-center justify-center gap-6 sm:gap-4">
            <Step number="1" text="Hold Fn and speak" />
            <Arrow />
            <Step number="2" text="AI transcribes locally" />
            <Arrow />
            <Step number="3" text="Text appears at cursor" />
          </div>
        </div>
      </main>

      {/* Footer */}
      <footer className="relative z-10 text-center py-8 text-xs text-zinc-600">
        Built with WhisperKit &middot; Open source &middot;{" "}
        <a
          href="https://github.com/sebi75/inputalk"
          className="text-zinc-500 hover:text-zinc-300 transition-colors"
        >
          GitHub
        </a>
      </footer>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Components
// ---------------------------------------------------------------------------

function FeatureCard({
  icon,
  title,
  description,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
}) {
  return (
    <div className="rounded-xl bg-white/[0.03] border border-white/[0.06] p-5 hover:bg-white/[0.05] transition-colors">
      <div className="mb-3 text-blue-400">{icon}</div>
      <h3 className="text-sm font-semibold mb-1.5">{title}</h3>
      <p className="text-xs text-zinc-500 leading-relaxed">{description}</p>
    </div>
  );
}

function Step({ number, text }: { number: string; text: string }) {
  return (
    <div className="flex items-center gap-3">
      <span className="flex-shrink-0 w-8 h-8 rounded-full bg-blue-500/10 border border-blue-500/20 flex items-center justify-center text-sm font-semibold text-blue-400">
        {number}
      </span>
      <span className="text-sm text-zinc-300">{text}</span>
    </div>
  );
}

function Arrow() {
  return (
    <svg
      className="w-5 h-5 text-zinc-600 hidden sm:block flex-shrink-0"
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3"
      />
    </svg>
  );
}

// ---------------------------------------------------------------------------
// Icons
// ---------------------------------------------------------------------------

function Waveform({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor">
      <rect x="2" y="9" width="2.5" height="6" rx="1.25" />
      <rect x="6.5" y="6" width="2.5" height="12" rx="1.25" />
      <rect x="11" y="3" width="2.5" height="18" rx="1.25" />
      <rect x="15.5" y="6" width="2.5" height="12" rx="1.25" />
      <rect x="20" y="9" width="2.5" height="6" rx="1.25" />
    </svg>
  );
}

function AppleLogo({ className }: { className?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" fill="currentColor">
      <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
    </svg>
  );
}

function FnKey() {
  return (
    <div className="w-8 h-8 rounded-lg bg-white/[0.06] border border-white/[0.1] flex items-center justify-center text-xs font-bold text-zinc-300">
      Fn
    </div>
  );
}

function CpuIcon() {
  return (
    <svg
      className="w-6 h-6"
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 6.75v10.5a2.25 2.25 0 002.25 2.25zm.75-12h9v9h-9v-9z"
      />
    </svg>
  );
}

function ZapIcon() {
  return (
    <svg
      className="w-6 h-6"
      fill="none"
      viewBox="0 0 24 24"
      strokeWidth={1.5}
      stroke="currentColor"
    >
      <path
        strokeLinecap="round"
        strokeLinejoin="round"
        d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z"
      />
    </svg>
  );
}

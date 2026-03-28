import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  Sequence,
  spring,
  useVideoConfig,
  Easing,
} from "remotion";

/* ================================================================
   INPUTALK LAUNCH VIDEO — 15s (450 frames @ 30fps)

   Shows 3 real use cases with our actual UI components:
   - Floating indicator (Liquid Glass capsule) with 3 states
   - Fn key trigger
   - Text appearing in real app contexts
   ================================================================ */

export const LaunchVideo: React.FC = () => {
  return (
    <AbsoluteFill className="bg-[#08080a]">
      {/* Dot grid texture */}
      <AbsoluteFill
        style={{
          backgroundImage:
            "radial-gradient(circle, #1a1a1e 1px, transparent 1px)",
          backgroundSize: "24px 24px",
          opacity: 0.4,
        }}
      />

      {/* 0-60: Cold open */}
      <Sequence from={0} durationInFrames={60}>
        <SceneColdOpen />
      </Sequence>

      {/* 60-180: Use case 1 — Slack message */}
      <Sequence from={60} durationInFrames={120}>
        <SceneUseCase
          app="slack"
          appLabel="Slack"
          placeholder="Message #engineering"
          dictatedText="Hey, can we push the standup to 3pm?"
        />
      </Sequence>

      {/* 180-290: Use case 2 — VS Code comment */}
      <Sequence from={180} durationInFrames={110}>
        <SceneUseCase
          app="vscode"
          appLabel="VS Code"
          placeholder=""
          dictatedText="// TODO: refactor auth middleware to use JWT"
          codeContext={true}
        />
      </Sequence>

      {/* 290-375: Use case 3 — Notes */}
      <Sequence from={290} durationInFrames={85}>
        <SceneUseCase
          app="notes"
          appLabel="Notes"
          placeholder="Start typing..."
          dictatedText="Remember to pick up the prescription after work"
        />
      </Sequence>

      {/* 375-450: Close */}
      <Sequence from={375} durationInFrames={75}>
        <SceneClose />
      </Sequence>
    </AbsoluteFill>
  );
};

/* ── Cold Open ───────────────────────────────────────────────── */

const SceneColdOpen: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const nameOpacity = interpolate(frame, [8, 22], [0, 1], {
    extrapolateRight: "clamp",
  });
  const nameY = interpolate(frame, [8, 22], [8, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const subOpacity = interpolate(frame, [22, 36], [0, 1], {
    extrapolateRight: "clamp",
  });
  const fadeOut = interpolate(frame, [48, 60], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      className="flex flex-col items-center justify-center"
      style={{ opacity: fadeOut }}
    >
      <div
        style={{
          opacity: nameOpacity,
          transform: `translateY(${nameY}px)`,
        }}
      >
        <span
          className="text-[42px] text-[#ececee] tracking-[-0.02em]"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}
        >
          inputalk
        </span>
      </div>
      <div className="mt-2" style={{ opacity: subOpacity }}>
        <span
          className="text-[18px] text-[#52525b]"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}
        >
          local voice-to-text for macOS
        </span>
      </div>
    </AbsoluteFill>
  );
};

/* ── Use Case Scene ──────────────────────────────────────────── */

interface UseCaseProps {
  app: "slack" | "vscode" | "notes";
  appLabel: string;
  placeholder: string;
  dictatedText: string;
  codeContext?: boolean;
}

const SceneUseCase: React.FC<UseCaseProps> = ({
  app,
  appLabel,
  placeholder,
  dictatedText,
  codeContext,
}) => {
  const frame = useCurrentFrame();

  const fadeIn = interpolate(frame, [0, 10], [0, 1], {
    extrapolateRight: "clamp",
  });
  const totalFrames = app === "notes" ? 85 : app === "vscode" ? 110 : 120;
  const fadeOut = interpolate(
    frame,
    [totalFrames - 12, totalFrames],
    [1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );

  // Timeline within each use case
  const fnPressFrame = 8;
  const recordStart = 14;
  const recordEnd = 40;
  const transcribeStart = 42;
  const transcribeEnd = 52;
  const typeStart = 54;
  const typeEnd = totalFrames - 16;

  const isFnPressed = frame >= fnPressFrame && frame < recordEnd + 4;
  const isRecording = frame >= recordStart && frame < recordEnd;
  const isTranscribing = frame >= transcribeStart && frame < transcribeEnd;
  const isDone =
    frame >= transcribeEnd && frame < typeEnd + 10;

  // Typing animation
  const charsVisible = Math.floor(
    interpolate(frame, [typeStart, typeEnd], [0, dictatedText.length], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    })
  );

  return (
    <AbsoluteFill
      className="flex flex-col items-center justify-center"
      style={{ opacity: fadeIn * fadeOut }}
    >
      {/* App label */}
      <div
        className="mb-4"
        style={{
          opacity: interpolate(frame, [0, 8], [0, 0.5], {
            extrapolateRight: "clamp",
          }),
        }}
      >
        <span
          className="text-[13px] text-[#3f3f46] uppercase tracking-[0.15em]"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}
        >
          {appLabel}
        </span>
      </div>

      {/* Mock app window */}
      <MockWindow app={app}>
        {codeContext && (
          <div className="mb-1">
            <span
              className="text-[15px] text-[#52525b]"
              style={{ fontFamily: "'JetBrains Mono', monospace" }}
            >
              <span className="text-[#7c3aed]">async function</span>{" "}
              <span className="text-[#22d3ee]">handleAuth</span>
              {"(req, res) {"}
            </span>
          </div>
        )}
        <div className="flex items-center">
          {charsVisible > 0 ? (
            <span
              className={`${
                codeContext
                  ? "text-[15px] text-[#6b7280]"
                  : "text-[16px] text-[#ececee]"
              }`}
              style={
                codeContext
                  ? { fontFamily: "'JetBrains Mono', monospace" }
                  : {}
              }
            >
              {codeContext ? "  " : ""}
              {dictatedText.slice(0, charsVisible)}
              {charsVisible < dictatedText.length && (
                <span
                  className="text-[#22d3ee] ml-[1px]"
                  style={{
                    opacity: Math.sin(frame * 0.3) > 0 ? 1 : 0,
                  }}
                >
                  |
                </span>
              )}
            </span>
          ) : (
            <span className="text-[15px] text-[#3f3f46]">
              {codeContext ? "  " : ""}
              {placeholder}
            </span>
          )}
        </div>
        {codeContext && charsVisible >= dictatedText.length && (
          <div className="mt-1">
            <span
              className="text-[15px] text-[#52525b]"
              style={{ fontFamily: "'JetBrains Mono', monospace" }}
            >
              {"}"}
            </span>
          </div>
        )}
      </MockWindow>

      {/* Fn key indicator */}
      <FnKeyVisual pressed={isFnPressed} frame={frame} pressFrame={fnPressFrame} />

      {/* Our actual floating indicator */}
      <FloatingIndicator
        isRecording={isRecording}
        isTranscribing={isTranscribing}
        isDone={isDone}
        doneText={dictatedText}
        frame={frame}
        recordStart={recordStart}
      />
    </AbsoluteFill>
  );
};

/* ── Close ───────────────────────────────────────────────────── */

const SceneClose: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const msgOpacity = interpolate(frame, [0, 15], [0, 1], {
    extrapolateRight: "clamp",
  });
  const msgY = interpolate(frame, [0, 15], [10, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  const urlOpacity = interpolate(frame, [30, 42], [0, 1], {
    extrapolateRight: "clamp",
  });
  const subOpacity = interpolate(frame, [40, 50], [0, 1], {
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill className="flex flex-col items-center justify-center">
      <div
        style={{
          opacity: msgOpacity,
          transform: `translateY(${msgY}px)`,
        }}
      >
        <span className="text-[28px] text-[#a1a1aa] leading-relaxed text-center block">
          Whisper AI. On your Mac.
          <br />
          <span className="text-[#52525b]">Nothing leaves your machine.</span>
        </span>
      </div>

      <div className="mt-12" style={{ opacity: urlOpacity }}>
        <span
          className="text-[28px] text-[#22d3ee]"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}
        >
          inputalk.com
        </span>
      </div>
      <div className="mt-2" style={{ opacity: subOpacity }}>
        <span
          className="text-[14px] text-[#3f3f46]"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}
        >
          free · open source
        </span>
      </div>
    </AbsoluteFill>
  );
};

/* ================================================================
   UI COMPONENTS — exact replicas of our actual Swift UI
   ================================================================ */

/* ── Mock macOS Window ───────────────────────────────────────── */

const MockWindow: React.FC<{
  app: "slack" | "vscode" | "notes";
  children: React.ReactNode;
}> = ({ app, children }) => {
  const colors = {
    slack: { bg: "#1a1d21", titlebar: "#1a1d21", border: "#2c2d30" },
    vscode: { bg: "#1e1e1e", titlebar: "#323233", border: "#3c3c3c" },
    notes: { bg: "#1c1c1e", titlebar: "#2c2c2e", border: "#3a3a3c" },
  };
  const c = colors[app];

  return (
    <div
      className="w-[680px] rounded-xl overflow-hidden"
      style={{
        backgroundColor: c.bg,
        border: `1px solid ${c.border}`,
        boxShadow: "0 25px 60px rgba(0,0,0,0.5)",
      }}
    >
      {/* Title bar */}
      <div
        className="flex items-center gap-2 px-4 py-2.5"
        style={{
          backgroundColor: c.titlebar,
          borderBottom: `1px solid ${c.border}`,
        }}
      >
        <div className="w-[12px] h-[12px] rounded-full bg-[#ff5f57]" />
        <div className="w-[12px] h-[12px] rounded-full bg-[#febc2e]" />
        <div className="w-[12px] h-[12px] rounded-full bg-[#28c840]" />
      </div>

      {/* Content */}
      <div className="px-5 py-4 min-h-[60px]">{children}</div>
    </div>
  );
};

/* ── Fn Key Visual ───────────────────────────────────────────── */

const FnKeyVisual: React.FC<{
  pressed: boolean;
  frame: number;
  pressFrame: number;
}> = ({ pressed, frame, pressFrame }) => {
  const { fps } = useVideoConfig();

  const opacity = interpolate(frame, [pressFrame - 4, pressFrame], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const scale = pressed
    ? spring({
        frame: Math.max(0, frame - pressFrame),
        fps,
        config: { damping: 14, stiffness: 200 },
      })
    : 1;

  return (
    <div
      className="absolute bottom-[160px] right-[260px]"
      style={{ opacity }}
    >
      <div
        className={`w-[52px] h-[52px] rounded-xl flex items-center justify-center border ${
          pressed
            ? "bg-[#22d3ee]/10 border-[#22d3ee]/30"
            : "bg-[#111113] border-[#2a2a2d]"
        }`}
        style={{ transform: `scale(${pressed ? scale * 0.96 : 1})` }}
      >
        <span
          className={`text-[16px] font-semibold ${
            pressed ? "text-[#22d3ee]" : "text-[#52525b]"
          }`}
          style={{ fontFamily: "'JetBrains Mono', monospace" }}
        >
          fn
        </span>
      </div>
    </div>
  );
};

/* ── Floating Indicator — exact replica of our Liquid Glass widget ── */

const FloatingIndicator: React.FC<{
  isRecording: boolean;
  isTranscribing: boolean;
  isDone: boolean;
  doneText: string;
  frame: number;
  recordStart: number;
}> = ({ isRecording, isTranscribing, isDone, doneText, frame, recordStart }) => {
  const visible = isRecording || isTranscribing || isDone;

  const opacity = visible
    ? interpolate(
        frame,
        [recordStart, recordStart + 6],
        [0, 1],
        { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
      )
    : 0;

  if (opacity === 0) return null;

  return (
    <div
      className="absolute bottom-[60px] left-1/2"
      style={{
        transform: "translateX(-50%)",
        opacity,
      }}
    >
      {/* Liquid Glass capsule */}
      <div
        className="flex items-center gap-3 px-5 py-3 rounded-full"
        style={{
          background: "rgba(255,255,255,0.06)",
          backdropFilter: "blur(20px)",
          border: "1px solid rgba(255,255,255,0.08)",
          boxShadow: "0 8px 32px rgba(0,0,0,0.3)",
        }}
      >
        {/* Left icon */}
        {isRecording && (
          <>
            <div
              className="w-[10px] h-[10px] rounded-full bg-red-500"
              style={{
                opacity: 0.7 + Math.sin(frame * 0.15) * 0.3,
                transform: `scale(${1 + Math.sin(frame * 0.15) * 0.15})`,
              }}
            />
            {/* 7 waveform bars — matching our Swift UI exactly */}
            <div className="flex items-end gap-[4px] h-[24px]">
              {Array.from({ length: 7 }).map((_, i) => {
                const level = 0.6 + 0.4 * Math.abs(Math.sin((frame - recordStart) * 0.12 + i * 1.2));
                const amplified = Math.min(Math.pow(level, 0.5) * 1.5, 1);
                const phase = i * 1.2 + amplified * 12;
                const wave = (Math.sin(phase) + 1) / 2;
                const jitter = i % 2 === 0 ? 2 : 0;
                const h = 5 + jitter + 19 * amplified * wave;
                return (
                  <div
                    key={i}
                    className="w-[4px] rounded-sm bg-white/90"
                    style={{ height: `${h}px` }}
                  />
                );
              })}
            </div>
            <span className="text-[14px] font-medium text-white/90 ml-1">
              Listening...
            </span>
          </>
        )}

        {isTranscribing && !isRecording && (
          <>
            {/* Spinner */}
            <div
              className="w-4 h-4 rounded-full border-2 border-white/20 border-t-white/80"
              style={{
                animation: "none",
                transform: `rotate(${frame * 12}deg)`,
              }}
            />
            <span className="text-[14px] font-medium text-white/90">
              Transcribing
            </span>
            {/* Bouncing dots */}
            <div className="flex gap-[3px]">
              {[0, 1, 2].map((i) => (
                <div
                  key={i}
                  className="w-[4px] h-[4px] rounded-full bg-white/60"
                  style={{
                    transform: `translateY(${
                      Math.sin((frame - i * 4) * 0.25) * 3
                    }px)`,
                  }}
                />
              ))}
            </div>
          </>
        )}

        {isDone && !isTranscribing && !isRecording && (
          <>
            <svg
              width="16"
              height="16"
              viewBox="0 0 16 16"
              fill="none"
              className="flex-shrink-0"
            >
              <circle cx="8" cy="8" r="8" fill="#22c55e" />
              <path
                d="M5 8.5L7 10.5L11 6"
                stroke="white"
                strokeWidth="1.5"
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            <span className="text-[14px] font-medium text-white/90 max-w-[300px] truncate">
              {doneText}
            </span>
          </>
        )}
      </div>
    </div>
  );
};

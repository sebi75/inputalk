import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  Sequence,
  spring,
  useVideoConfig,
  Easing,
  Audio,
  staticFile,
} from "remotion";

/* ================================================================
   INPUTALK LAUNCH VIDEO — 30s (900 frames @ 30fps)

   Structure:
   - 0-3.5s    Cold open (logo + tagline)
   - 3.5-12s   Use case 1: Slack (with zoom on widget)
   - 12-20s    Use case 2: VS Code (with zoom on typed text)
   - 20-26s    Use case 3: Notes (fastest, builds rhythm)
   - 26-30s    Close (message + URL)
   ================================================================ */

export const LaunchVideo: React.FC = () => {
  const frame = useCurrentFrame();

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

      {/* Background music — uncomment when audio file is available */}
      {/* <Audio src={staticFile("bg-music.mp3")} volume={0.15} /> */}

      {/* Scene 1: Cold open — 0-105 frames (0-3.5s) */}
      <Sequence from={0} durationInFrames={105}>
        <SceneColdOpen />
      </Sequence>

      {/* Scene 2: Slack — 105-360 frames (3.5-12s) */}
      <Sequence from={105} durationInFrames={255}>
        <SceneUseCase
          app="slack"
          appLabel="Slack"
          topLine="📍 #engineering"
          placeholder="Message #engineering"
          dictatedText="Hey, can we push the standup to 3pm? I'm wrapping up the auth fix."
          totalFrames={255}
          zoomTarget="widget"
        />
      </Sequence>

      {/* Scene 3: VS Code — 360-600 frames (12-20s) */}
      <Sequence from={360} durationInFrames={240}>
        <SceneUseCase
          app="vscode"
          appLabel="VS Code"
          topLine="auth-middleware.ts"
          placeholder=""
          dictatedText="// TODO: refactor to validate JWT claims before granting access"
          totalFrames={240}
          codeContext
          zoomTarget="text"
        />
      </Sequence>

      {/* Scene 4: Notes — 600-780 frames (20-26s) */}
      <Sequence from={600} durationInFrames={180}>
        <SceneUseCase
          app="notes"
          appLabel="Notes"
          topLine="Meeting notes — March 28"
          placeholder=""
          dictatedText="Follow up with design team about the new onboarding flow before Friday"
          totalFrames={180}
          zoomTarget="none"
        />
      </Sequence>

      {/* Scene 5: Close — 780-900 frames (26-30s) */}
      <Sequence from={780} durationInFrames={120}>
        <SceneClose />
      </Sequence>
    </AbsoluteFill>
  );
};

/* ── Cold Open ───────────────────────────────────────────────── */

const SceneColdOpen: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const nameOpacity = interpolate(frame, [10, 28], [0, 1], {
    extrapolateRight: "clamp",
  });
  const nameY = interpolate(frame, [10, 28], [12, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  // Waveform bars stagger in
  const waveOpacity = interpolate(frame, [20, 38], [0, 1], {
    extrapolateRight: "clamp",
  });

  const subOpacity = interpolate(frame, [35, 50], [0, 1], {
    extrapolateRight: "clamp",
  });
  const subY = interpolate(frame, [35, 50], [6, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  const fadeOut = interpolate(frame, [85, 105], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      className="flex flex-col items-center justify-center"
      style={{ opacity: fadeOut }}
    >
      {/* Waveform accent */}
      <div
        className="flex items-end gap-[5px] h-14 mb-8"
        style={{ opacity: waveOpacity }}
      >
        {[0.3, 0.55, 0.8, 1, 0.85, 0.6, 0.9, 0.7, 1, 0.5, 0.75, 0.4].map(
          (h, i) => {
            const barSpring = spring({
              frame: Math.max(0, frame - 20 - i * 2),
              fps,
              config: { damping: 10, mass: 0.6 },
            });
            return (
              <div
                key={i}
                className="w-[3px] rounded-full bg-[#22d3ee]"
                style={{
                  height: `${h * 48 * barSpring}px`,
                  opacity: 0.4 + h * 0.5,
                }}
              />
            );
          }
        )}
      </div>

      <div
        style={{
          opacity: nameOpacity,
          transform: `translateY(${nameY}px)`,
        }}
      >
        <span
          className="text-[56px] text-[#ececee] tracking-[-0.03em] font-semibold"
          style={{ fontFamily: "system-ui, -apple-system, sans-serif" }}
        >
          Inputalk
        </span>
      </div>

      <div
        className="mt-3"
        style={{
          opacity: subOpacity,
          transform: `translateY(${subY}px)`,
        }}
      >
        <span
          className="text-[20px] text-[#52525b] tracking-wide"
          style={{ fontFamily: "'JetBrains Mono', 'SF Mono', monospace" }}
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
  topLine: string;
  placeholder: string;
  dictatedText: string;
  totalFrames: number;
  codeContext?: boolean;
  zoomTarget: "widget" | "text" | "none";
}

const SceneUseCase: React.FC<UseCaseProps> = ({
  app,
  appLabel,
  topLine,
  placeholder,
  dictatedText,
  totalFrames,
  codeContext,
  zoomTarget,
}) => {
  const frame = useCurrentFrame();

  // Pacing — more breathing room
  const fadeIn = interpolate(frame, [0, 14], [0, 1], {
    extrapolateRight: "clamp",
  });
  const fadeOut = interpolate(
    frame,
    [totalFrames - 16, totalFrames],
    [1, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );

  // Timeline
  const fnPressFrame = 15;
  const recordStart = 22;
  const recordEnd = Math.floor(totalFrames * 0.35);
  const transcribeStart = recordEnd + 4;
  const transcribeEnd = recordEnd + 20;
  const typeStart = transcribeEnd + 2;
  const typeEnd = totalFrames - 24;

  const isFnPressed = frame >= fnPressFrame && frame < recordEnd + 6;
  const isRecording = frame >= recordStart && frame < recordEnd;
  const isTranscribing = frame >= transcribeStart && frame < transcribeEnd;
  const isDone = frame >= transcribeEnd && frame < typeEnd + 14;

  // Typing animation
  const charsVisible = Math.floor(
    interpolate(frame, [typeStart, typeEnd], [0, dictatedText.length], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    })
  );

  // Smooth zoom — gradually zoom into the scene during recording,
  // then zoom further toward the target on completion
  const zoomBase = interpolate(frame, [0, recordEnd], [1, 1.04], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });

  let zoomPeak = 1.04;
  let translateX = 0;
  let translateY = 0;

  if (zoomTarget === "widget" && frame > transcribeStart) {
    // Zoom toward bottom center (where widget is)
    zoomPeak = interpolate(
      frame,
      [transcribeStart, transcribeEnd + 20],
      [1.04, 1.18],
      { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) }
    );
    translateY = interpolate(
      frame,
      [transcribeStart, transcribeEnd + 20],
      [0, -80],
      { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) }
    );
    // Ease back out
    if (frame > typeStart + 30) {
      zoomPeak = interpolate(
        frame,
        [typeStart + 30, typeEnd],
        [1.18, 1.02],
        { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) }
      );
      translateY = interpolate(
        frame,
        [typeStart + 30, typeEnd],
        [-80, 0],
        { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) }
      );
    }
  }

  if (zoomTarget === "text" && frame > typeStart) {
    // Zoom toward the text area
    zoomPeak = interpolate(
      frame,
      [typeStart, typeStart + 40],
      [1.04, 1.14],
      { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) }
    );
    translateY = interpolate(
      frame,
      [typeStart, typeStart + 40],
      [0, 20],
      { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) }
    );
    if (frame > typeEnd - 20) {
      zoomPeak = interpolate(
        frame,
        [typeEnd - 20, typeEnd + 10],
        [1.14, 1.02],
        { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.inOut(Easing.cubic) }
      );
    }
  }

  const zoom = frame > transcribeStart ? zoomPeak : zoomBase;

  return (
    <AbsoluteFill
      className="flex flex-col items-center justify-center"
      style={{
        opacity: fadeIn * fadeOut,
        transform: `scale(${zoom}) translate(${translateX}px, ${translateY}px)`,
      }}
    >
      {/* App label */}
      <div
        className="mb-5"
        style={{
          opacity: interpolate(frame, [0, 12], [0, 0.6], {
            extrapolateRight: "clamp",
          }),
        }}
      >
        <span
          className="text-[13px] text-[#3f3f46] uppercase tracking-[0.18em]"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}
        >
          {appLabel}
        </span>
      </div>

      {/* Mock app window */}
      <MockWindow app={app} topLine={topLine}>
        {codeContext && (
          <>
            <div className="mb-1 opacity-40">
              <span
                className="text-[15px] text-[#52525b]"
                style={{ fontFamily: "'JetBrains Mono', monospace" }}
              >
                <span className="text-[#c084fc]">export async function</span>{" "}
                <span className="text-[#67e8f9]">validateSession</span>
                {"(req: Request) {"}
              </span>
            </div>
            <div className="mb-1 opacity-30">
              <span
                className="text-[15px] text-[#52525b]"
                style={{ fontFamily: "'JetBrains Mono', monospace" }}
              >
                {"  const token = req.headers.authorization;"}
              </span>
            </div>
          </>
        )}
        <div className="flex items-center min-h-[28px]">
          {charsVisible > 0 ? (
            <span
              className={`${
                codeContext
                  ? "text-[15px] text-[#6a9955]"
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
        {codeContext && (
          <div className="mt-1 opacity-30">
            <span
              className="text-[15px] text-[#52525b]"
              style={{ fontFamily: "'JetBrains Mono', monospace" }}
            >
              {"}"}
            </span>
          </div>
        )}
      </MockWindow>

      {/* Fn key */}
      <FnKeyVisual
        pressed={isFnPressed}
        frame={frame}
        pressFrame={fnPressFrame}
      />

      {/* Floating indicator */}
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

  const line1Opacity = interpolate(frame, [0, 18], [0, 1], {
    extrapolateRight: "clamp",
  });
  const line1Y = interpolate(frame, [0, 18], [14, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });
  const line2Opacity = interpolate(frame, [12, 28], [0, 1], {
    extrapolateRight: "clamp",
  });
  const line2Y = interpolate(frame, [12, 28], [10, 0], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  const urlOpacity = interpolate(frame, [45, 60], [0, 1], {
    extrapolateRight: "clamp",
  });
  const urlScale = spring({
    frame: Math.max(0, frame - 45),
    fps,
    config: { damping: 12, mass: 0.8 },
  });
  const subOpacity = interpolate(frame, [58, 72], [0, 1], {
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill className="flex flex-col items-center justify-center">
      <div
        style={{
          opacity: line1Opacity,
          transform: `translateY(${line1Y}px)`,
        }}
      >
        <span className="text-[32px] text-[#ececee] font-medium">
          Whisper AI. On your Mac.
        </span>
      </div>
      <div
        className="mt-1"
        style={{
          opacity: line2Opacity,
          transform: `translateY(${line2Y}px)`,
        }}
      >
        <span className="text-[32px] text-[#52525b]">
          Nothing leaves your machine.
        </span>
      </div>

      <div
        className="mt-14"
        style={{
          opacity: urlOpacity,
          transform: `scale(${urlScale})`,
        }}
      >
        <span
          className="text-[32px] text-[#22d3ee]"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}
        >
          inputalk.com
        </span>
      </div>
      <div className="mt-3" style={{ opacity: subOpacity }}>
        <span
          className="text-[15px] text-[#3f3f46] tracking-wide"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}
        >
          free &middot; open source
        </span>
      </div>
    </AbsoluteFill>
  );
};

/* ================================================================
   UI COMPONENTS — faithful replicas of our Swift UI
   ================================================================ */

/* ── Mock macOS Window ───────────────────────────────────────── */

const MockWindow: React.FC<{
  app: "slack" | "vscode" | "notes";
  topLine: string;
  children: React.ReactNode;
}> = ({ app, topLine, children }) => {
  const colors = {
    slack: { bg: "#1a1d21", titlebar: "#1a1d21", border: "#2c2d30" },
    vscode: { bg: "#1e1e1e", titlebar: "#323233", border: "#3c3c3c" },
    notes: { bg: "#1c1c1e", titlebar: "#2c2c2e", border: "#3a3a3c" },
  };
  const c = colors[app];

  return (
    <div
      className="w-[720px] rounded-xl overflow-hidden"
      style={{
        backgroundColor: c.bg,
        border: `1px solid ${c.border}`,
        boxShadow: "0 30px 80px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.03)",
      }}
    >
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
        <span
          className="ml-3 text-[12px] text-[#52525b]"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}
        >
          {topLine}
        </span>
      </div>
      <div className="px-5 py-4 min-h-[70px]">{children}</div>
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

  const opacity = interpolate(frame, [pressFrame - 6, pressFrame + 2], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const fadeOut = !pressed
    ? interpolate(frame, [pressFrame + 60, pressFrame + 72], [1, 0.3], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    : 1;

  const pressScale = pressed
    ? spring({
        frame: Math.max(0, frame - pressFrame),
        fps,
        config: { damping: 14, stiffness: 200 },
      })
    : 1;

  return (
    <div
      className="absolute bottom-[170px] right-[220px]"
      style={{ opacity: opacity * fadeOut }}
    >
      <div
        className={`w-[56px] h-[56px] rounded-xl flex items-center justify-center border-[1.5px] transition-all ${
          pressed
            ? "bg-[#22d3ee]/8 border-[#22d3ee]/25"
            : "bg-[#111113] border-[#252528]"
        }`}
        style={{
          transform: `scale(${pressed ? pressScale * 0.95 : 1})`,
          boxShadow: pressed
            ? "0 0 20px rgba(34,211,238,0.08), inset 0 1px 0 rgba(255,255,255,0.04)"
            : "inset 0 1px 0 rgba(255,255,255,0.04), 0 2px 4px rgba(0,0,0,0.3)",
        }}
      >
        <span
          className={`text-[15px] font-semibold ${
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

/* ── Floating Indicator — replica of our Liquid Glass widget ── */

const FloatingIndicator: React.FC<{
  isRecording: boolean;
  isTranscribing: boolean;
  isDone: boolean;
  doneText: string;
  frame: number;
  recordStart: number;
}> = ({
  isRecording,
  isTranscribing,
  isDone,
  doneText,
  frame,
  recordStart,
}) => {
  const visible = isRecording || isTranscribing || isDone;

  const slideUp = interpolate(
    frame,
    [recordStart, recordStart + 10],
    [20, 0],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.out(Easing.cubic) }
  );
  const opacity = visible
    ? interpolate(frame, [recordStart, recordStart + 8], [0, 1], {
        extrapolateLeft: "clamp",
        extrapolateRight: "clamp",
      })
    : 0;

  if (opacity === 0) return null;

  return (
    <div
      className="absolute bottom-[56px] left-1/2"
      style={{
        transform: `translateX(-50%) translateY(${slideUp}px)`,
        opacity,
      }}
    >
      <div
        className="flex items-center gap-3 rounded-full"
        style={{
          padding: "12px 20px",
          background:
            "linear-gradient(135deg, rgba(255,255,255,0.07) 0%, rgba(255,255,255,0.03) 100%)",
          backdropFilter: "blur(24px) saturate(1.2)",
          border: "1px solid rgba(255,255,255,0.09)",
          boxShadow:
            "0 12px 40px rgba(0,0,0,0.35), inset 0 1px 0 rgba(255,255,255,0.06)",
        }}
      >
        {isRecording && (
          <>
            <div
              className="w-[10px] h-[10px] rounded-full bg-red-500 flex-shrink-0"
              style={{
                opacity: 0.7 + Math.sin(frame * 0.15) * 0.3,
                transform: `scale(${1 + Math.sin(frame * 0.15) * 0.15})`,
              }}
            />
            <div className="flex items-end gap-[4px] h-[24px]">
              {Array.from({ length: 7 }).map((_, i) => {
                const t = (frame - recordStart) * 0.12 + i * 1.2;
                const level =
                  0.5 + 0.5 * Math.abs(Math.sin(t));
                const amplified = Math.min(
                  Math.pow(level, 0.5) * 1.5,
                  1
                );
                const phase = i * 1.2 + amplified * 12;
                const wave = (Math.sin(phase) + 1) / 2;
                const jitter = i % 2 === 0 ? 2 : 0;
                const h = 5 + jitter + 19 * amplified * wave;
                return (
                  <div
                    key={i}
                    className="w-[4px] rounded-sm"
                    style={{
                      height: `${h}px`,
                      backgroundColor: "rgba(255,255,255,0.85)",
                    }}
                  />
                );
              })}
            </div>
            <span className="text-[14px] font-medium text-white/85 ml-1 whitespace-nowrap">
              Listening...
            </span>
          </>
        )}

        {isTranscribing && !isRecording && (
          <>
            <div
              className="w-4 h-4 rounded-full border-2 border-white/20 border-t-white/70 flex-shrink-0"
              style={{ transform: `rotate(${frame * 12}deg)` }}
            />
            <span className="text-[14px] font-medium text-white/85">
              Transcribing
            </span>
            <div className="flex gap-[3px]">
              {[0, 1, 2].map((i) => (
                <div
                  key={i}
                  className="w-[4px] h-[4px] rounded-full bg-white/50"
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
            <span className="text-[14px] font-medium text-white/85 max-w-[320px] truncate">
              {doneText}
            </span>
          </>
        )}
      </div>
    </div>
  );
};

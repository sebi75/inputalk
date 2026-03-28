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

   Audio:
   - bg-music-v2.mp3    Dark atmospheric ambient
   - voice-slack.mp3    "Hey, can we push..." (3.8s)
   - voice-vscode.mp3   "TODO: refactor..." (5.5s)
   - voice-notes.mp3    "Follow up with..." (4.2s)
   - ping.mp3           Recording start
   - done.mp3           Transcription complete
   - whoosh.mp3         Scene transitions
   - typing.mp3         Text appearing
   ================================================================ */

export const LaunchVideo: React.FC = () => {
  return (
    <AbsoluteFill className="bg-[#08080a]">
      {/* Dot grid */}
      <AbsoluteFill
        style={{
          backgroundImage:
            "radial-gradient(circle, #1a1a1e 1px, transparent 1px)",
          backgroundSize: "24px 24px",
          opacity: 0.4,
        }}
      />

      {/* ── Audio bed ── */}
      <Audio src={staticFile("bg-music-v2.mp3")} volume={0.14} />

      {/* Scene transitions whooshes */}
      <Sequence from={100}><Audio src={staticFile("whoosh.mp3")} volume={0.2} /></Sequence>
      <Sequence from={365}><Audio src={staticFile("whoosh.mp3")} volume={0.18} /></Sequence>
      <Sequence from={600}><Audio src={staticFile("whoosh.mp3")} volume={0.18} /></Sequence>
      <Sequence from={770}><Audio src={staticFile("whoosh.mp3")} volume={0.2} /></Sequence>

      {/* ── Scene 1: Slack (105-370) ── */}
      {/* Recording ping */}
      <Sequence from={120}><Audio src={staticFile("ping.mp3")} volume={0.35} /></Sequence>
      {/* Voice plays during listening — starts when recording indicator appears */}
      <Sequence from={130}><Audio src={staticFile("voice-slack.mp3")} volume={0.8} /></Sequence>
      {/* Done chime + typing sound */}
      <Sequence from={266}><Audio src={staticFile("done.mp3")} volume={0.25} /></Sequence>
      <Sequence from={282}><Audio src={staticFile("typing.mp3")} volume={0.2} /></Sequence>

      {/* ── Scene 2: VS Code (370-610) ── */}
      <Sequence from={385}><Audio src={staticFile("ping.mp3")} volume={0.3} /></Sequence>
      <Sequence from={395}><Audio src={staticFile("voice-vscode.mp3")} volume={0.75} /></Sequence>
      <Sequence from={508}><Audio src={staticFile("done.mp3")} volume={0.22} /></Sequence>
      <Sequence from={524}><Audio src={staticFile("typing.mp3")} volume={0.18} /></Sequence>

      {/* ── Scene 3: Notes (610-780) ── */}
      <Sequence from={625}><Audio src={staticFile("ping.mp3")} volume={0.3} /></Sequence>
      <Sequence from={635}><Audio src={staticFile("voice-notes.mp3")} volume={0.75} /></Sequence>
      <Sequence from={730}><Audio src={staticFile("done.mp3")} volume={0.22} /></Sequence>
      <Sequence from={742}><Audio src={staticFile("typing.mp3")} volume={0.18} /></Sequence>

      {/* ── Visual scenes ── */}

      <Sequence from={0} durationInFrames={105}>
        <SceneColdOpen />
      </Sequence>

      <Sequence from={105} durationInFrames={260}>
        <SceneUseCase
          app="slack"
          appLabel="Slack"
          topLine="📍 #engineering"
          placeholder="Message #engineering"
          dictatedText="Hey, can we push the standup to 3pm? I'm wrapping up the auth fix."
          totalFrames={260}
          voiceDurationFrames={114}
          caption="message a teammate"
        />
      </Sequence>

      <Sequence from={370} durationInFrames={235}>
        <SceneUseCase
          app="vscode"
          appLabel="VS Code"
          topLine="auth-middleware.ts"
          placeholder=""
          dictatedText="// TODO: refactor to validate JWT claims before granting access"
          totalFrames={235}
          codeContext
          voiceDurationFrames={166}
          caption="add a code comment"
        />
      </Sequence>

      <Sequence from={610} durationInFrames={170}>
        <SceneUseCase
          app="notes"
          appLabel="Notes"
          topLine="Meeting notes — March 28"
          placeholder=""
          dictatedText="Follow up with design team about the new onboarding flow before Friday"
          totalFrames={170}
          voiceDurationFrames={125}
          caption="jot down a reminder"
        />
      </Sequence>

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
      <div style={{ opacity: nameOpacity, transform: `translateY(${nameY}px)` }}>
        <span className="text-[56px] text-[#ececee] tracking-[-0.03em] font-semibold"
          style={{ fontFamily: "system-ui, -apple-system, sans-serif" }}>
          Inputalk
        </span>
      </div>
      <div className="mt-3" style={{ opacity: subOpacity, transform: `translateY(${subY}px)` }}>
        <span className="text-[20px] text-[#52525b] tracking-wide"
          style={{ fontFamily: "'JetBrains Mono', 'SF Mono', monospace" }}>
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
  voiceDurationFrames: number;
  codeContext?: boolean;
  caption: string;
}

const SceneUseCase: React.FC<UseCaseProps> = ({
  app,
  appLabel,
  topLine,
  placeholder,
  dictatedText,
  totalFrames,
  voiceDurationFrames,
  codeContext,
  caption,
}) => {
  const frame = useCurrentFrame();

  const fadeIn = interpolate(frame, [0, 14], [0, 1], { extrapolateRight: "clamp" });
  const fadeOut = interpolate(frame, [totalFrames - 16, totalFrames], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Timeline — synced to voice duration
  const fnPressFrame = 12;
  const recordStart = 18;
  const recordEnd = Math.min(recordStart + voiceDurationFrames + 6, totalFrames - 50);
  const transcribeStart = recordEnd + 3;
  const transcribeEnd = Math.min(recordEnd + 14, totalFrames - 32);
  const typeStart = transcribeEnd + 2;
  const typeEnd = Math.max(typeStart + 1, Math.min(typeStart + 28, totalFrames - 18));

  const isFnPressed = frame >= fnPressFrame && frame < recordEnd + 4;
  const isRecording = frame >= recordStart && frame < recordEnd;
  const isTranscribing = frame >= transcribeStart && frame < transcribeEnd;
  const isDone = frame >= transcribeEnd && frame < totalFrames - 12;

  const charsVisible = Math.floor(
    interpolate(frame, [typeStart, typeEnd], [0, dictatedText.length], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    })
  );

  // Voice-reactive waveform: simulate amplitude from voice timing
  // Peaks in the middle of the voice, tapers at start/end
  const voiceProgress = interpolate(
    frame,
    [recordStart + 5, recordStart + voiceDurationFrames],
    [0, 1],
    { extrapolateLeft: "clamp", extrapolateRight: "clamp" }
  );
  const voiceAmplitude =
    frame >= recordStart + 5 && frame < recordStart + voiceDurationFrames
      ? 0.4 + 0.6 * Math.sin(voiceProgress * Math.PI) // bell curve
      : 0.1;

  // Zoom toward widget during listening, ease back for typing
  const zoomPhase = recordStart + 35;
  const zoomBackStart = Math.max(transcribeEnd + 1, zoomPhase + 1);
  const zoomBackEnd = zoomBackStart + 30;

  let zoom = 1;
  let panY = 0;

  if (frame >= recordStart && frame < zoomPhase) {
    const t = (frame - recordStart) / (zoomPhase - recordStart);
    const eased = t * t * (3 - 2 * t); // smoothstep
    zoom = 1 + 0.25 * eased;
    panY = -120 * eased;
  } else if (frame >= zoomPhase && frame < zoomBackStart) {
    zoom = 1.25;
    panY = -120;
  } else if (frame >= zoomBackStart && frame < zoomBackEnd) {
    const t = (frame - zoomBackStart) / (zoomBackEnd - zoomBackStart);
    const eased = t * t * (3 - 2 * t);
    zoom = 1.25 - 0.23 * eased;
    panY = -120 + 120 * eased;
  } else if (frame >= zoomBackEnd) {
    zoom = 1.02;
    panY = 0;
  }

  // Caption fade
  const captionOpacity = interpolate(frame, [2, 12, 40, 50], [0, 0.7, 0.7, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      className="flex flex-col items-center justify-center"
      style={{
        opacity: fadeIn * fadeOut,
        transform: `scale(${zoom}) translateY(${panY}px)`,
      }}
    >
      {/* Presenting caption */}
      <div
        className="absolute top-[140px] left-1/2"
        style={{
          transform: "translateX(-50%)",
          opacity: captionOpacity,
        }}
      >
        <span
          className="text-[15px] text-[#52525b] italic"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}
        >
          {caption}
        </span>
      </div>

      {/* App label */}
      <div
        className="mb-5"
        style={{
          opacity: interpolate(frame, [0, 10], [0, 0.5], { extrapolateRight: "clamp" }),
        }}
      >
        <span
          className="text-[13px] text-[#3f3f46] uppercase tracking-[0.18em]"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}
        >
          {appLabel}
        </span>
      </div>

      {/* Mock window */}
      <MockWindow app={app} topLine={topLine}>
        {codeContext && (
          <>
            <div className="mb-1 opacity-40">
              <span className="text-[15px] text-[#52525b]"
                style={{ fontFamily: "'JetBrains Mono', monospace" }}>
                <span className="text-[#c084fc]">export async function</span>{" "}
                <span className="text-[#67e8f9]">validateSession</span>{"(req: Request) {"}
              </span>
            </div>
            <div className="mb-1 opacity-30">
              <span className="text-[15px] text-[#52525b]"
                style={{ fontFamily: "'JetBrains Mono', monospace" }}>
                {"  const token = req.headers.authorization;"}
              </span>
            </div>
          </>
        )}
        <div className="flex items-center min-h-[28px]">
          {charsVisible > 0 ? (
            <span
              className={codeContext ? "text-[15px] text-[#6a9955]" : "text-[16px] text-[#ececee]"}
              style={codeContext ? { fontFamily: "'JetBrains Mono', monospace" } : {}}>
              {codeContext ? "  " : ""}
              {dictatedText.slice(0, charsVisible)}
              {charsVisible < dictatedText.length && (
                <span className="text-[#22d3ee] ml-[1px]"
                  style={{ opacity: Math.sin(frame * 0.3) > 0 ? 1 : 0 }}>|</span>
              )}
            </span>
          ) : (
            <span className="text-[15px] text-[#3f3f46]">
              {codeContext ? "  " : ""}{placeholder}
            </span>
          )}
        </div>
        {codeContext && (
          <div className="mt-1 opacity-30">
            <span className="text-[15px] text-[#52525b]"
              style={{ fontFamily: "'JetBrains Mono', monospace" }}>{"}"}</span>
          </div>
        )}
      </MockWindow>

      {/* Fn key */}
      <FnKeyVisual pressed={isFnPressed} frame={frame} pressFrame={fnPressFrame} />

      {/* Floating indicator with voice-reactive waveform */}
      <FloatingIndicator
        isRecording={isRecording}
        isTranscribing={isTranscribing}
        isDone={isDone}
        doneText={dictatedText}
        frame={frame}
        recordStart={recordStart}
        voiceAmplitude={voiceAmplitude}
      />
    </AbsoluteFill>
  );
};

/* ── Close with CTA ──────────────────────────────────────────── */

const SceneClose: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const line1Opacity = interpolate(frame, [0, 18], [0, 1], { extrapolateRight: "clamp" });
  const line1Y = interpolate(frame, [0, 18], [14, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const line2Opacity = interpolate(frame, [12, 28], [0, 1], { extrapolateRight: "clamp" });
  const line2Y = interpolate(frame, [12, 28], [10, 0], {
    extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });

  const ctaOpacity = interpolate(frame, [40, 55], [0, 1], { extrapolateRight: "clamp" });
  const ctaScale = spring({ frame: Math.max(0, frame - 40), fps, config: { damping: 12, mass: 0.8 } });

  const subOpacity = interpolate(frame, [55, 68], [0, 1], { extrapolateRight: "clamp" });
  const badgesOpacity = interpolate(frame, [65, 78], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill className="flex flex-col items-center justify-center">
      <div style={{ opacity: line1Opacity, transform: `translateY(${line1Y}px)` }}>
        <span className="text-[32px] text-[#ececee] font-medium">
          Whisper AI. On your Mac.
        </span>
      </div>
      <div className="mt-1" style={{ opacity: line2Opacity, transform: `translateY(${line2Y}px)` }}>
        <span className="text-[32px] text-[#52525b]">
          Nothing leaves your machine.
        </span>
      </div>

      {/* CTA button */}
      <div className="mt-12" style={{ opacity: ctaOpacity, transform: `scale(${ctaScale})` }}>
        <div className="flex items-center gap-2.5 px-7 py-3.5 rounded-xl bg-[#ececee]">
          <svg className="w-5 h-5 text-[#08080a]" viewBox="0 0 24 24" fill="currentColor">
            <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
          </svg>
          <span className="text-[16px] font-semibold text-[#08080a]">
            Download for Mac — free
          </span>
        </div>
      </div>

      <div className="mt-4" style={{ opacity: subOpacity }}>
        <span className="text-[28px] text-[#22d3ee]"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}>
          inputalk.com
        </span>
      </div>

      {/* Badges */}
      <div className="flex items-center gap-3 mt-6" style={{ opacity: badgesOpacity }}>
        {["Open source", "macOS 15+", "Apple Silicon & Intel"].map((label) => (
          <div key={label} className="px-3 py-1.5 rounded-md border border-[#1c1c1f] bg-[#111113]">
            <span className="text-[12px] text-[#52525b]"
              style={{ fontFamily: "'JetBrains Mono', monospace" }}>{label}</span>
          </div>
        ))}
      </div>
    </AbsoluteFill>
  );
};

/* ================================================================
   UI COMPONENTS
   ================================================================ */

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
    <div className="w-[720px] rounded-xl overflow-hidden"
      style={{
        backgroundColor: c.bg,
        border: `1px solid ${c.border}`,
        boxShadow: "0 30px 80px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.03)",
      }}>
      <div className="flex items-center gap-2 px-4 py-2.5"
        style={{ backgroundColor: c.titlebar, borderBottom: `1px solid ${c.border}` }}>
        <div className="w-[12px] h-[12px] rounded-full bg-[#ff5f57]" />
        <div className="w-[12px] h-[12px] rounded-full bg-[#febc2e]" />
        <div className="w-[12px] h-[12px] rounded-full bg-[#28c840]" />
        <span className="ml-3 text-[12px] text-[#52525b]"
          style={{ fontFamily: "'JetBrains Mono', monospace" }}>{topLine}</span>
      </div>
      <div className="px-5 py-4 min-h-[70px]">{children}</div>
    </div>
  );
};

const FnKeyVisual: React.FC<{
  pressed: boolean; frame: number; pressFrame: number;
}> = ({ pressed, frame, pressFrame }) => {
  const { fps } = useVideoConfig();
  const opacity = interpolate(frame, [pressFrame - 6, pressFrame + 2], [0, 1], {
    extrapolateLeft: "clamp", extrapolateRight: "clamp",
  });
  const fadeOut = !pressed
    ? interpolate(frame, [pressFrame + 80, pressFrame + 95], [1, 0], {
        extrapolateLeft: "clamp", extrapolateRight: "clamp",
      })
    : 1;
  const pressScale = pressed
    ? spring({ frame: Math.max(0, frame - pressFrame), fps, config: { damping: 14, stiffness: 200 } })
    : 1;
  return (
    <div className="absolute bottom-[170px] right-[220px]" style={{ opacity: opacity * fadeOut }}>
      <div className={`w-[56px] h-[56px] rounded-xl flex items-center justify-center border-[1.5px] ${
        pressed ? "bg-[#22d3ee]/8 border-[#22d3ee]/25" : "bg-[#111113] border-[#252528]"
      }`} style={{
        transform: `scale(${pressed ? pressScale * 0.95 : 1})`,
        boxShadow: pressed
          ? "0 0 24px rgba(34,211,238,0.1), inset 0 1px 0 rgba(255,255,255,0.04)"
          : "inset 0 1px 0 rgba(255,255,255,0.04), 0 2px 4px rgba(0,0,0,0.3)",
      }}>
        <span className={`text-[15px] font-semibold ${pressed ? "text-[#22d3ee]" : "text-[#52525b]"}`}
          style={{ fontFamily: "'JetBrains Mono', monospace" }}>fn</span>
      </div>
    </div>
  );
};

/* ── Floating Indicator — voice-reactive waveform ──────────── */

const FloatingIndicator: React.FC<{
  isRecording: boolean;
  isTranscribing: boolean;
  isDone: boolean;
  doneText: string;
  frame: number;
  recordStart: number;
  voiceAmplitude: number;
}> = ({ isRecording, isTranscribing, isDone, doneText, frame, recordStart, voiceAmplitude }) => {
  const visible = isRecording || isTranscribing || isDone;
  const slideUp = interpolate(frame, [recordStart, recordStart + 10], [20, 0], {
    extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: Easing.out(Easing.cubic),
  });
  const opacity = visible
    ? interpolate(frame, [recordStart, recordStart + 8], [0, 1], {
        extrapolateLeft: "clamp", extrapolateRight: "clamp",
      })
    : 0;
  if (opacity === 0) return null;

  return (
    <div className="absolute bottom-[56px] left-1/2"
      style={{ transform: `translateX(-50%) translateY(${slideUp}px)`, opacity }}>
      <div className="flex items-center gap-3 rounded-full"
        style={{
          padding: "12px 20px",
          background: "linear-gradient(135deg, rgba(255,255,255,0.07) 0%, rgba(255,255,255,0.03) 100%)",
          backdropFilter: "blur(24px) saturate(1.2)",
          border: "1px solid rgba(255,255,255,0.09)",
          boxShadow: "0 12px 40px rgba(0,0,0,0.35), inset 0 1px 0 rgba(255,255,255,0.06)",
        }}>

        {isRecording && (
          <>
            <div className="w-[10px] h-[10px] rounded-full bg-red-500 flex-shrink-0"
              style={{
                opacity: 0.7 + Math.sin(frame * 0.15) * 0.3,
                transform: `scale(${1 + Math.sin(frame * 0.15) * 0.15})`,
              }} />
            {/* 7 waveform bars — reactive to voice amplitude */}
            <div className="flex items-end gap-[4px] h-[24px]">
              {Array.from({ length: 7 }).map((_, i) => {
                // Mix voice amplitude with per-bar variation
                const t = frame * 0.18 + i * 1.4;
                const barVariation = 0.3 + 0.7 * Math.abs(Math.sin(t));
                const level = voiceAmplitude * barVariation;
                const amplified = Math.min(Math.pow(level, 0.45) * 1.6, 1);
                const phase = i * 1.2 + amplified * 14;
                const wave = (Math.sin(phase) + 1) / 2;
                const jitter = i % 2 === 0 ? 2 : 0;
                const h = 4 + jitter + 20 * amplified * wave;
                return (
                  <div key={i} className="w-[4px] rounded-sm"
                    style={{ height: `${h}px`, backgroundColor: "rgba(255,255,255,0.85)" }} />
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
            <div className="w-4 h-4 rounded-full border-2 border-white/20 border-t-white/70 flex-shrink-0"
              style={{ transform: `rotate(${frame * 12}deg)` }} />
            <span className="text-[14px] font-medium text-white/85">Transcribing</span>
            <div className="flex gap-[3px]">
              {[0, 1, 2].map((i) => (
                <div key={i} className="w-[4px] h-[4px] rounded-full bg-white/50"
                  style={{ transform: `translateY(${Math.sin((frame - i * 4) * 0.25) * 3}px)` }} />
              ))}
            </div>
          </>
        )}

        {isDone && !isTranscribing && !isRecording && (
          <>
            <svg width="16" height="16" viewBox="0 0 16 16" fill="none" className="flex-shrink-0">
              <circle cx="8" cy="8" r="8" fill="#22c55e" />
              <path d="M5 8.5L7 10.5L11 6" stroke="white" strokeWidth="1.5"
                strokeLinecap="round" strokeLinejoin="round" />
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

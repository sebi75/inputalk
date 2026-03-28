import {
  AbsoluteFill,
  interpolate,
  useCurrentFrame,
  Sequence,
  spring,
  useVideoConfig,
} from "remotion";

export const LaunchVideo: React.FC = () => {
  return (
    <AbsoluteFill className="bg-[#08080a]">
      {/* Subtle dot grid */}
      <AbsoluteFill
        style={{
          backgroundImage: "radial-gradient(circle, #1c1c1f 1px, transparent 1px)",
          backgroundSize: "32px 32px",
          opacity: 0.5,
        }}
      />

      {/* Scene 1: Logo + waveform intro (0-90 frames = 0-3s) */}
      <Sequence from={0} durationInFrames={90}>
        <SceneIntro />
      </Sequence>

      {/* Scene 2: "Hold Fn" demo (90-210 = 3-7s) */}
      <Sequence from={90} durationInFrames={120}>
        <SceneHoldFn />
      </Sequence>

      {/* Scene 3: Transcription flow (210-330 = 7-11s) */}
      <Sequence from={210} durationInFrames={120}>
        <SceneTranscribe />
      </Sequence>

      {/* Scene 4: Tagline + CTA (330-450 = 11-15s) */}
      <Sequence from={330} durationInFrames={120}>
        <SceneTagline />
      </Sequence>
    </AbsoluteFill>
  );
};

/* ── Scene 1: Intro ─────────────────────────────────────────── */

const SceneIntro: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const logoScale = spring({ frame, fps, config: { damping: 12, mass: 0.8 } });
  const logoOpacity = interpolate(frame, [0, 20], [0, 1], { extrapolateRight: "clamp" });
  const subtitleOpacity = interpolate(frame, [25, 45], [0, 1], { extrapolateRight: "clamp" });
  const subtitleY = interpolate(frame, [25, 45], [12, 0], { extrapolateRight: "clamp" });

  // Fade out at end
  const fadeOut = interpolate(frame, [70, 90], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill
      className="flex flex-col items-center justify-center"
      style={{ opacity: fadeOut }}
    >
      {/* Waveform */}
      <div className="flex items-end gap-[4px] h-12 mb-8" style={{ opacity: logoOpacity }}>
        {[0.3, 0.6, 0.9, 1, 0.8, 0.5, 0.7, 1, 0.4, 0.65].map((h, i) => {
          const barAnim = spring({
            frame: frame - i * 2,
            fps,
            config: { damping: 8, mass: 0.5 },
          });
          return (
            <div
              key={i}
              className="w-[3px] rounded-full bg-[#22d3ee]"
              style={{
                height: `${h * 40 * barAnim}px`,
                opacity: 0.5 + h * 0.5,
              }}
            />
          );
        })}
      </div>

      {/* Logo text */}
      <div
        style={{
          opacity: logoOpacity,
          transform: `scale(${logoScale})`,
        }}
      >
        <span
          className="text-[72px] font-bold tracking-[-0.04em] text-[#ececee]"
          style={{ fontFamily: "system-ui" }}
        >
          Inputalk
        </span>
      </div>

      {/* Subtitle */}
      <div
        style={{
          opacity: subtitleOpacity,
          transform: `translateY(${subtitleY}px)`,
        }}
      >
        <span
          className="text-[22px] text-[#71717a] tracking-wide"
          style={{ fontFamily: "monospace" }}
        >
          local voice-to-text for macOS
        </span>
      </div>
    </AbsoluteFill>
  );
};

/* ── Scene 2: Hold Fn ───────────────────────────────────────── */

const SceneHoldFn: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const fadeIn = interpolate(frame, [0, 15], [0, 1], { extrapolateRight: "clamp" });
  const fadeOut = interpolate(frame, [100, 120], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  // Fn key press animation
  const keyPress = frame > 25 && frame < 85;
  const keyScale = keyPress
    ? spring({ frame: frame - 25, fps, config: { damping: 15, stiffness: 300 } })
    : 1;
  const keyDepth = keyPress ? 0.95 : 1;

  // Waveform appears when "recording"
  const waveOpacity = interpolate(frame, [30, 40], [0, 1], { extrapolateRight: "clamp" });
  const waveOut = interpolate(frame, [80, 90], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  // "Listening..." text
  const listenOpacity = interpolate(frame, [35, 45], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill
      className="flex flex-col items-center justify-center"
      style={{ opacity: fadeIn * fadeOut }}
    >
      {/* Fn Key */}
      <div
        className="mb-10"
        style={{ transform: `scale(${keyScale * keyDepth})` }}
      >
        <div
          className={`w-24 h-24 rounded-2xl border-2 flex items-center justify-center transition-colors ${
            keyPress
              ? "bg-[#22d3ee]/10 border-[#22d3ee]/40"
              : "bg-[#111113] border-[#1c1c1f]"
          }`}
        >
          <span
            className={`text-3xl font-bold ${
              keyPress ? "text-[#22d3ee]" : "text-[#71717a]"
            }`}
            style={{ fontFamily: "monospace" }}
          >
            fn
          </span>
        </div>
      </div>

      {/* Recording indicator */}
      <div
        className="flex items-center gap-4 mb-6"
        style={{ opacity: waveOpacity * waveOut }}
      >
        {/* Pulsing red dot */}
        <div
          className="w-3 h-3 rounded-full bg-red-500"
          style={{
            opacity: Math.sin(frame * 0.15) * 0.3 + 0.7,
            transform: `scale(${1 + Math.sin(frame * 0.15) * 0.15})`,
          }}
        />

        {/* Waveform bars */}
        <div className="flex items-end gap-[3px] h-8">
          {Array.from({ length: 12 }).map((_, i) => {
            const barH =
              0.3 +
              0.7 *
                Math.abs(
                  Math.sin((frame - 30) * 0.12 + i * 0.8)
                );
            return (
              <div
                key={i}
                className="w-[3px] rounded-full bg-[#22d3ee]"
                style={{
                  height: `${barH * 28}px`,
                  opacity: 0.5 + barH * 0.5,
                }}
              />
            );
          })}
        </div>
      </div>

      <div style={{ opacity: listenOpacity * waveOut }}>
        <span className="text-[20px] text-[#71717a]" style={{ fontFamily: "monospace" }}>
          listening...
        </span>
      </div>

      {/* Label */}
      <div
        className="absolute bottom-32"
        style={{ opacity: fadeIn }}
      >
        <span className="text-[18px] text-[#3f3f46]" style={{ fontFamily: "monospace" }}>
          hold fn to record
        </span>
      </div>
    </AbsoluteFill>
  );
};

/* ── Scene 3: Transcription ─────────────────────────────────── */

const SceneTranscribe: React.FC = () => {
  const frame = useCurrentFrame();

  const fadeIn = interpolate(frame, [0, 15], [0, 1], { extrapolateRight: "clamp" });
  const fadeOut = interpolate(frame, [100, 120], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  // Simulated text typing
  const fullText = "Let's schedule the meeting for Thursday at 3pm.";
  const charsVisible = Math.min(
    Math.floor(interpolate(frame, [20, 80], [0, fullText.length], { extrapolateRight: "clamp" })),
    fullText.length
  );
  const displayText = fullText.slice(0, charsVisible);

  // Cursor blink
  const cursorVisible = Math.sin(frame * 0.3) > 0;

  // Processing → done transition
  const processingOpacity = interpolate(frame, [0, 10, 15, 20], [0, 1, 1, 0], {
    extrapolateRight: "clamp",
  });
  const textOpacity = interpolate(frame, [18, 25], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill
      className="flex flex-col items-center justify-center"
      style={{ opacity: fadeIn * fadeOut }}
    >
      {/* Mock text editor */}
      <div className="w-[700px] rounded-xl border border-[#1c1c1f] bg-[#111113] overflow-hidden">
        {/* Title bar */}
        <div className="flex items-center gap-2 px-4 py-3 border-b border-[#1c1c1f]">
          <div className="w-3 h-3 rounded-full bg-[#ff5f57]" />
          <div className="w-3 h-3 rounded-full bg-[#febc2e]" />
          <div className="w-3 h-3 rounded-full bg-[#28c840]" />
          <span className="ml-3 text-[13px] text-[#3f3f46]" style={{ fontFamily: "monospace" }}>
            Notes.txt
          </span>
        </div>

        {/* Content */}
        <div className="px-6 py-5 min-h-[120px]">
          {/* Processing indicator */}
          <div style={{ opacity: processingOpacity }} className="flex items-center gap-2 mb-2">
            <span className="text-[14px] text-[#71717a]" style={{ fontFamily: "monospace" }}>
              transcribing...
            </span>
          </div>

          {/* Typed text */}
          <div style={{ opacity: textOpacity }}>
            <span className="text-[20px] text-[#ececee] leading-relaxed">
              {displayText}
            </span>
            {cursorVisible && charsVisible < fullText.length && (
              <span className="text-[20px] text-[#22d3ee]">|</span>
            )}
          </div>
        </div>
      </div>

      {/* Label */}
      <div className="mt-8" style={{ opacity: textOpacity }}>
        <span className="text-[18px] text-[#3f3f46]" style={{ fontFamily: "monospace" }}>
          text appears at your cursor
        </span>
      </div>
    </AbsoluteFill>
  );
};

/* ── Scene 4: Tagline ───────────────────────────────────────── */

const SceneTagline: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleScale = spring({ frame, fps, config: { damping: 12 } });
  const titleOpacity = interpolate(frame, [0, 20], [0, 1], { extrapolateRight: "clamp" });

  const subtitleOpacity = interpolate(frame, [20, 40], [0, 1], { extrapolateRight: "clamp" });
  const subtitleY = interpolate(frame, [20, 40], [10, 0], { extrapolateRight: "clamp" });

  const detailsOpacity = interpolate(frame, [45, 60], [0, 1], { extrapolateRight: "clamp" });

  const urlOpacity = interpolate(frame, [65, 80], [0, 1], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill className="flex flex-col items-center justify-center">
      <div
        style={{
          opacity: titleOpacity,
          transform: `scale(${titleScale})`,
        }}
      >
        <span
          className="text-[64px] font-bold tracking-[-0.04em] text-[#ececee]"
          style={{ fontFamily: "system-ui" }}
        >
          Inputalk
        </span>
      </div>

      <div
        className="mt-3"
        style={{
          opacity: subtitleOpacity,
          transform: `translateY(${subtitleY}px)`,
        }}
      >
        <span className="text-[24px] text-[#71717a]">
          Voice to text, on your Mac
        </span>
      </div>

      {/* Feature pills */}
      <div
        className="flex items-center gap-3 mt-10"
        style={{ opacity: detailsOpacity }}
      >
        {["On-device AI", "Open source", "Free"].map((label) => (
          <div
            key={label}
            className="px-4 py-2 rounded-lg border border-[#1c1c1f] bg-[#111113]"
          >
            <span className="text-[15px] text-[#a1a1aa]">{label}</span>
          </div>
        ))}
      </div>

      {/* URL */}
      <div className="mt-12" style={{ opacity: urlOpacity }}>
        <span
          className="text-[20px] text-[#22d3ee]"
          style={{ fontFamily: "monospace" }}
        >
          inputalk.com
        </span>
      </div>
    </AbsoluteFill>
  );
};

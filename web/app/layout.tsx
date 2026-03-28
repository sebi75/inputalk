import type { Metadata } from "next";
import { Syne, DM_Sans, JetBrains_Mono } from "next/font/google";
import "./globals.css";

const syne = Syne({
  subsets: ["latin"],
  variable: "--font-syne",
  display: "swap",
});

const dmSans = DM_Sans({
  subsets: ["latin"],
  variable: "--font-dm",
  display: "swap",
});

const jetbrains = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-mono",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Inputalk — local voice-to-text for macOS",
  description:
    "Hold Fn, speak, release. Text appears at your cursor. Whisper AI runs on your Mac. Open source, no cloud, no API keys.",
  openGraph: {
    title: "Inputalk — local voice-to-text for macOS",
    description:
      "Hold Fn, speak, release. Text appears at your cursor. Whisper AI runs on your Mac.",
    url: "https://inputalk.com",
    siteName: "Inputalk",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Inputalk — local voice-to-text for macOS",
    description:
      "Hold Fn, speak, release. Text appears at your cursor. Whisper AI runs on your Mac.",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html
      lang="en"
      className={`${syne.variable} ${dmSans.variable} ${jetbrains.variable}`}
    >
      <body className="bg-[#08080a] text-[#a1a1aa] antialiased font-[family-name:var(--font-dm)]">
        {children}
      </body>
    </html>
  );
}

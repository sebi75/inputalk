import type { Metadata } from "next";
import { Syne, DM_Sans, JetBrains_Mono } from "next/font/google";
import { Analytics } from "@vercel/analytics/react";
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
  title: "Inputalk — free dictation for macOS",
  description:
    "Dictate into any app on your Mac. Hold Fn, speak, release — text appears at your cursor. On-device transcription, no cloud, completely free.",
  openGraph: {
    title: "Inputalk — free dictation for macOS",
    description:
      "Dictate into any app on your Mac. Hold Fn, speak, release — text appears at your cursor. On-device, free, open source.",
    url: "https://inputalk.com",
    siteName: "Inputalk",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Inputalk — free dictation for macOS",
    description:
      "Dictate into any app on your Mac. Hold Fn, speak, release — text appears at your cursor. On-device, free, open source.",
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
        <Analytics />
      </body>
    </html>
  );
}

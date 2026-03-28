import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
});

export const metadata: Metadata = {
  title: "Inputalk - Free Voice-to-Text for macOS",
  description:
    "Dictate anywhere on your Mac. Hold Fn to talk, release to paste. Powered by local AI — completely free, no API keys, total privacy.",
  openGraph: {
    title: "Inputalk - Free Voice-to-Text for macOS",
    description:
      "Dictate anywhere on your Mac. Hold Fn to talk, release to paste. Powered by local AI.",
    url: "https://inputalk.com",
    siteName: "Inputalk",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Inputalk - Free Voice-to-Text for macOS",
    description:
      "Dictate anywhere on your Mac. Hold Fn to talk, release to paste. Powered by local AI.",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className={inter.variable}>
      <body className="bg-[#0a0a0b] text-white antialiased">{children}</body>
    </html>
  );
}

import { NextResponse } from "next/server";

const S3_BASE = "https://inputalk.s3.us-east-1.amazonaws.com";
const LATEST_URL = `${S3_BASE}/releases/latest.json`;

export async function GET() {
  try {
    const res = await fetch(LATEST_URL, { next: { revalidate: 60 } });
    if (!res.ok) throw new Error("Failed to fetch latest.json");

    const data = await res.json();
    const dmgUrl = data.dmg?.url;
    if (!dmgUrl) throw new Error("No DMG URL");

    // Each invocation = one download. Visible in Vercel Functions log.
    console.log(`[download] v${data.version}`);

    return NextResponse.redirect(dmgUrl, 302);
  } catch {
    return NextResponse.redirect("https://inputalk.com", 302);
  }
}

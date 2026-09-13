import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "ECLIPSE LAB — ECLIPSEBOUND Observability & Build Simulator",
  description: "Web experimentation lab, build simulator, boss adaptation inspector, and RL telemetry engine for ECLIPSEBOUND.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body className="bg-eclipse-950 text-slate-100 min-h-screen antialiased selection:bg-purple-600 selection:text-white">
        {children}
      </body>
    </html>
  );
}

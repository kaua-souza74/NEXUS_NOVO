import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "NEXUS",
  description: "NEXUS hotel IoT platform",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="pt-BR"><body>{children}</body></html>;
}

'use client';

import { Providers } from '@/components/Providers';
import './globals.css';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="bg-black">
      <body className="bg-black text-white">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}

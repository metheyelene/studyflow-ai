import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Pin the project root. Without this, Turbopack can resolve the root
  // to a parent directory that contains a stray package-lock.json
  // (the user's home dir has one), serving the wrong files.
  turbopack: {
    root: process.cwd(),
  },
};

export default nextConfig;

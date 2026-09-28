import { createClient } from "@supabase/supabase-js";

/** Server-only client for trusted ingestion work. Never import from client code. */
export function createAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const secretKey = process.env.SUPABASE_SECRET_KEY;

  if (!url) throw new Error("NEXT_PUBLIC_SUPABASE_URL is not configured");
  if (!secretKey?.startsWith("sb_secret_")) {
    throw new Error("SUPABASE_SECRET_KEY must be a modern sb_secret_ key");
  }

  return createClient(url, secretKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
}

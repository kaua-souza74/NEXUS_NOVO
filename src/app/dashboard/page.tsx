import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { logout } from "./actions";

export default async function DashboardPage() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login");

  return (
    <main>
      <h1>NEXUS TEST DASHBOARD</h1>
      <p>Authenticated: YES</p>
      <p>Email: {user.email}</p>
      <p>User ID: {user.id}</p>
      <form action={logout}><button type="submit">LOGOUT</button></form>
    </main>
  );
}

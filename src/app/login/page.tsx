import { login } from "./actions";

const messages: Record<string, string> = {
  missing: "Informe email e senha.",
  invalid: "Email ou senha inválidos.",
};

export default async function LoginPage({ searchParams }: { searchParams: Promise<{ error?: string }> }) {
  const { error } = await searchParams;
  return (
    <main>
      <h1>NEXUS</h1>
      <form action={login}>
        <label htmlFor="email">Email</label><br />
        <input id="email" name="email" type="email" autoComplete="email" required /><br />
        <label htmlFor="password">Password</label><br />
        <input id="password" name="password" type="password" autoComplete="current-password" required /><br />
        <button type="submit">LOGIN</button>
      </form>
      {error && <p role="alert">{messages[error] ?? "Não foi possível entrar. Tente novamente."}</p>}
    </main>
  );
}

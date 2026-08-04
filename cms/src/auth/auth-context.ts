import { createContext, useContext } from "react";
import type { User } from "firebase/auth";

export type AuthState = {
  user: User | null;
  /** True only when the `admin` custom claim is present on the ID token. */
  isAdmin: boolean;
  /** Still resolving the session. Render nothing rather than flashing login. */
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signOut: () => Promise<void>;
};

export const AuthContext = createContext<AuthState | null>(null);

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside <AuthProvider>");
  return ctx;
}

// Separate from AuthProvider.tsx on purpose: React Fast Refresh only works on a
// module that exports components exclusively, so shipping the hook and the
// context alongside the provider would silently break hot reload for it.

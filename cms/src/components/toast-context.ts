import { createContext, useContext } from "react";
import type { AlertVariant } from "./Alert";

export type ToastInput = {
  variant: AlertVariant;
  title: string;
  description?: string;
  /** One follow-up, such as Undo. Pressing it also dismisses the toast. */
  action?: { label: string; onClick: () => void };
};

export type ToastApi = {
  toast: (t: ToastInput) => void;
  success: (title: string, description?: string) => void;
  error: (title: string, description?: string) => void;
};

export const ToastContext = createContext<ToastApi | null>(null);

export function useToast(): ToastApi {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error("useToast must be used inside <ToastProvider>");
  return ctx;
}

// Separate from Toast.tsx for the same reason as auth-context: React Fast
// Refresh only works on a module that exports components exclusively, so
// shipping the hook beside the provider would silently break hot reload.

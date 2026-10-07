import { useEffect, useState, type RefObject } from "react";

/**
 * Whether an element is on screen, below the sticky top bar.
 *
 * `ready` exists because the element may not be mounted yet: the editor
 * renders "Loading…" first, so an observer attached on the first pass would
 * find nothing and never look again.
 */
export function useInView(
  ref: RefObject<Element | null>,
  ready = true,
): boolean {
  const [inView, setInView] = useState(true);
  useEffect(() => {
    const el = ref.current;
    if (!ready || !el) return;
    const observer = new IntersectionObserver(
      ([entry]) => setInView(entry.isIntersecting),
      // The top bar is 56px and sticky; something under it is not visible.
      { rootMargin: "-56px 0px 0px 0px" },
    );
    observer.observe(el);
    return () => observer.disconnect();
  }, [ref, ready]);
  return inView;
}

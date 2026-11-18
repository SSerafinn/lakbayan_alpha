// The landing page's small motions. Without this script the page is complete
// and still: every section is visible and the welcome shows its first words.
(() => {
  const root = document.documentElement;
  root.classList.add("js");
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;

  // The header earns its hairline once the page has scrolled under it.
  const top = document.querySelector("[data-top]");
  const onScroll = () => top.classList.toggle("is-scrolled", scrollY > 8);
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // Sections rise in once, as they arrive.
  const reveal = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        entry.target.classList.add("is-in");
        reveal.unobserve(entry.target);
      }
    },
    { rootMargin: "0px 0px -12% 0px" },
  );
  document.querySelectorAll(".reveal").forEach((el) => reveal.observe(el));

  // Runs `tick` every `ms` only while `el` is on screen.
  const whileVisible = (el, ms, tick) => {
    let timer = 0;
    new IntersectionObserver(([entry]) => {
      clearInterval(timer);
      if (entry.isIntersecting) {
        tick();
        timer = setInterval(tick, ms);
      }
    }).observe(el);
  };

  // The hero's heart: saved, then not, as someone deciding.
  const heart = document.querySelector("[data-heart]");
  if (still) heart.classList.add("is-saved");
  else whileVisible(heart, 2600, () => heart.classList.toggle("is-saved"));

  // The scan screen: the corners lock on, the exhibit's card rises, again.
  const box = document.querySelector("[data-scan]");
  const sheet = document.querySelector("[data-scan-sheet]");
  if (still) {
    box.classList.add("is-locked");
    sheet.classList.add("is-up");
  } else {
    whileVisible(box, 5200, () => {
      box.classList.remove("is-locked");
      sheet.classList.remove("is-up");
      setTimeout(() => box.classList.add("is-locked"), 1400);
      setTimeout(() => sheet.classList.add("is-up"), 2000);
    });
  }

  // The welcome types itself out in each of the app's three greetings, the
  // ground changing with each, as the app's own landing does.
  const greetings = [
    {
      word: "MADDULO KAMU",
      wash: "var(--sky)",
      body: "The welcome that met every traveller at the old provincial arch. Rivers, mountains and coast, and the stories that come with them.",
    },
    {
      word: "YENA TAM NGAMIN",
      wash: "var(--mint)",
      body: "Mother of us all. At Piat, the pilgrimage centre of the valley, faith and heritage have always shared the same road.",
    },
    {
      word: "TULOY PO KAYO",
      wash: "var(--butter)",
      body: "Come in. Download a town before you set out and the province travels with you, signal or none.",
    },
  ];
  const band = document.querySelector("[data-greeting]");
  const word = document.querySelector("[data-greeting-word]");
  const body = document.querySelector("[data-greeting-body]");
  if (!still) {
    let index = 0;
    let running = false;
    let timer = 0;
    const caret = '<span class="caret" aria-hidden="true"></span>';
    const show = (g) => {
      band.style.backgroundColor = g.wash;
      body.textContent = g.body;
      let n = 0;
      const type = () => {
        word.innerHTML = g.word.slice(0, n) + caret;
        if (n++ < g.word.length) {
          timer = setTimeout(type, 75);
        } else {
          timer = setTimeout(() => {
            index = (index + 1) % greetings.length;
            if (running) show(greetings[index]);
          }, 2600);
        }
      };
      type();
    };
    new IntersectionObserver(([entry]) => {
      clearTimeout(timer);
      running = entry.isIntersecting;
      if (running) show(greetings[index]);
    }).observe(band);
  }
})();

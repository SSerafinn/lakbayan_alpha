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

  // The hero's deck plays through the province, as Explore's featured deck
  // does: the front card flicks away and slides in at the back, which loads
  // the next place while it is hidden. A swipe or a tap moves it on too.
  // With reduced motion it waits for a swipe or tap.
  const deck = document.querySelector("[data-deck]");
  const places = [
    ["palaui-island", "Palaui Island", "Santa Ana"],
    ["basilica-minore-de-piat", "Basilica Minore de Piat", "Piat"],
    ["callao-cave", "Callao Cave", "Peñablanca"],
    ["buntun-bridge", "Buntun Bridge", "Tuguegarao City"],
    ["cagayan-museum", "Cagayan Museum", "Tuguegarao City"],
    ["pinacanauan-river", "Pinacanauan River", "Peñablanca"],
  ];
  const roles = ["deck-front", "deck-back-1", "deck-back-2"];
  // In the markup the front shows place 0, the cards behind it places 1 and 2.
  const cards = roles.map((role) => deck.querySelector(`.${role}`));
  const overlay = [...cards[0].querySelectorAll(".deck-top, .deck-foot")];
  const [title, town] = cards[0].querySelectorAll(".deck-foot > *");
  let shown = 0; // the place on the front card
  let busy = false;

  const advance = () => {
    if (busy) return;
    busy = true;
    const [leaving, next, last] = cards;
    leaving.classList.add("is-leaving");
    setTimeout(() => {
      leaving.classList.remove("is-leaving", "deck-front");
      leaving.classList.add("deck-back-2");
      next.classList.replace("deck-back-1", "deck-front");
      last.classList.replace("deck-back-2", "deck-back-1");
      next.append(...overlay);
      shown = (shown + 1) % places.length;
      title.textContent = places[shown][1];
      town.textContent = places[shown][2];
      heart.classList.remove("is-saved");
      // The card now at the back shows the place two after the front.
      const [file] = places[(shown + 2) % places.length];
      leaving.querySelector("img").src = `images/${file}.jpg`;
      cards.push(cards.shift());
      busy = false;
    }, still ? 0 : 380);
  };

  let paused = false;
  deck.closest(".hero-art").addEventListener("pointerenter", (e) => {
    if (e.pointerType === "mouse") paused = true;
  });
  deck.closest(".hero-art").addEventListener("pointerleave", () => {
    paused = false;
  });
  let playTimer = 0;
  let deckOnScreen = false;
  const restart = () => {
    clearInterval(playTimer);
    if (!still && deckOnScreen) {
      playTimer = setInterval(() => paused || advance(), 3600);
    }
  };
  new IntersectionObserver(([entry]) => {
    deckOnScreen = entry.isIntersecting;
    restart();
  }).observe(deck);

  // A swipe either way, or a tap, moves the deck on. Vertical drags stay
  // with the page (touch-action: pan-y).
  let startX = null;
  deck.addEventListener("pointerdown", (e) => {
    startX = e.clientX;
  });
  deck.addEventListener("pointerup", (e) => {
    if (startX === null) return;
    const dx = Math.abs(e.clientX - startX);
    startX = null;
    if (dx > 40 || dx < 8) {
      advance();
      restart();
    }
  });
  deck.addEventListener("pointercancel", () => {
    startX = null;
  });

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

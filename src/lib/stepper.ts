// The driver behind the stepped diagrams. Every diagram is the same machine:
// a list of stages that light up in order, a caption per stage, transport
// controls, and a dash animation on any wire marked `.trace`. Only the drawing
// and the prose differ, so that machine lives here and not in each component.

export type Step = readonly [label: string, caption: string];

interface Options {
  /** Milliseconds a stage holds before the next one arrives. */
  autoplayMs?: number;
  /** How much of the figure must be on screen before it starts itself. */
  threshold?: number;
  /** Called after every stage change, for state a stage class cannot carry. */
  onRender?: (root: HTMLElement, at: number) => void;
}

export function mountStepper(selector: string, steps: Step[], opts: Options = {}) {
  const { autoplayMs = 2600, threshold = 0.35, onRender } = opts;

  for (const root of document.querySelectorAll<HTMLElement>(selector)) {
    const stages = [...root.querySelectorAll<SVGGElement>('.stage')];
    const tabs = [...root.querySelectorAll<HTMLButtonElement>('[data-step]')];
    const playBtn = root.querySelector<HTMLButtonElement>('[data-play]');
    const bar = root.querySelector<HTMLElement>('[data-progress]');
    const label = root.querySelector<HTMLElement>('[data-caption-label]');
    const text = root.querySelector<HTMLElement>('[data-caption-text]');
    const reduced = matchMedia('(prefers-reduced-motion: reduce)');

    // Measure each traced path so the dash animation matches its real length.
    for (const p of root.querySelectorAll<SVGPathElement>('.wire.trace')) {
      const len = Math.ceil(p.getTotalLength());
      p.style.setProperty('--len', String(len));
      p.style.strokeDasharray = String(len);
    }

    let at = -1;
    let timer: number | undefined;

    const render = (n: number) => {
      at = Math.max(0, Math.min(steps.length - 1, n));
      stages.forEach((s, i) => {
        s.classList.toggle('is-on', i <= at);
        s.classList.toggle('is-active', i === at);
      });
      tabs.forEach((t, i) => t.setAttribute('aria-selected', String(i === at)));
      if (bar) bar.style.width = `${((at + 1) / steps.length) * 100}%`;
      if (label) label.textContent = `${steps[at][0]}.`;
      if (text) text.textContent = steps[at][1];
      onRender?.(root, at);
    };

    const stop = () => {
      if (timer) clearInterval(timer);
      timer = undefined;
      root.classList.remove('is-playing');
    };

    const play = () => {
      if (reduced.matches) return;
      stop();
      root.classList.add('is-playing');
      timer = window.setInterval(() => {
        if (at >= steps.length - 1) {
          stop();
          return;
        }
        render(at + 1);
      }, autoplayMs);
    };

    // Any manual interaction cancels playback rather than fighting it.
    const goto = (n: number) => {
      stop();
      render(n);
    };

    tabs.forEach((t, i) => t.addEventListener('click', () => goto(i)));

    playBtn?.addEventListener('click', () => {
      if (timer) return stop();
      if (at >= steps.length - 1) render(0);
      play();
    });

    root.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowRight') { goto(at + 1); e.preventDefault(); }
      if (e.key === 'ArrowLeft') { goto(at - 1); e.preventDefault(); }
    });

    render(0);

    // Start once, when it is actually on screen.
    if (!reduced.matches && 'IntersectionObserver' in window) {
      const io = new IntersectionObserver(
        (entries) => {
          for (const e of entries) {
            if (!e.isIntersecting) continue;
            io.disconnect();
            play();
          }
        },
        { threshold },
      );
      io.observe(root);
    }
  }
}

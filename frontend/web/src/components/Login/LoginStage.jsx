import { useEffect, useRef } from 'react';

// Animated isometric scene for the left side of the login page (pure SVG + CSS, themeable).
const iso = (cx, cy, w, depth) => ({
  top: `${cx},${cy - w / 2} ${cx + w},${cy} ${cx},${cy + w / 2} ${cx - w},${cy}`,
  left: `${cx - w},${cy} ${cx},${cy + w / 2} ${cx},${cy + w / 2 + depth} ${cx - w},${cy + depth}`,
  right: `${cx + w},${cy} ${cx},${cy + w / 2} ${cx},${cy + w / 2 + depth} ${cx + w},${cy + depth}`,
});
const LAYERS = [iso(340, 478, 262, 30), iso(340, 442, 200, 26), iso(340, 410, 138, 22)];

const GITHUB_PATH =
  'M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8z';

const Jira = () => (<g className="ls-icon"><path d="M0 -34 34 0 0 34 -34 0z" fill="none" strokeWidth="5" strokeLinejoin="round" /><path d="M0 -16 16 0 0 16 -16 0z" fill="currentColor" stroke="none" /></g>);
const Github = () => (<g className="ls-icon ls-icon--text" transform="translate(-30 -30) scale(3.75)"><path d={GITHUB_PATH} fill="currentColor" stroke="none" /></g>);
const Graph = () => (
  <g className="ls-icon" strokeWidth="3" strokeLinecap="round">
    <path d="M-22 14 -4 -14M-4 -14 20 -6M-4 -14 4 22M-22 14 4 22M20 -6 4 22" fill="none" opacity=".8" />
    {[[-22, 14], [-4, -14], [20, -6], [4, 22]].map(([x, y]) => (<circle key={`${x}${y}`} cx={x} cy={y} r="7" fill="currentColor" stroke="none" />))}
  </g>
);
const Notes = () => (
  <g className="ls-icon" strokeWidth="3.4" strokeLinecap="round">
    <rect x="-28" y="-30" width="56" height="60" rx="9" fill="none" />
    <path d="M-14 -12H14M-14 0H14M-14 12H4" fill="none" />
  </g>
);

const CARDS = [
  { id: 'jira', x: 340, y: 232, w: 150, h: 196, skew: 0, float: 'a', depth: 1.2, Icon: Jira },
  { id: 'github', x: 160, y: 328, w: 118, h: 150, skew: 0.5, float: 'b', depth: 1.6, Icon: Github },
  { id: 'graph', x: 524, y: 236, w: 112, h: 138, skew: -0.5, float: 'c', depth: 1.5, Icon: Graph },
  { id: 'notes', x: 512, y: 410, w: 112, h: 132, skew: -0.5, float: 'd', depth: 1.8, Icon: Notes },
];

const BEAMS = [
  'M340 332 V 396',
  'M160 404 Q 170 436 296 424',
  'M520 342 Q 520 410 392 420',
  'M508 478 Q 480 462 400 440',
];

const TRACES = [
  'M70 500 H 22', 'M96 540 L 40 566', 'M118 574 H 60 L 36 596', 'M610 500 H 660', 'M584 540 L 640 566', 'M562 574 H 620 L 644 596',
];

const PARTICLES = [[92, 124], [152, 74], [262, 58], [420, 92], [566, 132], [616, 224], [604, 338], [58, 262], [40, 404], [628, 486], [300, 36], [484, 40], [214, 150], [452, 170]];

export default function LoginStage() {
  const ref = useRef(null);

  // Gentle parallax that follows the pointer (skipped when the user prefers reduced motion).
  useEffect(() => {
    const el = ref.current;
    const host = el?.closest('.login');
    if (!el || !host || window.matchMedia('(prefers-reduced-motion: reduce)').matches) return undefined;
    let frame = 0;
    const onMove = (event) => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const r = host.getBoundingClientRect();
        el.style.setProperty('--px', ((event.clientX - r.left) / r.width - 0.5).toFixed(3));
        el.style.setProperty('--py', ((event.clientY - r.top) / r.height - 0.5).toFixed(3));
      });
    };
    host.addEventListener('pointermove', onMove);
    return () => {
      cancelAnimationFrame(frame);
      host.removeEventListener('pointermove', onMove);
    };
  }, []);

  return (
    <div className="ls" ref={ref} aria-hidden="true">
      <svg viewBox="0 0 680 640" role="presentation">
        <defs>
          <linearGradient id="ls-edge" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" style={{ stopColor: 'var(--st-accent)' }} />
            <stop offset="1" style={{ stopColor: 'var(--st-accent-2)' }} />
          </linearGradient>
          <linearGradient id="ls-card-fill" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0" style={{ stopColor: 'var(--st-accent)', stopOpacity: 0.3 }} />
            <stop offset="1" style={{ stopColor: 'var(--st-accent-2)', stopOpacity: 0.08 }} />
          </linearGradient>
          <linearGradient id="ls-top-fill" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" style={{ stopColor: 'var(--st-accent)', stopOpacity: 0.5 }} />
            <stop offset="1" style={{ stopColor: 'var(--st-accent-2)', stopOpacity: 0.16 }} />
          </linearGradient>
          <radialGradient id="ls-ground" cx=".5" cy=".5" r=".5">
            <stop offset="0" style={{ stopColor: 'var(--st-accent)', stopOpacity: 0.5 }} />
            <stop offset="1" style={{ stopColor: 'var(--st-accent)', stopOpacity: 0 }} />
          </radialGradient>
        </defs>

        <g className="ls-par ls-par--far">
          <ellipse className="ls-ground" cx="340" cy="520" rx="330" ry="96" fill="url(#ls-ground)" />
          {TRACES.map((d) => (<path key={d} className="ls-trace" d={d} />))}
          {PARTICLES.map(([x, y], i) => (
            <circle key={`${x}${y}`} className="ls-particle" cx={x} cy={y} r={i % 3 === 0 ? 2.6 : 1.6} style={{ '--d': `${(i * 0.37).toFixed(2)}s` }} />
          ))}
        </g>

        <g className="ls-par ls-par--mid">
          {LAYERS.map((p, i) => (
            <g key={i} className={`ls-layer ls-layer--${i}`}>
              <polygon className="ls-side" points={p.left} />
              <polygon className="ls-side ls-side--r" points={p.right} />
              <polygon className="ls-top" points={p.top} fill={i === 2 ? 'url(#ls-top-fill)' : undefined} />
            </g>
          ))}
        </g>

        <g className="ls-par ls-par--near">
          {BEAMS.map((d) => (<path key={d} className="ls-beam" d={d} />))}
          {CARDS.map(({ id, x, y, w, h, skew, float, Icon }) => (
            <g key={id} className={`ls-float ls-float--${float}`}>
              <g transform={`translate(${x} ${y}) matrix(1 ${skew} 0 1 0 0)`}>
                <rect className="ls-card" x={-w / 2} y={-h / 2} width={w} height={h} rx="16" />
                <rect className="ls-card-shine" x={-w / 2} y={-h / 2} width={w} height={h} rx="16" />
                <Icon />
              </g>
            </g>
          ))}
        </g>
      </svg>
    </div>
  );
}

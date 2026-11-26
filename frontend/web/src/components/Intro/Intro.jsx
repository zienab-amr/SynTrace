import { useEffect, useRef } from 'react';
import { SYNTRACE_LOGO } from './logos.js';
import { mountIntroEngine } from './engine.js';
import {
  BackgroundCanvas,
  FloatingElements,
  IntroOverlays,
  Navigation,
  ScrollTrack,
  StorySections,
  ToolWindows,
} from './IntroParts.jsx';
import './intro.css';

export default function Intro({ onLogin }) {
  const rootRef = useRef(null);

  useEffect(() => {
    const root = rootRef.current;
    if (!root) return undefined;

    root.querySelectorAll('.slogo').forEach((image) => {
      image.src = SYNTRACE_LOGO;
    });
    root.querySelectorAll('.slogo2').forEach((image) => {
      image.setAttribute('href', SYNTRACE_LOGO);
    });

    return mountIntroEngine(root);
  }, []);

  function handleIntroClick(event) {
    const target = event.target instanceof Element ? event.target.closest('#gs, #en') : null;
    if (target) {
      event.preventDefault();
      onLogin?.();
    }
  }

  return (
    <main
      ref={rootRef}
      id="intro-root"
      className="intro-shell"
      aria-label="SynTrace introduction"
      onClick={handleIntroClick}
    >
      <ScrollTrack />
      <BackgroundCanvas />
      <Navigation />
      <ToolWindows />
      <StorySections />
      <FloatingElements />
      <IntroOverlays />
    </main>
  );
}

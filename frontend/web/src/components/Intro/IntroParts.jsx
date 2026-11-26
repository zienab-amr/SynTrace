import parse from 'html-react-parser';
import markup from './intro-markup.html?raw';

const fragments = Object.fromEntries(
  [...markup.matchAll(/<template data-fragment="([^"]+)">([\s\S]*?)<\/template>/g)]
    .map(([, name, html]) => [name, html]),
);

const renderFragment = (name) => parse(fragments[name] || '');

function Fragment({ name }) {
  return renderFragment(name);
}

export function ScrollTrack() {
  return <Fragment name="scrollTrack" />;
}

export function BackgroundCanvas() {
  return (
    <>
      <Fragment name="background" />
      <Fragment name="canvas" />
      <Fragment name="svgDefs" />
    </>
  );
}

export function Navigation() {
  return <Fragment name="navigation" />;
}

export function ToolWindows() {
  return (
    <>
      <Fragment name="jiraWindow" />
      <Fragment name="githubWindow" />
      <Fragment name="notesWindow" />
      <Fragment name="graphWindow" />
    </>
  );
}

export function StorySections() {
  return (
    <>
      <Fragment name="titleOverview" />
      <Fragment name="titleJira" />
      <Fragment name="titleGithub" />
      <Fragment name="titleNotes" />
      <Fragment name="titleGraph" />
      <Fragment name="titleAnswer" />
    </>
  );
}

export function FloatingElements() {
  return (
    <>
      <Fragment name="cube" />
      <Fragment name="orb" />
    </>
  );
}

export function IntroOverlays() {
  return (
    <>
      <Fragment name="tooltip" />
      <Fragment name="hud" />
      <Fragment name="grain" />
    </>
  );
}

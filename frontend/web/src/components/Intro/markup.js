import parse from 'html-react-parser';
import markup from './intro-markup.html?raw';

const fragments = Object.fromEntries(
  [...markup.matchAll(/<template data-fragment="([^"]+)">([\s\S]*?)<\/template>/g)]
    .map(([, name, html]) => [name, html]),
);
export const renderFragment = (name) => parse(fragments[name] || '');

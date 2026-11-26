import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './index.css';
import { themeController } from './theme/themeController.js';

// Apply the saved/system theme before the first render (theme-init.js already did it before paint).
themeController.init();

createRoot(document.getElementById('root')).render(
  <React.StrictMode><App /></React.StrictMode>,
);

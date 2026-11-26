import { useSyncExternalStore } from 'react';
import { themeController } from './themeController.js';

export function useTheme() {
  const theme = useSyncExternalStore(
    (onChange) => themeController.subscribe(onChange),
    () => themeController.resolved,
  );
  return { theme, toggle: () => themeController.toggle(), set: (mode) => themeController.set(mode) };
}

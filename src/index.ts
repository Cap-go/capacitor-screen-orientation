import { registerPlugin } from '@capacitor/core';

import type { CapacitorScreenOrientationPlugin } from './definitions';

const ScreenOrientation = registerPlugin<CapacitorScreenOrientationPlugin>('CapacitorScreenOrientation', {
  web: () => import('./web').then((m) => new m.CapacitorScreenOrientationWeb()),
});

export * from './definitions';
export { ScreenOrientation };

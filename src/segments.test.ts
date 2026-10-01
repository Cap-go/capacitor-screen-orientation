import { describe, expect, it } from 'vitest';

import type { FoldState } from './definitions';
import { splitViewport } from './segments';
import { readWebFoldState } from './web-fold';

describe('splitViewport', () => {
  it('returns one segment when there is no separating fold', () => {
    const segments = splitViewport(null, 400, 800);
    expect(segments).toEqual([{ x: 0, y: 0, width: 400, height: 800 }]);
  });

  it('splits on a vertical hinge', () => {
    const fold: FoldState = {
      state: 'half-opened',
      isSeparating: true,
      posture: 'book',
      hingeOrientation: 'vertical',
      hingeBounds: { x: 200, y: 0, width: 24, height: 800 },
    };
    const segments = splitViewport(fold, 424, 800);
    expect(segments).toEqual([
      { x: 0, y: 0, width: 200, height: 800 },
      { x: 224, y: 0, width: 200, height: 800 },
    ]);
  });

  it('splits on a horizontal hinge', () => {
    const fold: FoldState = {
      state: 'half-opened',
      isSeparating: true,
      posture: 'tabletop',
      hingeOrientation: 'horizontal',
      hingeBounds: { x: 0, y: 300, width: 800, height: 20 },
    };
    const segments = splitViewport(fold, 800, 640);
    expect(segments).toEqual([
      { x: 0, y: 0, width: 800, height: 300 },
      { x: 0, y: 320, width: 800, height: 320 },
    ]);
  });
});

describe('readWebFoldState', () => {
  it('returns flat when no fold APIs are present', () => {
    expect(readWebFoldState(400, 800)).toEqual({
      state: 'flat',
      isSeparating: false,
      posture: 'flat',
    });
  });
});

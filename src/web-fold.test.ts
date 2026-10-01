import { afterEach, describe, expect, it } from 'vitest';

import { readWebFoldState, webDeviceFoldable } from './web-fold';

describe('webDeviceFoldable', () => {
  afterEach(() => {
    Reflect.deleteProperty(window, 'viewport');
    Reflect.deleteProperty(navigator, 'devicePosture');
  });

  it('is false when only APIs exist without fold evidence', () => {
    Object.defineProperty(navigator, 'devicePosture', {
      configurable: true,
      value: { type: 'continuous', addEventListener: () => undefined },
    });
    Object.defineProperty(window, 'viewport', {
      configurable: true,
      value: { segments: [new DOMRect(0, 0, 400, 800)] },
    });
    expect(webDeviceFoldable()).toEqual({ foldable: false, supportsTabletop: false });
  });

  it('is true when viewport splits into two segments', () => {
    Object.defineProperty(navigator, 'devicePosture', {
      configurable: true,
      value: { type: 'folded', addEventListener: () => undefined },
    });
    Object.defineProperty(window, 'viewport', {
      configurable: true,
      value: {
        segments: [new DOMRect(0, 0, 200, 800), new DOMRect(224, 0, 200, 800)],
      },
    });
    const fold = readWebFoldState(424, 800);
    expect(fold.isSeparating).toBe(true);
    expect(fold.hingeBounds).toEqual({ x: 200, y: 0, width: 24, height: 800 });
    expect(fold.occludedBounds).toEqual(fold.hingeBounds);
    expect(webDeviceFoldable().foldable).toBe(true);
  });

  it('treats null viewport segments as no hinge data', () => {
    Object.defineProperty(window, 'viewport', {
      configurable: true,
      value: { segments: null },
    });
    Object.defineProperty(navigator, 'devicePosture', {
      configurable: true,
      value: { type: 'continuous', addEventListener: () => undefined },
    });
    expect(readWebFoldState(400, 800)).toEqual({
      state: 'flat',
      isSeparating: false,
      posture: 'flat',
    });
  });
});

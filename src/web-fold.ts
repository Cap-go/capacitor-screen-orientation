/*
 * Portions adapted from capacitor-foldable (MIT)
 * Copyright (c) Erkam Yaman
 * https://github.com/erkamyaman/capacitor-foldable
 * See THIRD_PARTY_LICENSES.
 */

import type { DeviceFoldableResult, FoldBounds, FoldState, HingeOrientation } from './definitions';
import { splitViewport, type SegmentRect } from './segments';

type DevicePostureType = 'continuous' | 'folded';

interface DevicePosture extends EventTarget {
  readonly type: DevicePostureType;
}

interface ViewportSegments {
  readonly segments: readonly { x: number; y: number; width: number; height: number }[] | null;
}

declare global {
  interface Navigator {
    readonly devicePosture?: DevicePosture;
  }

  interface Window {
    readonly viewport?: ViewportSegments;
  }
}

const FLAT_FOLD: FoldState = { state: 'flat', isSeparating: false, posture: 'flat' };

export function webFoldApisAvailable(): boolean {
  return (
    typeof window !== 'undefined' &&
    typeof navigator !== 'undefined' &&
    ('devicePosture' in navigator || 'viewport' in window)
  );
}

export function webDeviceFoldable(): DeviceFoldableResult {
  if (!webFoldApisAvailable()) {
    return { foldable: false, supportsTabletop: false };
  }
  const fold = readWebFoldState(window.innerWidth, window.innerHeight);
  const foldable = fold.state === 'half-opened' || (fold.isSeparating && fold.hingeBounds != null);
  const supportsTabletop = foldable && (fold.posture === 'tabletop' || fold.hingeOrientation === 'horizontal');
  return { foldable, supportsTabletop };
}

export function readWebFoldState(width: number, height: number): FoldState {
  if (typeof window === 'undefined' || typeof navigator === 'undefined') {
    return FLAT_FOLD;
  }

  const fromSegments = foldFromViewportSegments(width, height);
  if (fromSegments) {
    return fromSegments;
  }

  const postureType = navigator.devicePosture?.type ?? 'continuous';
  if (postureType === 'folded') {
    return { state: 'half-opened', isSeparating: false, posture: 'book' };
  }

  return FLAT_FOLD;
}

function foldFromViewportSegments(width: number, height: number): FoldState | null {
  const viewport = window.viewport;
  if (!viewport) {
    return null;
  }

  const rawSegments = viewport.segments;
  if (!rawSegments || rawSegments.length !== 2) {
    return null;
  }

  const rects: SegmentRect[] = rawSegments.map((rect) => ({
    x: rect.x,
    y: rect.y,
    width: rect.width,
    height: rect.height,
  }));

  const folded = navigator.devicePosture?.type === 'folded';
  const state = folded ? 'half-opened' : 'flat';

  const vertical = rects.every((r) => r.y <= 1 && r.height >= height - 1);
  if (vertical) {
    const sorted = [...rects].sort((a, b) => a.x - b.x);
    const left = sorted[0];
    const right = sorted[1];
    const hingeX = left.x + left.width;
    const hingeW = right.x - hingeX;
    if (hingeW < 0) {
      return null;
    }
    const hingeBounds: FoldBounds = { x: hingeX, y: 0, width: hingeW, height };
    return finalizeSegmentFold(state, folded, 'vertical', hingeBounds, width, height);
  }

  const horizontal = rects.every((r) => r.x <= 1 && r.width >= width - 1);
  if (horizontal) {
    const sorted = [...rects].sort((a, b) => a.y - b.y);
    const top = sorted[0];
    const bottom = sorted[1];
    const hingeY = top.y + top.height;
    const hingeH = bottom.y - hingeY;
    if (hingeH < 0) {
      return null;
    }
    const hingeBounds: FoldBounds = { x: 0, y: hingeY, width, height: hingeH };
    return finalizeSegmentFold(state, folded, 'horizontal', hingeBounds, width, height);
  }

  return null;
}

function finalizeSegmentFold(
  state: FoldState['state'],
  folded: boolean,
  hingeOrientation: HingeOrientation,
  hingeBounds: FoldBounds,
  width: number,
  height: number,
): FoldState | null {
  const fold = foldWithHinge(state, folded, hingeOrientation, hingeBounds, true);
  if (splitViewport(fold, width, height).length !== 2) {
    return null;
  }
  return fold;
}

function foldWithHinge(
  state: FoldState['state'],
  folded: boolean,
  hingeOrientation: HingeOrientation,
  hingeBounds: FoldBounds,
  isSeparating: boolean,
): FoldState {
  const posture = !folded ? 'flat' : hingeOrientation === 'horizontal' ? 'tabletop' : 'book';
  const fold: FoldState = {
    state,
    isSeparating,
    posture,
    hingeOrientation,
    hingeBounds,
  };
  const gap = hingeOrientation === 'vertical' ? hingeBounds.width : hingeBounds.height;
  if (gap > 0) {
    fold.occludedBounds = { ...hingeBounds };
  }
  return fold;
}

export function foldStateKey(state: FoldState): string {
  return JSON.stringify(state);
}

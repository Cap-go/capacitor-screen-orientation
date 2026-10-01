import { WebPlugin } from '@capacitor/core';

import type {
  BarPlacement,
  CapacitorScreenOrientationPlugin,
  DeviceFoldableResult,
  FoldState,
  HingeAngleResult,
  ReservedRegion,
  OrientationLockOptions,
  OrientationType,
  ScreenOrientationResult,
  SizeClass,
  StartOrientationTrackingOptions,
} from './definitions';
import { sizeClassOf } from './size-class';
import { foldStateKey, readWebFoldState, webDeviceFoldable } from './web-fold';

export { sizeClassOf } from './size-class';

export class CapacitorScreenOrientationWeb extends WebPlugin implements CapacitorScreenOrientationPlugin {
  private readonly pluginVersion = '1.0.0';
  private lastFoldKey: string | null = null;

  constructor() {
    super();
    if (window.screen?.orientation) {
      window.screen.orientation.addEventListener('change', () => {
        this.notifyListeners('screenOrientationChange', {
          type: this.mapOrientationType(window.screen.orientation.type),
        });
      });
    }
    window.addEventListener('resize', () => {
      this.notifySizeClassIfChanged();
      this.notifyFoldIfChanged();
    });
    navigator.devicePosture?.addEventListener('change', () => {
      this.notifyFoldIfChanged();
    });
    this.lastSizeClass = this.readSizeClass();
    this.lastFoldKey = foldStateKey(readWebFoldState(window.innerWidth, window.innerHeight));
  }

  private lastSizeClass: SizeClass | null = null;

  async orientation(): Promise<ScreenOrientationResult> {
    if (!window.screen?.orientation) {
      throw this.unavailable('Screen Orientation API not available');
    }
    return {
      type: this.mapOrientationType(window.screen.orientation.type),
    };
  }

  async lock(options: OrientationLockOptions): Promise<void> {
    const screenOrientation = window.screen?.orientation as { lock?: (orientation: string) => Promise<void> };
    if (!screenOrientation?.lock) {
      throw this.unavailable('Screen Orientation lock not available');
    }

    try {
      await screenOrientation.lock(options.orientation);
    } catch (error) {
      throw new Error(`Failed to lock orientation: ${error}`);
    }
  }

  async unlock(): Promise<void> {
    const screenOrientation = window.screen?.orientation as { unlock?: () => void };
    if (!screenOrientation?.unlock) {
      throw this.unavailable('Screen Orientation unlock not available');
    }
    screenOrientation.unlock();
  }

  async startOrientationTracking(_options?: StartOrientationTrackingOptions): Promise<void> {
    console.warn('Motion-based orientation tracking is not available on web platform', _options);
  }

  async stopOrientationTracking(): Promise<void> {
    // No-op on web
  }

  async isOrientationLocked(): Promise<{
    locked: boolean;
    physicalOrientation?: OrientationType;
    uiOrientation: OrientationType;
  }> {
    const orientationResult = await this.orientation();
    return {
      locked: false,
      uiOrientation: orientationResult.type,
    };
  }

  async isDeviceFoldable(): Promise<DeviceFoldableResult> {
    return webDeviceFoldable();
  }

  async getFoldState(): Promise<FoldState> {
    return readWebFoldState(window.innerWidth, window.innerHeight);
  }

  async getHingeAngle(): Promise<HingeAngleResult> {
    return { angle: null, status: null };
  }

  async getReservedRegions(): Promise<{ regions: ReservedRegion[] }> {
    return { regions: [] };
  }

  async getBarPlacement(): Promise<BarPlacement> {
    return { verticalBarEdge: null, inset: 0 };
  }

  async setVerticalBarBehavior(): Promise<{ applied: boolean }> {
    return { applied: false };
  }

  async getSizeClass(): Promise<SizeClass> {
    return this.readSizeClass();
  }

  async getPluginVersion(): Promise<{ version: string }> {
    return { version: this.pluginVersion };
  }

  private readSizeClass(): SizeClass {
    return sizeClassOf(window.innerWidth, window.innerHeight);
  }

  private notifySizeClassIfChanged(): void {
    const next = this.readSizeClass();
    const previous = JSON.stringify(this.lastSizeClass);
    if (previous === JSON.stringify(next)) return;
    this.lastSizeClass = next;
    this.notifyListeners('sizeClassChange', next);
  }

  private notifyFoldIfChanged(): void {
    const next = readWebFoldState(window.innerWidth, window.innerHeight);
    const key = foldStateKey(next);
    if (key === this.lastFoldKey) {
      return;
    }
    this.lastFoldKey = key;
    this.notifyListeners('foldStateChange', next);
  }

  private mapOrientationType(type: string): OrientationType {
    if (type.includes('portrait-primary') || type === 'portrait-primary') {
      return 'portrait-primary';
    }
    if (type.includes('portrait-secondary') || type === 'portrait-secondary') {
      return 'portrait-secondary';
    }
    if (type.includes('landscape-primary') || type === 'landscape-primary') {
      return 'landscape-primary';
    }
    if (type.includes('landscape-secondary') || type === 'landscape-secondary') {
      return 'landscape-secondary';
    }
    return 'portrait-primary';
  }
}

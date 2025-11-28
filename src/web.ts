import { WebPlugin } from '@capacitor/core';

import type {
  CapacitorScreenOrientationPlugin,
  OrientationLockOptions,
  OrientationType,
  ScreenOrientationResult,
  StartOrientationTrackingOptions,
} from './definitions';

export class CapacitorScreenOrientationWeb extends WebPlugin implements CapacitorScreenOrientationPlugin {
  private readonly pluginVersion = '1.0.0';

  constructor() {
    super();
    if (window.screen?.orientation) {
      window.screen.orientation.addEventListener('change', () => {
        this.notifyListeners('screenOrientationChange', {
          type: this.mapOrientationType(window.screen.orientation.type),
        });
      });
    }
  }

  async orientation(): Promise<ScreenOrientationResult> {
    if (!window.screen?.orientation) {
      throw this.unavailable('Screen Orientation API not available');
    }
    return {
      type: this.mapOrientationType(window.screen.orientation.type),
    };
  }

  async lock(options: OrientationLockOptions): Promise<void> {
    const screenOrientation = window.screen?.orientation as any;
    if (!screenOrientation?.lock) {
      throw this.unavailable('Screen Orientation lock not available');
    }

    // bypassOrientationLock is only supported on iOS native platform
    // Silently ignore it on web

    try {
      await screenOrientation.lock(options.orientation);
    } catch (error) {
      throw new Error(`Failed to lock orientation: ${error}`);
    }
  }

  async unlock(): Promise<void> {
    const screenOrientation = window.screen?.orientation as any;
    if (!screenOrientation?.unlock) {
      throw this.unavailable('Screen Orientation unlock not available');
    }
    screenOrientation.unlock();
  }

  async startOrientationTracking(_options?: StartOrientationTrackingOptions): Promise<void> {
    // Motion-based orientation tracking is only supported on iOS
    // Silently ignore on web
  }

  async stopOrientationTracking(): Promise<void> {
    // Motion-based orientation tracking is only supported on iOS
    // Silently ignore on web
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

  async getPluginVersion(): Promise<{ version: string }> {
    return { version: this.pluginVersion };
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
    return 'portrait-primary'; // default fallback
  }
}

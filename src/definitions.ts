import type { PluginListenerHandle } from '@capacitor/core';

/**
 * Orientation type that describes the orientation state of the device.
 *
 * @since 1.0.0
 */
export type OrientationType = 'portrait-primary' | 'portrait-secondary' | 'landscape-primary' | 'landscape-secondary';

/**
 * Orientation lock type that can be used to lock the device orientation.
 *
 * @since 1.0.0
 */
export type OrientationLockType =
  | 'any'
  | 'natural'
  | 'landscape'
  | 'portrait'
  | 'portrait-primary'
  | 'portrait-secondary'
  | 'landscape-primary'
  | 'landscape-secondary';

/**
 * Result returned by the orientation() method.
 *
 * @since 1.0.0
 */
export interface ScreenOrientationResult {
  /**
   * The current orientation type.
   *
   * @since 1.0.0
   */
  type: OrientationType;
}

/**
 * Result returned by the isOrientationLocked() method.
 *
 * @since 1.0.0
 */
export interface OrientationLockStatusResult {
  /**
   * Whether the device orientation lock is currently enabled.
   *
   * This is determined by comparing the physical device orientation
   * (from motion sensors) with the UI orientation. If they differ,
   * orientation lock is enabled.
   *
   * Available on iOS (Core Motion) and Android (Accelerometer) when motion tracking is active.
   *
   * @since 1.0.0
   */
  locked: boolean;

  /**
   * The physical orientation of the device from motion sensors.
   * Available when motion tracking is active (iOS and Android).
   *
   * @since 1.0.0
   */
  physicalOrientation?: OrientationType;

  /**
   * The current UI orientation reported by the system.
   *
   * @since 1.0.0
   */
  uiOrientation: OrientationType;
}

/**
 * Options for locking the screen orientation.
 *
 * @since 1.0.0
 */
export interface OrientationLockOptions {
  /**
   * The orientation type to lock to.
   *
   * @since 1.0.0
   */
  orientation: OrientationLockType;

  /**
   * Whether to track physical device orientation using motion sensors.
   * When true, uses device motion sensors to detect the true physical
   * orientation of the device, even when the device orientation lock is enabled.
   *
   * **Important:** This does NOT bypass the UI orientation lock.
   * The screen will still respect the user's orientation lock setting.
   * This option only affects orientation detection/tracking - you'll receive
   * orientation change events based on how the device is physically held,
   * but the UI will not rotate if orientation lock is enabled.
   *
   * Supported on iOS (Core Motion) and Android (Accelerometer).
   *
   * @default false
   * @since 1.0.0
   */
  bypassOrientationLock?: boolean;
}

/**
 * Options for starting orientation tracking using motion sensors.
 *
 * @since 1.0.0
 */
export interface StartOrientationTrackingOptions {
  /**
   * Whether to track physical device orientation using motion sensors.
   * When true, uses device motion sensors to detect the true physical
   * orientation of the device, even when the device orientation lock is enabled.
   *
   * **Important:** This does NOT bypass the UI orientation lock.
   * This only enables detection of the physical orientation.
   *
   * Supported on iOS (Core Motion) and Android (Accelerometer).
   *
   * @default false
   * @since 1.0.0
   */
  bypassOrientationLock?: boolean;
}

/**
 * Capacitor Screen Orientation Plugin interface.
 *
 * Provides methods to detect and control screen orientation,
 * with support for detecting true physical device orientation using motion sensors.
 *
 * @since 1.0.0
 */
export interface CapacitorScreenOrientationPlugin {
  /**
   * Get the current screen orientation.
   *
   * Returns the current orientation of the device screen.
   *
   * @since 1.0.0
   * @returns {Promise<ScreenOrientationResult>} A promise that resolves with the current orientation.
   *
   * @example
   * ```typescript
   * const result = await ScreenOrientation.orientation();
   * console.log('Current orientation:', result.type);
   * ```
   */
  orientation(): Promise<ScreenOrientationResult>;

  /**
   * Lock the screen orientation to a specific type.
   *
   * Locks the screen to the specified orientation.
   * On iOS, if bypassOrientationLock is true, it will also start
   * tracking physical device orientation using motion sensors.
   *
   * Note: The UI will still respect the user's orientation lock setting.
   * Motion tracking allows you to detect how the device is physically held
   * even when the UI doesn't rotate.
   *
   * @since 1.0.0
   * @param options Options for locking the orientation.
   * @returns {Promise<void>} A promise that resolves when the orientation is locked.
   *
   * @example
   * ```typescript
   * // Standard lock
   * await ScreenOrientation.lock({ orientation: 'landscape' });
   *
   * // Lock with motion tracking on iOS
   * await ScreenOrientation.lock({
   *   orientation: 'portrait',
   *   bypassOrientationLock: true
   * });
   * ```
   */
  lock(options: OrientationLockOptions): Promise<void>;

  /**
   * Unlock the screen orientation.
   *
   * Allows the screen to rotate freely based on device position.
   * Also stops any motion-based orientation tracking if it was enabled.
   *
   * @since 1.0.0
   * @returns {Promise<void>} A promise that resolves when the orientation is unlocked.
   *
   * @example
   * ```typescript
   * await ScreenOrientation.unlock();
   * ```
   */
  unlock(): Promise<void>;

  /**
   * Start tracking device orientation using motion sensors.
   *
   * This method is useful when you want to track the device's physical
   * orientation independently from the screen orientation lock.
   * It uses Core Motion on iOS to detect orientation changes.
   *
   * @since 1.0.0
   * @param options Options for starting orientation tracking.
   * @returns {Promise<void>} A promise that resolves when tracking starts.
   *
   * @example
   * ```typescript
   * await ScreenOrientation.startOrientationTracking({
   *   bypassOrientationLock: true
   * });
   *
   * // Listen for changes
   * ScreenOrientation.addListener('screenOrientationChange', (result) => {
   *   console.log('Orientation changed:', result.type);
   * });
   * ```
   */
  startOrientationTracking(options?: StartOrientationTrackingOptions): Promise<void>;

  /**
   * Stop tracking device orientation using motion sensors.
   *
   * Stops the motion-based orientation tracking if it was started.
   *
   * @since 1.0.0
   * @returns {Promise<void>} A promise that resolves when tracking stops.
   *
   * @example
   * ```typescript
   * await ScreenOrientation.stopOrientationTracking();
   * ```
   */
  stopOrientationTracking(): Promise<void>;

  /**
   * Check if device orientation lock is currently enabled.
   *
   * This method compares the physical device orientation (from motion sensors)
   * with the UI orientation. If they differ, orientation lock is enabled.
   *
   * Note: This requires motion tracking to be active via
   * startOrientationTracking() or lock() with bypassOrientationLock: true.
   * Works on both iOS (Core Motion) and Android (Accelerometer).
   *
   * @since 1.0.0
   * @returns {Promise<OrientationLockStatusResult>} A promise that resolves with the lock status.
   *
   * @example
   * ```typescript
   * // Start motion tracking first
   * await ScreenOrientation.startOrientationTracking({
   *   bypassOrientationLock: true
   * });
   *
   * // Check lock status
   * const status = await ScreenOrientation.isOrientationLocked();
   * if (status.locked) {
   *   console.log('Orientation lock is ON');
   *   console.log('Physical:', status.physicalOrientation);
   *   console.log('UI:', status.uiOrientation);
   * }
   * ```
   */
  isOrientationLocked(): Promise<OrientationLockStatusResult>;

  /**
   * Listen for screen orientation changes.
   *
   * Registers a listener that will be called whenever the screen orientation changes.
   * If motion-based tracking is enabled, this will also fire for orientation changes
   * detected by motion sensors even when orientation lock is enabled.
   *
   * @since 1.0.0
   * @param eventName The event name. Must be 'screenOrientationChange'.
   * @param listenerFunc Callback function invoked when orientation changes.
   * @returns {Promise<PluginListenerHandle>} A promise that resolves to a listener handle.
   *
   * @example
   * ```typescript
   * const listener = await ScreenOrientation.addListener(
   *   'screenOrientationChange',
   *   (result) => {
   *     console.log('New orientation:', result.type);
   *   }
   * );
   *
   * // To remove the listener:
   * await listener.remove();
   * ```
   */
  addListener(
    eventName: 'screenOrientationChange',
    listenerFunc: (result: ScreenOrientationResult) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Remove all listeners for this plugin.
   *
   * Removes all registered event listeners.
   *
   * @since 1.0.0
   * @returns {Promise<void>} A promise that resolves when all listeners are removed.
   *
   * @example
   * ```typescript
   * await ScreenOrientation.removeAllListeners();
   * ```
   */
  removeAllListeners(): Promise<void>;

  /**
   * Get the native plugin version.
   *
   * Returns the current version of the native plugin implementation.
   *
   * @since 1.0.0
   * @returns {Promise<{ version: string }>} A promise that resolves with the version string.
   *
   * @example
   * ```typescript
   * const { version } = await ScreenOrientation.getPluginVersion();
   * console.log('Plugin version:', version);
   * ```
   */
  getPluginVersion(): Promise<{ version: string }>;
}

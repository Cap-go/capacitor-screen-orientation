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
 * How open a foldable is.
 *
 * `closed` is reserved. A device shut onto its cover display reports `flat`.
 *
 * @since 8.2.0
 */
export type FoldStateValue = 'flat' | 'half-opened';

/**
 * How a half-open foldable is held.
 *
 * `tabletop` is a horizontal hinge, like a laptop. `book` is a vertical hinge.
 *
 * @since 8.2.0
 */
export type FoldPosture = 'flat' | 'tabletop' | 'book';

/**
 * Direction of the hinge relative to the window.
 *
 * @since 8.2.0
 */
export type HingeOrientation = 'horizontal' | 'vertical';

/**
 * A rectangle in CSS pixels, relative to the web view.
 *
 * @since 8.2.0
 */
export interface FoldBounds {
  x: number;
  y: number;
  width: number;
  height: number;
}

/**
 * Current fold of the window.
 *
 * Phones that do not fold, and iOS before 27.1, resolve to a flat state.
 * iPhone Duo reports `book`, `tabletop`, or `flat`, and which display is in front.
 *
 * @since 8.2.0
 */
export interface FoldState {
  /**
   * Posture of the fold.
   *
   * @since 8.2.0
   */
  state: FoldStateValue;

  /**
   * Whether the fold splits the web view into two areas.
   *
   * @since 8.2.0
   */
  isSeparating: boolean;

  /**
   * How the device is held.
   *
   * @since 8.2.0
   */
  posture: FoldPosture;

  /**
   * Direction of the hinge. Omitted when there is no fold.
   *
   * @since 8.2.0
   */
  hingeOrientation?: HingeOrientation;

  /**
   * Position of the fold in CSS pixels. Omitted when there is no fold.
   *
   * @since 8.2.0
   */
  hingeBounds?: FoldBounds;

  /**
   * Area the hinge covers. Present when the hinge has a physical gap.
   *
   * @since 8.2.0
   */
  occludedBounds?: FoldBounds;

  /**
   * Which display is showing the app on iPhone Duo. Omitted on Android, web, and iOS before 27.1.
   *
   * @since 8.2.0
   */
  activeDisplay?: 'inner' | 'outer';

  /**
   * Space the system keeps clear around the fold, in CSS pixels. iPhone Duo reports 20 on each side of a vertical fold.
   *
   * @since 8.2.0
   */
  hingeMargins?: { top: number; right: number; bottom: number; left: number };

  /**
   * Areas covering the display, such as the iPhone Duo camera. Omitted when there are none.
   *
   * @since 8.2.0
   */
  cameraBounds?: FoldBounds[];
}

/**
 * Whether this device can fold.
 *
 * @since 8.2.0
 */
export interface DeviceFoldableResult {
  /**
   * Whether the device has a fold.
   *
   * @since 8.2.0
   */
  foldable: boolean;

  /**
   * Whether it can stand half-open like a laptop.
   *
   * @since 8.2.0
   */
  supportsTabletop: boolean;
}

/**
 * Angle between the two halves of a foldable, in degrees.
 *
 * `0` is closed and `180` is flat. `angle` is `null` when the device has no hinge sensor.
 *
 * @since 8.2.0
 */
export interface HingeAngleResult {
  /**
   * Hinge angle in degrees, or `null` when no sensor is available.
   *
   * @since 8.2.0
   */
  angle: number | null;

  /**
   * How far open iPhone Duo is, as the system sees it. `null` on Android and web.
   *
   * @since 8.2.0
   */
  status?: 'closed' | 'partiallyOpen' | 'fullyOpen' | null;
}

/**
 * A region the system reserves on iPhone Duo.
 *
 * `division` is the fold. `occlusion` is something covering the display, such as the camera.
 *
 * @since 8.2.0
 */
export interface ReservedRegion {
  /**
   * What the region is.
   *
   * @since 8.2.0
   */
  kind: 'division' | 'occlusion';

  /**
   * Whether the region applies right now. An inactive division is a flat fold.
   *
   * @since 8.2.0
   */
  isActive: boolean;

  /**
   * Left edge, in CSS pixels.
   *
   * @since 8.2.0
   */
  x: number;

  /**
   * Top edge, in CSS pixels.
   *
   * @since 8.2.0
   */
  y: number;

  /**
   * Width in CSS pixels.
   *
   * @since 8.2.0
   */
  width: number;

  /**
   * Height in CSS pixels.
   *
   * @since 8.2.0
   */
  height: number;

  /**
   * Space to keep clear around the region, in CSS pixels.
   *
   * @since 8.2.0
   */
  margins: { top: number; right: number; bottom: number; left: number };
}

/**
 * Where iPhone Duo places native bars.
 *
 * @since 8.2.0
 */
export interface BarPlacement {
  /**
   * The edge the system moves tab bars and toolbars to. `null` when they stay horizontal.
   *
   * @since 8.2.0
   */
  verticalBarEdge: 'leading' | 'trailing' | null;

  /**
   * How much room the vertical bar takes, in points. `0` when bars stay horizontal.
   *
   * @since 8.2.0
   */
  inset: number;
}

/**
 * Window size classes.
 *
 * `horizontal` and `vertical` follow Apple's compact/regular split.
 * On Android and web, `regular` starts at 600 CSS pixels wide and 480 tall.
 * `widthClass` and `heightClass` follow Material window size classes.
 *
 * @since 8.2.0
 */
export interface SizeClass {
  /**
   * Width size class. `compact` on a phone, `regular` on the inner display of a foldable, a tablet, or a window at least 600 CSS pixels wide.
   *
   * @since 8.2.0
   */
  horizontal: 'compact' | 'regular';

  /**
   * Height size class. `regular` starts at 480 CSS pixels.
   *
   * @since 8.2.0
   */
  vertical: 'compact' | 'regular';

  /**
   * Material window width class.
   *
   * @since 8.2.0
   */
  widthClass: 'compact' | 'medium' | 'expanded' | 'large' | 'extraLarge';

  /**
   * Material window height class.
   *
   * @since 8.2.0
   */
  heightClass: 'compact' | 'medium' | 'expanded';
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
  /**
   * Whether this device folds, and whether it can stand half-open like a laptop.
   *
   * On web, both flags are `false` when the browser does not expose the Device Posture API or
   * Viewport Segments API. When those APIs exist, `foldable` is `true` and `supportsTabletop`
   * reflects the current hinge orientation when known.
   *
   * On Android, both flags are `false` on phones that do not fold. On iOS, both are `false`
   * except on iPhone Duo (iOS 27.1 or later).
   *
   * @since 8.2.0
   * @returns {Promise<DeviceFoldableResult>} Fold capability of this device.
   *
   * @example
   * ```typescript
   * const { foldable, supportsTabletop } = await ScreenOrientation.isDeviceFoldable();
   * ```
   */
  isDeviceFoldable(): Promise<DeviceFoldableResult>;

  /**
   * Read the current fold.
   *
   * Resolves to a flat state when the device has no fold. On web, uses
   * `navigator.devicePosture` and `window.viewport.segments` when the browser provides them.
   *
   * @since 8.2.0
   * @returns {Promise<FoldState>} The current fold state.
   *
   * @example
   * ```typescript
   * const { posture, hingeOrientation } = await ScreenOrientation.getFoldState();
   * ```
   */
  getFoldState(): Promise<FoldState>;

  /**
   * Read the hinge angle in degrees.
   *
   * `0` is closed and `180` is flat. `angle` is `null` without a hinge sensor.
   *
   * @since 8.2.0
   * @returns {Promise<HingeAngleResult>} The latest hinge angle.
   *
   * @example
   * ```typescript
   * const { angle } = await ScreenOrientation.getHingeAngle();
   * ```
   */
  getHingeAngle(): Promise<HingeAngleResult>;

  /**
   * Read the fold and anything covering the screen.
   *
   * iPhone Duo reports the fold, the vertical status bar area, and the under-display camera.
   * Resolves to an empty list on Android, web, and iOS before 27.1.
   *
   * @since 8.2.0
   * @returns {Promise<{ regions: ReservedRegion[] }>} The reserved regions.
   */
  getReservedRegions(): Promise<{ regions: ReservedRegion[] }>;

  /**
   * Read where iPhone Duo puts native tab bars and toolbars.
   *
   * `verticalBarEdge` is `null` when bars stay horizontal, and always on Android and web.
   *
   * @since 8.2.0
   * @returns {Promise<BarPlacement>} The current bar placement.
   */
  getBarPlacement(): Promise<BarPlacement>;

  /**
   * Choose whether iPhone Duo may move this app's bars to the side.
   *
   * Resolves to `{ applied: false }` unless the app's bridge view controller opts in.
   * Android and web always resolve to `{ applied: false }`.
   *
   * @since 8.2.0
   * @param options `automatic` lets the system move bars. `disabled` keeps them horizontal.
   * @returns {Promise<{ applied: boolean }>} Whether the app applied the choice.
   */
  setVerticalBarBehavior(options: { behavior: 'automatic' | 'disabled' }): Promise<{ applied: boolean }>;

  /**
   * Read the window size classes.
   *
   * @since 8.2.0
   * @returns {Promise<SizeClass>} Apple and Material size classes for the current window.
   *
   * @example
   * ```typescript
   * const { horizontal, widthClass } = await ScreenOrientation.getSizeClass();
   * ```
   */
  getSizeClass(): Promise<SizeClass>;

  addListener(
    eventName: 'screenOrientationChange',
    listenerFunc: (result: ScreenOrientationResult) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Listen for fold changes.
   *
   * On a foldable this also fires when the device rotates, because the hinge
   * bounds rotate with the window.
   *
   * @since 8.2.0
   * @param eventName The event name. Must be 'foldStateChange'.
   * @param listenerFunc Callback invoked with the new fold state.
   * @returns {Promise<PluginListenerHandle>} A promise that resolves to a listener handle.
   */
  addListener(eventName: 'foldStateChange', listenerFunc: (state: FoldState) => void): Promise<PluginListenerHandle>;

  /**
   * Listen for hinge angle changes.
   *
   * On Android the hinge sensor runs only while at least one listener is registered.
   * On iOS this fires on iPhone Duo (iOS 27.1 or later). On web, hinge angle stays `null`;
   * use `foldStateChange` for posture updates from the Device Posture API.
   *
   * @since 8.2.0
   * @param eventName The event name. Must be 'hingeAngleChange'.
   * @param listenerFunc Callback invoked with the angle in degrees.
   * @returns {Promise<PluginListenerHandle>} A promise that resolves to a listener handle.
   */
  addListener(
    eventName: 'hingeAngleChange',
    listenerFunc: (event: HingeAngleResult) => void,
  ): Promise<PluginListenerHandle>;

  /**
   * Listen for size class changes, such as unfolding, rotating, or resizing.
   *
   * @since 8.2.0
   * @param eventName The event name. Must be 'sizeClassChange'.
   * @param listenerFunc Callback invoked with the new size class.
   * @returns {Promise<PluginListenerHandle>} A promise that resolves to a listener handle.
   */
  addListener(
    eventName: 'sizeClassChange',
    listenerFunc: (sizeClass: SizeClass) => void,
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

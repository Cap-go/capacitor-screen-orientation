# @capgo/capacitor-screen-orientation

 <a href="https://capgo.app/"><img src='https://raw.githubusercontent.com/Cap-go/capgo/main/assets/capgo_banner.png' alt='Capgo - Instant updates for capacitor'/></a>

<div align="center">
  <h2><a href="https://capgo.app/?ref=plugin_screen_orientation"> ➡️ Get Instant updates for your App with Capgo</a></h2>
  <h2><a href="https://capgo.app/consulting/?ref=plugin_screen_orientation"> Missing a feature? We'll build the plugin for you 💪</a></h2>
</div>



Screen orientation plugin with support for detecting true physical device orientation

## Features

- 📱 Full Screen Orientation API support
- 🔍 **Detect true physical device orientation** using motion sensors (even when orientation lock is enabled)
  - iOS: Uses Core Motion framework
  - Android: Uses accelerometer sensor
- 🔒 **Detect if orientation lock is enabled** by comparing physical vs UI orientation
- 🔄 Real-time orientation change detection
- 🎯 Lock orientation to specific modes
- 🌐 Web platform support

**Important Note:** This plugin can detect the physical orientation of the device using motion sensors, but it **cannot bypass the UI orientation lock**. The screen will still respect the user's orientation lock setting. This is useful for knowing how the device is physically held vs. how the UI is displayed.

## Documentation

The most complete doc is available here: https://capgo.app/docs/plugins/screen-orientation/

## Install

```bash
npm install @capgo/capacitor-screen-orientation
npx cap sync
```

## iOS Configuration

To detect physical device orientation using motion sensors on iOS, you need to add the Motion Usage Description to your `Info.plist`:

```xml
<key>NSMotionUsageDescription</key>
<string>This app uses motion sensors to detect the true physical orientation of your device.</string>
```

## Usage

```typescript
import { ScreenOrientation } from '@capgo/capacitor-screen-orientation';

// Get current orientation
const result = await ScreenOrientation.orientation();
console.log('Current orientation:', result.type);

// Lock to landscape
await ScreenOrientation.lock({ orientation: 'landscape' });

// Lock UI orientation and track physical orientation via motion sensors
// Note: UI will still respect user's orientation lock, but you'll get physical orientation events
await ScreenOrientation.lock({
  orientation: 'portrait',
  bypassOrientationLock: true
});

// Listen for orientation changes
const listener = await ScreenOrientation.addListener(
  'screenOrientationChange',
  (result) => {
    console.log('Orientation changed:', result.type);
  }
);

// Unlock orientation
await ScreenOrientation.unlock();

// Start motion-based tracking to detect physical device orientation
// This uses motion sensors to track how the device is actually held
await ScreenOrientation.startOrientationTracking({
  bypassOrientationLock: true
});

// Check if device orientation lock is enabled
// Compares physical device orientation (from sensors) with UI orientation (from system)
const lockStatus = await ScreenOrientation.isOrientationLocked();
if (lockStatus.locked) {
  console.log('Orientation lock is ON!');
  console.log('Physical device orientation:', lockStatus.physicalOrientation);
  console.log('UI orientation:', lockStatus.uiOrientation);
} else {
  console.log('Orientation lock is OFF or motion tracking not active');
}

// Stop motion-based tracking
await ScreenOrientation.stopOrientationTracking();

// Remove listener
await listener.remove();
```

## API

<docgen-index>

* [`orientation()`](#orientation)
* [`lock(...)`](#lock)
* [`unlock()`](#unlock)
* [`startOrientationTracking(...)`](#startorientationtracking)
* [`stopOrientationTracking()`](#stoporientationtracking)
* [`isOrientationLocked()`](#isorientationlocked)
* [`addListener('screenOrientationChange', ...)`](#addlistenerscreenorientationchange-)
* [`removeAllListeners()`](#removealllisteners)
* [`getPluginVersion()`](#getpluginversion)
* [Interfaces](#interfaces)
* [Type Aliases](#type-aliases)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

Capacitor Screen Orientation Plugin interface.

Provides methods to detect and control screen orientation,
with support for detecting true physical device orientation using motion sensors.

### orientation()

```typescript
orientation() => Promise<ScreenOrientationResult>
```

Get the current screen orientation.

Returns the current orientation of the device screen.

**Returns:** <code>Promise&lt;<a href="#screenorientationresult">ScreenOrientationResult</a>&gt;</code>

**Since:** 1.0.0

--------------------


### lock(...)

```typescript
lock(options: OrientationLockOptions) => Promise<void>
```

Lock the screen orientation to a specific type.

Locks the screen to the specified orientation.
On iOS, if bypassOrientationLock is true, it will also start
tracking physical device orientation using motion sensors.

Note: The UI will still respect the user's orientation lock setting.
Motion tracking allows you to detect how the device is physically held
even when the UI doesn't rotate.

| Param         | Type                                                                      | Description                          |
| ------------- | ------------------------------------------------------------------------- | ------------------------------------ |
| **`options`** | <code><a href="#orientationlockoptions">OrientationLockOptions</a></code> | Options for locking the orientation. |

**Since:** 1.0.0

--------------------


### unlock()

```typescript
unlock() => Promise<void>
```

Unlock the screen orientation.

Allows the screen to rotate freely based on device position.
Also stops any motion-based orientation tracking if it was enabled.

**Since:** 1.0.0

--------------------


### startOrientationTracking(...)

```typescript
startOrientationTracking(options?: StartOrientationTrackingOptions | undefined) => Promise<void>
```

Start tracking device orientation using motion sensors.

This method is useful when you want to track the device's physical
orientation independently from the screen orientation lock.
It uses Core Motion on iOS to detect orientation changes.

| Param         | Type                                                                                        | Description                                |
| ------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------ |
| **`options`** | <code><a href="#startorientationtrackingoptions">StartOrientationTrackingOptions</a></code> | Options for starting orientation tracking. |

**Since:** 1.0.0

--------------------


### stopOrientationTracking()

```typescript
stopOrientationTracking() => Promise<void>
```

Stop tracking device orientation using motion sensors.

Stops the motion-based orientation tracking if it was started.

**Since:** 1.0.0

--------------------


### isOrientationLocked()

```typescript
isOrientationLocked() => Promise<OrientationLockStatusResult>
```

Check if device orientation lock is currently enabled.

This method compares the physical device orientation (from motion sensors)
with the UI orientation. If they differ, orientation lock is enabled.

Note: This requires motion tracking to be active via
startOrientationTracking() or lock() with bypassOrientationLock: true.
Works on both iOS (Core Motion) and Android (Accelerometer).

**Returns:** <code>Promise&lt;<a href="#orientationlockstatusresult">OrientationLockStatusResult</a>&gt;</code>

**Since:** 1.0.0

--------------------


### addListener('screenOrientationChange', ...)

```typescript
addListener(eventName: 'screenOrientationChange', listenerFunc: (result: ScreenOrientationResult) => void) => Promise<PluginListenerHandle>
```

Listen for screen orientation changes.

Registers a listener that will be called whenever the screen orientation changes.
If motion-based tracking is enabled, this will also fire for orientation changes
detected by motion sensors even when orientation lock is enabled.

| Param              | Type                                                                                             | Description                                         |
| ------------------ | ------------------------------------------------------------------------------------------------ | --------------------------------------------------- |
| **`eventName`**    | <code>'screenOrientationChange'</code>                                                           | The event name. Must be 'screenOrientationChange'.  |
| **`listenerFunc`** | <code>(result: <a href="#screenorientationresult">ScreenOrientationResult</a>) =&gt; void</code> | Callback function invoked when orientation changes. |

**Returns:** <code>Promise&lt;<a href="#pluginlistenerhandle">PluginListenerHandle</a>&gt;</code>

**Since:** 1.0.0

--------------------


### removeAllListeners()

```typescript
removeAllListeners() => Promise<void>
```

Remove all listeners for this plugin.

Removes all registered event listeners.

**Since:** 1.0.0

--------------------


### getPluginVersion()

```typescript
getPluginVersion() => Promise<{ version: string; }>
```

Get the native plugin version.

Returns the current version of the native plugin implementation.

**Returns:** <code>Promise&lt;{ version: string; }&gt;</code>

**Since:** 1.0.0

--------------------


### Interfaces


#### ScreenOrientationResult

Result returned by the orientation() method.

| Prop       | Type                                                        | Description                   | Since |
| ---------- | ----------------------------------------------------------- | ----------------------------- | ----- |
| **`type`** | <code><a href="#orientationtype">OrientationType</a></code> | The current orientation type. | 1.0.0 |


#### OrientationLockOptions

Options for locking the screen orientation.

| Prop                        | Type                                                                | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | Default            | Since |
| --------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ----- |
| **`orientation`**           | <code><a href="#orientationlocktype">OrientationLockType</a></code> | The orientation type to lock to.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |                    | 1.0.0 |
| **`bypassOrientationLock`** | <code>boolean</code>                                                | Whether to track physical device orientation using motion sensors. When true, uses device motion sensors to detect the true physical orientation of the device, even when the device orientation lock is enabled. **Important:** This does NOT bypass the UI orientation lock. The screen will still respect the user's orientation lock setting. This option only affects orientation detection/tracking - you'll receive orientation change events based on how the device is physically held, but the UI will not rotate if orientation lock is enabled. Supported on iOS (Core Motion) and Android (Accelerometer). | <code>false</code> | 1.0.0 |


#### StartOrientationTrackingOptions

Options for starting orientation tracking using motion sensors.

| Prop                        | Type                 | Description                                                                                                                                                                                                                                                                                                                                                                                         | Default            | Since |
| --------------------------- | -------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------ | ----- |
| **`bypassOrientationLock`** | <code>boolean</code> | Whether to track physical device orientation using motion sensors. When true, uses device motion sensors to detect the true physical orientation of the device, even when the device orientation lock is enabled. **Important:** This does NOT bypass the UI orientation lock. This only enables detection of the physical orientation. Supported on iOS (Core Motion) and Android (Accelerometer). | <code>false</code> | 1.0.0 |


#### OrientationLockStatusResult

Result returned by the isOrientationLocked() method.

| Prop                      | Type                                                        | Description                                                                                                                                                                                                                                                                                                      | Since |
| ------------------------- | ----------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| **`locked`**              | <code>boolean</code>                                        | Whether the device orientation lock is currently enabled. This is determined by comparing the physical device orientation (from motion sensors) with the UI orientation. If they differ, orientation lock is enabled. Available on iOS (Core Motion) and Android (Accelerometer) when motion tracking is active. | 1.0.0 |
| **`physicalOrientation`** | <code><a href="#orientationtype">OrientationType</a></code> | The physical orientation of the device from motion sensors. Available when motion tracking is active (iOS and Android).                                                                                                                                                                                          | 1.0.0 |
| **`uiOrientation`**       | <code><a href="#orientationtype">OrientationType</a></code> | The current UI orientation reported by the system.                                                                                                                                                                                                                                                               | 1.0.0 |


#### PluginListenerHandle

| Prop         | Type                                      |
| ------------ | ----------------------------------------- |
| **`remove`** | <code>() =&gt; Promise&lt;void&gt;</code> |


### Type Aliases


#### OrientationType

Orientation type that describes the orientation state of the device.

<code>'portrait-primary' | 'portrait-secondary' | 'landscape-primary' | 'landscape-secondary'</code>


#### OrientationLockType

Orientation lock type that can be used to lock the device orientation.

<code>'any' | 'natural' | 'landscape' | 'portrait' | 'portrait-primary' | 'portrait-secondary' | 'landscape-primary' | 'landscape-secondary'</code>

</docgen-api>

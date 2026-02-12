package ee.forgr.capacitor.screenorientation;

import android.content.Context;
import android.content.pm.ActivityInfo;
import android.content.res.Configuration;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.view.Surface;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "CapacitorScreenOrientation")
public class CapacitorScreenOrientationPlugin extends Plugin implements SensorEventListener {

    private final String pluginVersion = "8.1.10";
    private int currentOrientation;
    private SensorManager sensorManager;
    private Sensor accelerometer;
    private boolean isTrackingMotion = false;
    private String currentPhysicalOrientation = "portrait-primary";
    private String lastNotifiedOrientation = null;

    @Override
    public void load() {
        super.load();
        currentOrientation = getActivity().getResources().getConfiguration().orientation;

        // Initialize sensor manager
        sensorManager = (SensorManager) getActivity().getSystemService(Context.SENSOR_SERVICE);
        if (sensorManager != null) {
            accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
        }
    }

    @Override
    protected void handleOnDestroy() {
        stopMotionTracking();
        super.handleOnDestroy();
    }

    @Override
    protected void handleOnConfigurationChanged(Configuration newConfig) {
        super.handleOnConfigurationChanged(newConfig);

        // Skip system orientation changes when motion tracking is active
        // to avoid duplicate events
        if (isTrackingMotion) {
            return;
        }

        if (currentOrientation != newConfig.orientation) {
            currentOrientation = newConfig.orientation;
            notifyOrientationChange();
        }
    }

    @PluginMethod
    public void orientation(final PluginCall call) {
        try {
            final JSObject ret = new JSObject();
            ret.put("type", getCurrentOrientationType());
            call.resolve(ret);
        } catch (final Exception e) {
            call.reject("Could not get orientation", e);
        }
    }

    @PluginMethod
    public void lock(final PluginCall call) {
        final String orientationString = call.getString("orientation");
        final Boolean bypassLock = call.getBoolean("bypassOrientationLock", false);

        if (orientationString == null) {
            call.reject("Orientation parameter is required");
            return;
        }

        try {
            final int orientation = getOrientationConstant(orientationString);
            getActivity().setRequestedOrientation(orientation);

            // Start motion tracking if requested
            if (bypassLock) {
                startMotionTracking();
            }

            call.resolve();
        } catch (final Exception e) {
            call.reject("Could not lock orientation", e);
        }
    }

    @PluginMethod
    public void unlock(final PluginCall call) {
        try {
            stopMotionTracking();
            getActivity().setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED);
            call.resolve();
        } catch (final Exception e) {
            call.reject("Could not unlock orientation", e);
        }
    }

    @PluginMethod
    public void startOrientationTracking(final PluginCall call) {
        final Boolean bypassLock = call.getBoolean("bypassOrientationLock", false);

        if (bypassLock) {
            startMotionTracking();
        }

        call.resolve();
    }

    @PluginMethod
    public void stopOrientationTracking(final PluginCall call) {
        stopMotionTracking();
        call.resolve();
    }

    @PluginMethod
    public void isOrientationLocked(final PluginCall call) {
        try {
            final String uiOrientation = getCurrentOrientationType();
            final JSObject ret = new JSObject();

            if (isTrackingMotion) {
                // Compare physical orientation with UI orientation
                final boolean locked = !currentPhysicalOrientation.equals(uiOrientation);
                ret.put("locked", locked);
                ret.put("physicalOrientation", currentPhysicalOrientation);
                ret.put("uiOrientation", uiOrientation);
            } else {
                // No motion tracking active, can't determine if locked
                ret.put("locked", false);
                ret.put("uiOrientation", uiOrientation);
            }

            call.resolve(ret);
        } catch (final Exception e) {
            call.reject("Could not check orientation lock status", e);
        }
    }

    @PluginMethod
    public void getPluginVersion(final PluginCall call) {
        try {
            final JSObject ret = new JSObject();
            ret.put("version", this.pluginVersion);
            call.resolve(ret);
        } catch (final Exception e) {
            call.reject("Could not get plugin version", e);
        }
    }

    private void notifyOrientationChange() {
        final JSObject ret = new JSObject();
        ret.put("type", getCurrentOrientationType());
        notifyListeners("screenOrientationChange", ret);
    }

    private String getCurrentOrientationType() {
        final int rotation = getActivity().getWindowManager().getDefaultDisplay().getRotation();
        final int orientation = getActivity().getResources().getConfiguration().orientation;

        if (orientation == Configuration.ORIENTATION_PORTRAIT) {
            return rotation == Surface.ROTATION_0 ? "portrait-primary" : "portrait-secondary";
        } else {
            return rotation == Surface.ROTATION_90 ? "landscape-primary" : "landscape-secondary";
        }
    }

    private int getOrientationConstant(final String orientationString) {
        switch (orientationString) {
            case "any":
                return ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED;
            case "natural":
                return ActivityInfo.SCREEN_ORIENTATION_NOSENSOR;
            case "landscape":
                return ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE;
            case "portrait":
                return ActivityInfo.SCREEN_ORIENTATION_SENSOR_PORTRAIT;
            case "portrait-primary":
                return ActivityInfo.SCREEN_ORIENTATION_PORTRAIT;
            case "portrait-secondary":
                return ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT;
            case "landscape-primary":
                return ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE;
            case "landscape-secondary":
                return ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE;
            default:
                return ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED;
        }
    }

    // Motion tracking methods
    private void startMotionTracking() {
        if (isTrackingMotion || accelerometer == null) {
            return;
        }

        isTrackingMotion = true;
        sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_NORMAL);
        android.util.Log.i("ScreenOrientation", "Started motion-based orientation tracking");
    }

    private void stopMotionTracking() {
        if (!isTrackingMotion) {
            return;
        }

        isTrackingMotion = false;
        if (sensorManager != null) {
            sensorManager.unregisterListener(this);
        }
        android.util.Log.i("ScreenOrientation", "Stopped motion-based orientation tracking");
    }

    @Override
    public void onSensorChanged(SensorEvent event) {
        if (event.sensor.getType() != Sensor.TYPE_ACCELEROMETER) {
            return;
        }

        float x = event.values[0];
        float y = event.values[1];
        float z = event.values[2];

        // Determine orientation based on accelerometer values
        String newOrientation = determinePhysicalOrientation(x, y, z);

        if (!newOrientation.equals(currentPhysicalOrientation)) {
            currentPhysicalOrientation = newOrientation;

            // Notify listeners of physical orientation change
            if (!newOrientation.equals(lastNotifiedOrientation)) {
                lastNotifiedOrientation = newOrientation;
                final JSObject ret = new JSObject();
                ret.put("type", newOrientation);
                notifyListeners("screenOrientationChange", ret);
            }
        }
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
        // Not needed for orientation detection
    }

    private String determinePhysicalOrientation(float x, float y, float z) {
        final float threshold = 5.0f;

        // X axis: left/right tilt
        // Y axis: forward/backward tilt
        // Z axis: up/down (gravity when flat)
        if (Math.abs(x) > threshold && Math.abs(x) > Math.abs(y)) {
            // Landscape orientation
            return x > 0 ? "landscape-primary" : "landscape-secondary";
        } else if (Math.abs(y) > threshold) {
            // Portrait orientation
            return y > 0 ? "portrait-primary" : "portrait-secondary";
        }
        // Default to current if unclear
        return currentPhysicalOrientation;
    }
}

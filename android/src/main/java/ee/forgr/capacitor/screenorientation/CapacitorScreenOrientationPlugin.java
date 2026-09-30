package ee.forgr.capacitor.screenorientation;

import android.content.Context;
import android.content.pm.ActivityInfo;
import android.content.res.Configuration;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.view.Surface;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Executor;
import org.json.JSONObject;

@CapacitorPlugin(name = "CapacitorScreenOrientation")
public class CapacitorScreenOrientationPlugin extends Plugin implements SensorEventListener {

    private final String pluginVersion = "8.1.21";
    private int currentOrientation;
    private SensorManager sensorManager;
    private Sensor accelerometer;
    private boolean isTrackingMotion = false;
    private String currentPhysicalOrientation = "portrait-primary";
    private String lastNotifiedOrientation = null;
    private FoldLayout foldLayout;
    private Sensor hingeSensor;
    private boolean hingeRegistered = false;
    private Float lastHingeAngle = null;
    private String lastSizeClassKey = null;
    private final List<PluginCall> pendingHingeCalls = new ArrayList<>();
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final SensorEventListener hingeListener = new SensorEventListener() {
        @Override
        public void onSensorChanged(SensorEvent event) {
            if (event.values.length == 0) {
                return;
            }
            float angle = Math.max(0f, Math.min(360f, event.values[0]));
            boolean unchanged = lastHingeAngle != null && Math.abs(lastHingeAngle - angle) < 0.5f;
            lastHingeAngle = angle;
            if (unchanged && pendingHingeCalls.isEmpty()) {
                return;
            }
            JSObject payload = hingePayload(angle);
            notifyListeners("hingeAngleChange", payload);
            resolvePendingHinge(payload);
            if (!hasListeners("hingeAngleChange")) {
                stopHingeTracking();
            }
        }

        @Override
        public void onAccuracyChanged(Sensor sensor, int accuracy) {}
    };

    @Override
    public void load() {
        super.load();
        currentOrientation = getActivity().getResources().getConfiguration().orientation;

        // Initialize sensor manager
        sensorManager = (SensorManager) getActivity().getSystemService(Context.SENSOR_SERVICE);
        if (sensorManager != null) {
            accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                hingeSensor = sensorManager.getDefaultSensor(Sensor.TYPE_HINGE_ANGLE);
            }
        }

        Executor executor = mainHandler::post;
        foldLayout = new FoldLayout(getActivity(), bridge.getWebView(), executor, (state) -> {
            notifyListeners("foldStateChange", state);
            notifySizeClassIfChanged();
        });
        notifySizeClassIfChanged();
    }

    @Override
    protected void handleOnDestroy() {
        stopMotionTracking();
        stopHingeTracking();
        if (foldLayout != null) {
            foldLayout.stop();
        }
        super.handleOnDestroy();
    }

    @Override
    protected void handleOnConfigurationChanged(Configuration newConfig) {
        super.handleOnConfigurationChanged(newConfig);

        notifySizeClassIfChanged();

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

    @PluginMethod(returnType = PluginMethod.RETURN_NONE)
    @Override
    public void addListener(PluginCall call) {
        super.addListener(call);
        String eventName = call.getString("eventName");
        if ("hingeAngleChange".equals(eventName)) {
            mainHandler.post(this::startHingeTracking);
        }
    }

    @PluginMethod(returnType = PluginMethod.RETURN_NONE)
    @Override
    public void removeListener(PluginCall call) {
        super.removeListener(call);
        if (!hasListeners("hingeAngleChange")) {
            mainHandler.post(this::stopHingeTracking);
        }
    }

    @PluginMethod
    @Override
    public void removeAllListeners(PluginCall call) {
        super.removeAllListeners(call);
        mainHandler.post(this::stopHingeTracking);
    }

    @PluginMethod
    public void isDeviceFoldable(PluginCall call) {
        JSObject result = new JSObject();
        result.put("foldable", foldLayout != null && foldLayout.isFoldable());
        result.put("supportsTabletop", foldLayout != null && foldLayout.supportsTabletop());
        call.resolve(result);
    }

    @PluginMethod
    public void getFoldState(PluginCall call) {
        call.resolve(foldLayout == null ? flatFold() : foldLayout.currentState());
    }

    @PluginMethod
    public void getHingeAngle(PluginCall call) {
        mainHandler.post(() -> {
            if (hingeRegistered && lastHingeAngle != null) {
                call.resolve(hingePayload(lastHingeAngle));
                return;
            }
            if (hingeSensor == null) {
                call.resolve(hingePayload(null));
                return;
            }
            pendingHingeCalls.add(call);
            startHingeTracking();
            mainHandler.postDelayed(
                () -> {
                    if (!pendingHingeCalls.contains(call)) {
                        return;
                    }
                    pendingHingeCalls.remove(call);
                    call.resolve(hingePayload(null));
                    if (!hasListeners("hingeAngleChange") && pendingHingeCalls.isEmpty()) {
                        stopHingeTracking();
                    }
                },
                800
            );
        });
    }

    @PluginMethod
    public void getSizeClass(PluginCall call) {
        call.resolve(currentSizeClass());
    }

    @PluginMethod
    public void getReservedRegions(PluginCall call) {
        JSObject result = new JSObject();
        result.put("regions", new org.json.JSONArray());
        call.resolve(result);
    }

    @PluginMethod
    public void getBarPlacement(PluginCall call) {
        JSObject result = new JSObject();
        result.put("verticalBarEdge", JSONObject.NULL);
        result.put("inset", 0);
        call.resolve(result);
    }

    @PluginMethod
    public void setVerticalBarBehavior(PluginCall call) {
        JSObject result = new JSObject();
        result.put("applied", false);
        call.resolve(result);
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

    private JSObject currentSizeClass() {
        if (foldLayout != null) {
            return foldLayout.sizeClass();
        }
        return FoldLayout.sizeClassOf(0f, 0f);
    }

    private void notifySizeClassIfChanged() {
        JSObject sizeClass = currentSizeClass();
        String key = sizeClass.toString();
        if (key.equals(lastSizeClassKey)) {
            return;
        }
        lastSizeClassKey = key;
        notifyListeners("sizeClassChange", sizeClass);
    }

    private void startHingeTracking() {
        if (hingeRegistered || hingeSensor == null || sensorManager == null) {
            return;
        }
        hingeRegistered = true;
        sensorManager.registerListener(hingeListener, hingeSensor, SensorManager.SENSOR_DELAY_NORMAL, mainHandler);
    }

    private void stopHingeTracking() {
        if (!hingeRegistered || sensorManager == null) {
            return;
        }
        hingeRegistered = false;
        sensorManager.unregisterListener(hingeListener);
    }

    private void resolvePendingHinge(JSObject payload) {
        if (pendingHingeCalls.isEmpty()) {
            return;
        }
        List<PluginCall> pending = new ArrayList<>(pendingHingeCalls);
        pendingHingeCalls.clear();
        for (PluginCall call : pending) {
            call.resolve(payload);
        }
    }

    private static JSObject hingePayload(Float angle) {
        JSObject result = new JSObject();
        if (angle == null) {
            result.put("angle", JSONObject.NULL);
        } else {
            result.put("angle", angle.doubleValue());
        }
        return result;
    }

    private static JSObject flatFold() {
        JSObject state = new JSObject();
        state.put("state", "flat");
        state.put("isSeparating", false);
        state.put("posture", "flat");
        return state;
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

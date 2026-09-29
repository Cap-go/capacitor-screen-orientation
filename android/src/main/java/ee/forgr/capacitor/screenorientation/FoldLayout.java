package ee.forgr.capacitor.screenorientation;

import android.app.Activity;
import android.content.pm.PackageManager;
import android.graphics.Rect;
import android.os.Build;
import android.view.View;
import androidx.core.util.Consumer;
import androidx.window.java.layout.WindowInfoTrackerCallbackAdapter;
import androidx.window.layout.DisplayFeature;
import androidx.window.layout.FoldingFeature;
import androidx.window.layout.SupportedPosture;
import androidx.window.layout.WindowInfoTracker;
import androidx.window.layout.WindowLayoutInfo;
import androidx.window.layout.WindowMetricsCalculator;
import com.getcapacitor.JSObject;
import java.util.concurrent.Executor;

/**
 * Reads Jetpack WindowManager fold state for the current activity.
 * The hinge sensor itself stays in the plugin so it can run only while a listener is registered.
 */
final class FoldLayout implements Consumer<WindowLayoutInfo> {

    interface Callback {
        void onFoldState(JSObject state);
    }

    private final Activity activity;
    private final View webView;
    private final WindowInfoTrackerCallbackAdapter adapter;
    private final Executor executor;
    private final Callback callback;
    private final boolean supportsTabletop;
    private JSObject current = flatState();
    private boolean sawFold = false;

    FoldLayout(Activity activity, View webView, Executor executor, Callback callback) {
        this.activity = activity;
        this.webView = webView;
        this.executor = executor;
        this.callback = callback;
        WindowInfoTracker tracker = WindowInfoTracker.getOrCreate(activity);
        this.adapter = new WindowInfoTrackerCallbackAdapter(tracker);
        this.supportsTabletop = supportsTabletop(tracker);
        this.current = toFoldState(firstFold());
        this.adapter.addWindowLayoutInfoListener(activity, executor, this);
    }

    private FoldingFeature firstFold() {
        WindowLayoutInfo info;
        try {
            info = adapter.getCurrentWindowLayoutInfo(activity);
        } catch (UnsupportedOperationException ignored) {
            return null;
        }
        for (DisplayFeature feature : info.getDisplayFeatures()) {
            if (feature instanceof FoldingFeature) {
                sawFold = true;
                return (FoldingFeature) feature;
            }
        }
        return null;
    }

    void stop() {
        adapter.removeWindowLayoutInfoListener(this);
    }

    JSObject currentState() {
        return current;
    }

    boolean isFoldable() {
        if (sawFold || supportsTabletop) {
            return true;
        }
        return (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            activity.getPackageManager().hasSystemFeature(PackageManager.FEATURE_SENSOR_HINGE_ANGLE)
        );
    }

    boolean supportsTabletop() {
        return supportsTabletop;
    }

    JSObject sizeClass() {
        Rect bounds = WindowMetricsCalculator.getOrCreate().computeCurrentWindowMetrics(activity).getBounds();
        float density = activity.getResources().getDisplayMetrics().density;
        return sizeClassOf(bounds.width() / density, bounds.height() / density);
    }

    static JSObject sizeClassOf(float widthDp, float heightDp) {
        JSObject result = new JSObject();
        result.put("horizontal", widthDp >= 600f ? "regular" : "compact");
        result.put("vertical", heightDp >= 480f ? "regular" : "compact");
        result.put("widthClass", widthClass(widthDp));
        result.put("heightClass", heightDp >= 900f ? "expanded" : heightDp >= 480f ? "medium" : "compact");
        return result;
    }

    @Override
    public void accept(WindowLayoutInfo info) {
        FoldingFeature fold = null;
        for (DisplayFeature feature : info.getDisplayFeatures()) {
            if (feature instanceof FoldingFeature) {
                fold = (FoldingFeature) feature;
                break;
            }
        }
        if (fold != null) {
            sawFold = true;
        }
        current = toFoldState(fold);
        callback.onFoldState(current);
    }

    private JSObject toFoldState(FoldingFeature fold) {
        if (fold == null) {
            return flatState();
        }

        float density = activity.getResources().getDisplayMetrics().density;
        int[] offset = new int[2];
        webView.getLocationInWindow(offset);
        JSObject bounds = boundsOf(fold.getBounds(), density, offset[0], offset[1]);

        boolean halfOpened = FoldingFeature.State.HALF_OPENED.equals(fold.getState());
        boolean horizontal = FoldingFeature.Orientation.HORIZONTAL.equals(fold.getOrientation());

        JSObject state = new JSObject();
        state.put("state", halfOpened ? "half-opened" : "flat");
        state.put("isSeparating", fold.isSeparating());
        state.put("posture", !halfOpened ? "flat" : horizontal ? "tabletop" : "book");
        state.put("hingeOrientation", horizontal ? "horizontal" : "vertical");
        state.put("hingeBounds", bounds);
        if (FoldingFeature.OcclusionType.FULL.equals(fold.getOcclusionType())) {
            state.put("occludedBounds", bounds);
        }
        return state;
    }

    private static JSObject boundsOf(Rect rect, float density, int offsetX, int offsetY) {
        JSObject bounds = new JSObject();
        bounds.put("x", Math.round((rect.left - offsetX) / density));
        bounds.put("y", Math.round((rect.top - offsetY) / density));
        bounds.put("width", Math.round(rect.width() / density));
        bounds.put("height", Math.round(rect.height() / density));
        return bounds;
    }

    private static JSObject flatState() {
        JSObject state = new JSObject();
        state.put("state", "flat");
        state.put("isSeparating", false);
        state.put("posture", "flat");
        return state;
    }

    private static String widthClass(float widthDp) {
        if (widthDp >= 1600f) return "extraLarge";
        if (widthDp >= 1200f) return "large";
        if (widthDp >= 840f) return "expanded";
        if (widthDp >= 600f) return "medium";
        return "compact";
    }

    private static boolean supportsTabletop(WindowInfoTracker tracker) {
        try {
            return tracker.getSupportedPostures().contains(SupportedPosture.TABLETOP);
        } catch (RuntimeException ignored) {
            return false;
        }
    }
}

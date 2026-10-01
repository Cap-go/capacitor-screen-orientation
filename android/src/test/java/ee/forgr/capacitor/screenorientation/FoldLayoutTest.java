package ee.forgr.capacitor.screenorientation;

import static org.junit.Assert.assertEquals;

import com.getcapacitor.JSObject;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 35)
public class FoldLayoutTest {

    @Test
    public void sizeClassOf_usesMaterialBreakpoints() {
        JSObject phone = FoldLayout.sizeClassOf(400f, 800f);
        assertEquals("compact", phone.getString("widthClass"));
        assertEquals("compact", phone.getString("horizontal"));

        JSObject tablet = FoldLayout.sizeClassOf(700f, 900f);
        assertEquals("medium", tablet.getString("widthClass"));
        assertEquals("regular", tablet.getString("horizontal"));
        assertEquals("expanded", tablet.getString("heightClass"));
    }
}

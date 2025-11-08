/**
 * Trio Watchface Background Drawable
 * 
 * Renders watchface background with user-configurable color.
 * Defined in layout XML and drawn before other UI elements.
 * 
 * CONFIGURATION:
 * Background color controlled via watchface settings:
 * - Black (0x000000) - Default
 * - Dark Gray (0x555555)
 * - Light Gray (0xAAAAAA)
 * - White (0xFFFFFF)
 * 
 * Property key: "BackgroundColor"
 * See properties.xml and settings.xml for configuration details.
 * 
 * @author Trio Development Team
 * @version 2.0
 */

import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class Background extends WatchUi.Drawable {

    /**
     * Constructor
     * 
     * Initializes drawable with "Background" identifier for layout binding.
     */
    function initialize() {
        var dictionary = {
            :identifier => "Background"
        };

        Drawable.initialize(dictionary);
    }

    /**
     * Draw handler
     * 
     * Fills entire screen with user-selected background color.
     * Called by layout system before other elements are rendered.
     * 
     * @param dc Drawing context for rendering operations
     */
    function draw(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, getApp().getProperty("BackgroundColor") as Number);
        dc.clear();
    }
}

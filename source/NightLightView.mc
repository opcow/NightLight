using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Time as T;
using Toybox.Time.Gregorian as Greg;
using Toybox.Application as App;
using Toybox.Math as Math;
using Toybox.System as Sys;

var g_dunits, g_sunits, g_distLabel, g_speedLabel;

class NightLightView extends Ui.DataField {

    hidden var m_value;
    hidden var m_onTimeText, m_offTimeText;
	hidden var bl, sunsetMoment, sunriseMoment;
	hidden var m_displayFuncs = new [8];
	hidden var m_funcNames = new [8];
	hidden var m_currentFunc = 0;
	
	enum {
		timeofday,
		speed,
		distance,
		cadence,
		heartrate,
		ascent,
		descent,
		altitude
	}

	function initTime () {

		//Toybox.Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));

		var stopOffset, startOffset; //in minutes
		var zeroTime = { :second => 0, :hour => 0, :minute => 0, :year => 0, :month => 0, :day => 0 };
		var tzOffset = Sys.getClockTime().timeZoneOffset / 60; //for converting to local time
		var latitude, longitude;
		stopOffset = App.getApp().getProperty("PROP_STOP_OFFSET");
		startOffset = App.getApp().getProperty("PROP_START_OFFSET");
		m_currentFunc = App.getApp().getProperty("PROP_FUNC");
		latitude = App.getApp().getProperty("PROP_LATITUDE");
		longitude = App.getApp().getProperty("PROP_LONGITUDE");
		
		var now = Greg.info(T.now(), T.FORMAT_SHORT);
        var jd = julianDay(now.year, now.month, now.day);
        
        var ss = Math.round(calcSunsetUTC(jd, latitude.toDouble(), longitude.toDouble()) + tzOffset);
        var today = T.today();
        var dur = Greg.duration(zeroTime);
        dur.initialize((ss + startOffset) * 60);
        sunsetMoment = today.add(dur);
        ss = Math.round(calcSunriseUTC(jd, latitude.toDouble(), longitude.toDouble()) + tzOffset);
        dur.initialize((ss + stopOffset) * 60);
        sunriseMoment = today.add(dur);
	}

	function initDisplayFuncs() {
		var funcs = new DisplayFuncs();
        m_displayFuncs[timeofday] = funcs.method(:doTime);
        m_displayFuncs[speed] = funcs.method(:doSpeed);
        m_displayFuncs[distance] = funcs.method(:doDistance);
        m_displayFuncs[cadence] = funcs.method(:doCadence);
        m_displayFuncs[heartrate] = funcs.method(:doHeartrate);
        m_displayFuncs[ascent] = funcs.method(:doAscent);
        m_displayFuncs[descent] = funcs.method(:doDescent);
        m_displayFuncs[altitude] = funcs.method(:doAltitude);
        
        m_funcNames[timeofday] = Ui.loadResource(Rez.Strings.functionLabel_0);
        m_funcNames[speed] = Ui.loadResource(Rez.Strings.functionLabel_1);
        m_funcNames[distance] = Ui.loadResource(Rez.Strings.functionLabel_2);
        m_funcNames[cadence] = Ui.loadResource(Rez.Strings.functionLabel_3);
        m_funcNames[heartrate] = Ui.loadResource(Rez.Strings.functionLabel_4);
        m_funcNames[ascent] = Ui.loadResource(Rez.Strings.functionLabel_5);
        m_funcNames[descent] = Ui.loadResource(Rez.Strings.functionLabel_6);
        m_funcNames[altitude] = Ui.loadResource(Rez.Strings.functionLabel_7);
	}
	
    function initialize() {
        m_value = 0.0f;
        initTime();
        bl = 9;
        initDisplayFuncs();
        DataField.initialize();
    }

    // Set your layout here. Anytime the size of obscurity of
    // the draw context is changed this will be called.
    function onLayout(dc) {
    	View.setLayout(Rez.Layouts.MainLayout(dc));
        g_dunits = Sys.getDeviceSettings().distanceUnits;
		if (g_dunits == Sys.UNIT_STATUTE) {
           	 g_distLabel= Ui.loadResource(Rez.Strings.mph);
           	 g_speedLabel= Ui.loadResource(Rez.Strings.miles);
        } else {
			g_distLabel= Ui.loadResource(Rez.Strings.kmh);
			g_speedLabel= Ui.loadResource(Rez.Strings.kilos);
        }
        var labelView = View.findDrawableById("label");
        labelView.locY = labelView.locY - 16;
        labelView.locX = labelView.locX + 14;
        var valueView = View.findDrawableById("value");
        valueView.locY = valueView.locY + 10;
        valueView.locX = valueView.locX + 14;

        //View.findDrawableById("label").setText(Rez.Strings.label);
        View.findDrawableById("label").setText(m_funcNames[m_currentFunc]);
        m_onTimeText = View.findDrawableById("onTimeInfo");
        m_onTimeText.locY = m_onTimeText.locY + 2;
        m_offTimeText = View.findDrawableById("offTimeInfo");
        m_offTimeText.locY = m_offTimeText.locY + 16;
        m_onTimeText.setBackgroundColor(Gfx.COLOR_BLACK);
        m_offTimeText.setBackgroundColor(Gfx.COLOR_WHITE);

        m_onTimeText.setText(makeTimeString(sunsetMoment));
        m_offTimeText.setText(makeTimeString(sunriseMoment));
        return true;
    }

    // The given info object contains all the current workout
    // information. Calculate a value and save it locally in this method.
    function compute(info) {
    
        var m_now = T.now();
        // Sys.println(makeTimeString(m_now) + "  " + makeTimeString(sunriseMoment));
        if (info.timerState != 0 && (sunsetMoment.lessThan(m_now) || sunriseMoment.greaterThan(m_now)))
        {
	        if (bl <= 9) {
    	    	bl++;
        	}
        	else {
                Toybox.Attention.backlight(true);
                bl = 0;
        	}
        }    
        // See Activity.Info in the documentation for available information.
        m_value = m_displayFuncs[m_currentFunc].invoke(info);
    }

    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc) {
        // Set the background color
        View.findDrawableById("Background").setColor(getBackgroundColor());

        // Set the foreground color and value
        var value = View.findDrawableById("value");
        if (getBackgroundColor() == Gfx.COLOR_BLACK) {
            value.setColor(Gfx.COLOR_WHITE);
        } else {
            value.setColor(Gfx.COLOR_BLACK);
        }
        //value.setText(m_value.format("%.2f"));
		value.setText(m_value);
		
        // Call parent's onUpdate(dc) to redraw the layout
        View.onUpdate(dc);
    }
}

function makeTimeString(d) {
	var t = Greg.info(d, T.FORMAT_SHORT);
	var h = t.hour;
	
	if (!Sys.getDeviceSettings().is24Hour && h > 12) {
		h -= 12;
	}
	return h.format("%02d") + ":" + t.min.format("%02d");
}


class DisplayFuncs
{
	function doTime(info) {
		var t = Greg.info(T.now(), T.FORMAT_SHORT);
		var h = t.hour;
		if (!Sys.getDeviceSettings().is24Hour && h > 12) {
			h -= 12;
		}
		return h.format("%02d") + ":" + t.min.format("%02d") + ":" + t.sec.format("%02d");
	}

	function doSpeed(info) {
		var factor;
		var u;

		if (g_dunits == Sys.UNIT_STATUTE) {
			factor  = 2.2356;
			u = " M/H";
		} else {
			factor = 3.6;
			u = " K/H";
		}
		if(!(info has :currentSpeed) || info.currentSpeed == null){
	        return "0.0" + g_distLabel;
	    } 
		return (info.currentSpeed * factor).format("%.1f") + g_distLabel;
	}

	function doDistance(info) {
		if(info has :elapsedDistance && info.elapsedDistance != null){
	        return info.elapsedDistance.format("%.1f");
	    }
		return "0.0";
	}

	function doCadence(info) {
		if(info has :currentCadence && info.currentCadence != null){
	        return info.currentCadence.format("%d");
	    }
		return "0";
	}

	function doHeartrate(info) {
		if(info has :currentHeartRate && info.currentHeartRate != null){
	        return info.currentHeartRate.format("%d");
	    }
        return "0";
	}

	function doAscent(info) {
		return info.totalAscent.format("%.1f");
	}

	function doDescent(info) {
		return info.totalDescent.format("%.1f");
	}

	function doAltitude(info) {
		return info.altitude.format("%.1f");
	}
}
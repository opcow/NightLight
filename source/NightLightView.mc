// Copyright (GPL) 2017   Mitch Crane mitch.crane@gmail.com

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Time as T;
using Toybox.Time.Gregorian as Greg;
using Toybox.Application as App;
using Toybox.Math as Math;
using Toybox.System as Sys;
using Toybox.Position;
using Toybox.Test;

var g_dunits, g_sunits, g_distLabel, g_speedLabel;
var app = App.getApp();

class NightLightView extends Ui.DataField {

    hidden var mValue;
    hidden var m_onTimeText, m_offTimeText;
	hidden var mBacklightCounter, mSunsetMoment, mSunriseMoment;
	hidden var mDisplayFuncs = new [8];
	hidden var mFuncNames = new [8];
	hidden var mCurrentFunc = 0;
	var mLastCheck;
	var mThrottle = 10;

	
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

	function initInfo() {
		//Toybox.Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
		var today = T.today();
		var dawn = new T.Duration(6 * 60 * 60);
		var dusk = new T.Duration(18 * 60 * 60);
		mSunriseMoment = today.add(dawn);
		mSunsetMoment = today.add(dusk);
		mLastCheck = T.now();
	}

	function setSunInfo() {
		var stopOffset, startOffset; //in minutes
		var zeroTime = { :second => 0, :hour => 0, :minute => 0, :year => 0, :month => 0, :day => 0 };
		var tzOffset = Sys.getClockTime().timeZoneOffset / 60; //for converting to local time

		stopOffset = App.getApp().getProperty("PROP_STOP_OFFSET");
		if (stopOffset == null) {
			stopOffset = -10;
			App.getApp().setProperty("PROP_STOP_OFFSET", stopOffset);
		}
		startOffset = App.getApp().getProperty("PROP_START_OFFSET");
		if (startOffset == null) {
			startOffset = 10;
			App.getApp().setProperty("PROP_START_OFFSET", startOffset);
		}
		mCurrentFunc = App.getApp().getProperty("PROP_FUNC");
		if (mCurrentFunc == null) {
			mCurrentFunc = 0;
			App.getApp().setProperty("PROP_FUNC", mCurrentFunc);
		}


		var now = Greg.info(T.now(), T.FORMAT_SHORT);
        var jd = julianDay(now.year, now.month, now.day);
        
        var ss = Math.round(calcSunsetUTC(jd, $.gLatitude.toDouble(), $.gLongitude.toDouble()) + tzOffset);
        var today = T.today();
        var dur = Greg.duration(zeroTime);
        dur.initialize((ss + startOffset) * 60);
        mSunsetMoment = today.add(dur);

        ss = Math.round(calcSunriseUTC(jd, $.gLatitude.toDouble(), $.gLongitude.toDouble()) + tzOffset);
        dur.initialize((ss + stopOffset) * 60);
        mSunriseMoment = today.add(dur);
	}

	function initDisplayFuncs() {
		var funcs = new DisplayFuncs();
        mDisplayFuncs[timeofday] = funcs.method(:doTime);
        mDisplayFuncs[speed] = funcs.method(:doSpeed);
        mDisplayFuncs[distance] = funcs.method(:doDistance);
        mDisplayFuncs[cadence] = funcs.method(:doCadence);
        mDisplayFuncs[heartrate] = funcs.method(:doHeartrate);
        mDisplayFuncs[ascent] = funcs.method(:doAscent);
        mDisplayFuncs[descent] = funcs.method(:doDescent);
        mDisplayFuncs[altitude] = funcs.method(:doAltitude);
        
        mFuncNames[timeofday] = Ui.loadResource(Rez.Strings.functionLabel_0);
        mFuncNames[speed] = Ui.loadResource(Rez.Strings.functionLabel_1);
        mFuncNames[distance] = Ui.loadResource(Rez.Strings.functionLabel_2);
        mFuncNames[cadence] = Ui.loadResource(Rez.Strings.functionLabel_3);
        mFuncNames[heartrate] = Ui.loadResource(Rez.Strings.functionLabel_4);
        mFuncNames[ascent] = Ui.loadResource(Rez.Strings.functionLabel_5);
        mFuncNames[descent] = Ui.loadResource(Rez.Strings.functionLabel_6);
        mFuncNames[altitude] = Ui.loadResource(Rez.Strings.functionLabel_7);
	}
	
    function initialize() {
        mValue = " ";
        initInfo();
        mBacklightCounter = 9;
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
        View.findDrawableById("label").setText(mFuncNames[mCurrentFunc]);
        m_onTimeText = View.findDrawableById("onTimeInfo");
        m_onTimeText.locY = m_onTimeText.locY + 2;
        m_offTimeText = View.findDrawableById("offTimeInfo");
        m_offTimeText.locY = m_offTimeText.locY + 16;
        m_onTimeText.setBackgroundColor(Gfx.COLOR_BLACK);
        m_offTimeText.setBackgroundColor(Gfx.COLOR_WHITE);

        m_onTimeText.setText(makeTimeString(mSunsetMoment));
        m_offTimeText.setText(makeTimeString(mSunriseMoment));
        return true;
    }

	// The given info object contains all the current workout
    // information. Calculate a value and save it locally in this method.
    function compute(info) {
    
        var mNow = T.now();
		var delta = mNow.subtract(mLastCheck).value();
		if (mThrottle <= delta) {
			var info = getLoc();
			if (info[2] >= Position.QUALITY_USABLE) {
				$.gLatitude = info[0];
				$.gLongitude = info[1];
				setSunInfo();
		        m_onTimeText.setText(makeTimeString(mSunsetMoment));
	    	    m_offTimeText.setText(makeTimeString(mSunriseMoment));
				mThrottle = 300; // only update every 5 minutes after getting location 
			} else {
				mThrottle = 30; // try every 30 secs to get usable accuracy
			}
			mLastCheck = T.now();
		} 

        if (info.timerState != 0 && (mSunsetMoment.lessThan(mNow) || mSunriseMoment.greaterThan(mNow)))
        {
	        if (mBacklightCounter <= 9) {
    	    	mBacklightCounter++;
        	}
        	else {
                Toybox.Attention.backlight(true);
                mBacklightCounter = 0;
        	}
        }    
        // See Activity.Info in the documentation for available information.
        mValue = mDisplayFuncs[mCurrentFunc].invoke(info);
    }

    // Display the value you computed here. This will be called
    // once a second when the data field is visible.
    function onUpdate(dc) {
        // Set the background color
        View.findDrawableById("Background").setColor(getBackgroundColor());

        // Set the foreground color and value
        var value = View.findDrawableById("value");
        if (value != null && mValue != null) {
	        if (getBackgroundColor() == Gfx.COLOR_BLACK) {
	            value.setColor(Gfx.COLOR_WHITE);
	        } else {
	            value.setColor(Gfx.COLOR_BLACK);
	        }
			value.setText(mValue);
		}

        // Call parent's onUpdate(dc) to redraw the layout
        View.onUpdate(dc);
    }
}

function getLoc() {
	var info = Position.getInfo();
	var loc = info.position.toDegrees();
	if (loc[1] <= 0) {
		loc[1] = -1 * loc[1];
	} else {
		loc[1] = 360-loc[1];
	}
	return [loc[0], loc[1], info.accuracy];
}

function printLoc() {
	Sys.println("Posistion: " + $.gLatitude + ", " + $.gLongitude);
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
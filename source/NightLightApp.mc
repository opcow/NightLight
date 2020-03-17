// Copyright (GPL) 2017   Mitch Crane mitch.crane@gmail.com

using Toybox.Application as App;
using Toybox.Background;
using Toybox.WatchUi as Ui;

var gLatitude = 0;
var gLongitude = 0;

class NightLightApp extends App.AppBase {

	//hidden var m_view;
	
    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    }

    //! Return the initial view of your application here
    function getInitialView() {
        return [ new NightLightView()];
    }
}

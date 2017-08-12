// Copyright (GPL) 2017   Mitch Crane mitch.crane@gmail.com

using Toybox.Application as App;

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
    	//m_view = new NightLightView();
        return [ new NightLightView() ];
    }
    
//   function onSettingsChanged() {
//    	m_view.method(:setFunctionLabel).invoke();
//    	m_view.method(:initialize).invoke();
//    }

}
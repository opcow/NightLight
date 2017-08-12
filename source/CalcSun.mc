/* Copyright (GPL) 2004   Mike Chirico mchirico@comcast.net

   Program adapted by mitch.crane@gmail.com
*/

using Toybox.Math as Math;

function julianDay(K, M, I)
{
	return 367 * K - Math.floor((7 * (K + Math.floor((M + 9) / 12))) / 4) + Math.floor((275 * M) / 9) + I + 1721013.5;
}

function calcMeanObliquityOfEcliptic(t)
{
	var seconds = 21.448d - t*(46.8150d + t*(0.00059d - t*(0.001813d)));
	return 23.0d + (26.0d + (seconds / 60.0d)) / 60.0d;
}

function calcGeomMeanLongSun(t)
{
	var L = 280.46646d + t * (36000.76983d + 0.0003032d * t);
	while (L.toNumber() > 360)
	{
		L -= 360.0d;
	}
	while (L < 0)
	{
		L += 360.0d;
	}
	return L;
}

function calcObliquityCorrection(t)
{
	var e0 = calcMeanObliquityOfEcliptic(t);
	var omega = 125.04d - 1934.136d * t;
	return e0 + 0.00256d * Math.cos(Math.toRadians(omega));
}

function calcEccentricityEarthOrbit(t)
{
	return 0.016708634d - t * (0.000042037d + 0.0000001267d * t);
}

function calcGeomMeanAnomalySun(t)
{
	return 357.52911d + t * (35999.05029d - 0.0001537d * t);
}

function calcEquationOfTime(t)
{
	var epsilon = calcObliquityCorrection(t);
	var  l0 = calcGeomMeanLongSun(t);
	var e = calcEccentricityEarthOrbit(t);
	var m = calcGeomMeanAnomalySun(t);
	var y = Math.tan(Math.toRadians(epsilon) / 2.0d);
	y *= y;
	var sin2l0 = Math.sin(2.0d * Math.toRadians(l0));
	var sinm = Math.sin(Math.toRadians(m));
	var cos2l0 = Math.cos(2.0d * Math.toRadians(l0));
	var sin4l0 = Math.sin(4.0d * Math.toRadians(l0));
	var sin2m = Math.sin(2.0d * Math.toRadians(m));
	var Etime = y * sin2l0 - 2.0d * e * sinm + 4.0d * e * y * sinm * cos2l0
		- 0.5d * y * y * sin4l0 - 1.25d * e * e * sin2m;

	return Math.toDegrees(Etime)*4.0d;
}

function calcTimeJulianCent(jd)
{
	return (jd - 2451545.0d) / 36525.0d;
}

function calcSunTrueLong(t)
{
	var l0 = calcGeomMeanLongSun(t);
	var c = calcSunEqOfCenter(t);

	return l0 + c;
}

function calcSunApparentLong(t)
{
	var o = calcSunTrueLong(t);

	var  omega = 125.04d - 1934.136d * t;
	return o - 0.00569d - 0.00478d * Math.sin(Math.toRadians(omega));
}

function calcSunDeclination(t)
{
	var e = calcObliquityCorrection(t);
	var lambda = calcSunApparentLong(t);

	var sint = Math.sin(Math.toRadians(e)) * Math.sin(Math.toRadians(lambda));
	return Math.toDegrees(Math.asin(sint));
}

function calcHourAngleSunrise(lat, solarDec)
{
	var latRad = Math.toRadians(lat);
	var sdRad = Math.toRadians(solarDec);

	return(Math.acos(Math.cos(Math.toRadians(90.833d)) / (Math.cos(latRad)*Math.cos(sdRad)) - Math.tan(latRad) * Math.tan(sdRad)));
}

function calcHourAngleSunset(lat, solarDec)
{
	var latRad = Math.toRadians(lat);
	var sdRad = Math.toRadians(solarDec);

	return -(Math.acos(Math.cos(Math.toRadians(90.833d)) / (Math.cos(latRad)*Math.cos(sdRad)) - Math.tan(latRad) * Math.tan(sdRad)));
}

function calcJDFromJulianCent(t)
{
	return t * 36525.0d + 2451545.0d;
}

function calcSunEqOfCenter(t)
{
	var m = calcGeomMeanAnomalySun(t);

	var mrad = Math.toRadians(m);
	var sinm = Math.sin(mrad);
	var sin2m = Math.sin(mrad + mrad);
	var sin3m = Math.sin(mrad + mrad + mrad);

	return sinm * (1.914602d - t * (0.004817d + 0.000014d * t)) + sin2m * (0.019993d - 0.000101d * t) + sin3m * 0.000289d;
}

function calcSunriseUTC(JD, latitude, longitude)
{
	var t = calcTimeJulianCent(JD);

	// first pass
	var  eqTime = calcEquationOfTime(t);
	var  solarDec = calcSunDeclination(t);
	var  hourAngle = calcHourAngleSunrise(latitude, solarDec);
	var  delta = longitude - Math.toDegrees(hourAngle);
	var  timeDiff = 4 * delta;
	var  timeUTC = 720 + timeDiff - eqTime;	
	var  newt = calcTimeJulianCent(calcJDFromJulianCent(t) + timeUTC / 1440.0);

	eqTime = calcEquationOfTime(newt);
	solarDec = calcSunDeclination(newt);

	hourAngle = calcHourAngleSunrise(latitude, solarDec);
	delta = longitude - Math.toDegrees(hourAngle);
	timeDiff = 4 * delta;
	return 720 + timeDiff - eqTime;
}

function calcSunsetUTC(JD, latitude, longitude)
{
	var t = calcTimeJulianCent(JD);

	// first pass
	var  eqTime = calcEquationOfTime(t);
	var  solarDec = calcSunDeclination(t);
	var  hourAngle = calcHourAngleSunset(latitude, solarDec);
	var  delta = longitude - Math.toDegrees(hourAngle);
	var  timeDiff = 4 * delta;
	var  timeUTC = 720 + timeDiff - eqTime;	
	var  newt = calcTimeJulianCent(calcJDFromJulianCent(t) + timeUTC / 1440.0);

	eqTime = calcEquationOfTime(newt);
	solarDec = calcSunDeclination(newt);

	hourAngle = calcHourAngleSunset(latitude, solarDec);
	delta = longitude - Math.toDegrees(hourAngle);
	timeDiff = 4 * delta;
	return 720 + timeDiff - eqTime;
}
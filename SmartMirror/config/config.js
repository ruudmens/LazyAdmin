/* MagicMirror² Config Sample
 *
 * By Michael Teeuw https://michaelteeuw.nl
 * MIT Licensed.
 *
 * For more information on how you can configure this file
 * see https://docs.magicmirror.builders/configuration/introduction.html
 * and https://docs.magicmirror.builders/modules/configuration.html
 */
let config = {
	address: "0.0.0.0", 	// Address to listen on, can be:
							// - "localhost", "127.0.0.1", "::1" to listen on loopback interface
							// - another specific IPv4/6 to listen on a specific interface
							// - "0.0.0.0", "::" to listen on any interface
							// Default, when address config is left out or empty, is "localhost"
	port: 8080,
	basePath: "/", 	// The URL path where MagicMirror² is hosted. If you are using a Reverse proxy
					// you must set the sub path here. basePath must end with a /
	ipWhitelist: ["127.0.0.1", "::ffff:127.0.0.1", "::1", "192.168.1.22"], 	// Set [] to allow all IP addresses
															// or add a specific IPv4 of 192.168.1.5 :
															// ["127.0.0.1", "::ffff:127.0.0.1", "::1", "::ffff:192.168.1.5"],
															// or IPv4 range of 192.168.3.0 --> 192.168.3.15 use CIDR format :
															// ["127.0.0.1", "::ffff:127.0.0.1", "::1", "::ffff:192.168.3.0/28"],

	useHttps: false, 		// Support HTTPS or not, default "false" will use HTTP
	httpsPrivateKey: "", 	// HTTPS private key path, only require when useHttps is true
	httpsCertificate: "", 	// HTTPS Certificate path, only require when useHttps is true

	language: "en",
	locale: "en-US",
	logLevel: ["INFO", "LOG", "WARN", "ERROR"], // Add "DEBUG" for even more logging
	timeFormat: 24,
	units: "metric",
	// serverOnly:  true/false/"local" ,
	// local for armv6l processors, default
	//   starts serveronly and then starts chrome browser
	// false, default for all NON-armv6l devices
	// true, force serveronly mode, because you want to.. no UI on this device

	modules: [
		{
			module: "alert",
		},
		{
			module: "updatenotification",
			position: "top_bar"
		},
		{
			module: "clock",
			position: "top_right",
			config: {
				displaySeconds: false,
				dateFormat: "dddd, MMMM Do",
			}
		},
		{
			module: "MMM-OpenWeatherMapForecast",
			header: false,
			position: "top_left",
			classes: "default everyone",
			disabled: false,
			config: {
				apikey: "<api-key>",
				latitude: "52.291610",
				longitude: "4.578690",
				updateInterval: "10", 
				units: "metric",
				showSummary: true,
				showForecastTableColumnHeaderIcons: false,
				showHourlyForecast: true,
				showDailyForecast: false,
				forecastLayout: "tiled",
				mainIconset: "6oa",
				iconset: "1c",
				animateMainIconOnly: true,
				concise: true,
				label_high: "",
				label_low: "",
				label_timeFormat: "k[h]",
		}
		},
		{
			module: 'MMM-google-route',
			position: 'bottom_left',
			header: "Travel Time",
			classes: 'morning_scheduler',
			config: {
					key: '<api-key>',
					directionsRequest:{
							origin: '<home-address>',
							destination: '<office-address>'
					},
					refreshPeriod: 10,
					showMap: false,
					showAge: false,
					width: "500px",
			}
		},
		{
			module: 'MMM-google-route',
			position: 'bottom_left',
			classes: 'morning_scheduler',
			config: {
					key: '<api-key>',
					directionsRequest:{
						origin: '<home-address>',
						destination: '<office-address-2>'
					},
					refreshPeriod: 10,
					showMap: false,
					showAge: false,
					width: "500px",
			}
		},
{
  module: "MMM-Jast",
  header:  "Stocks",
  position: "bottom_left",
  classes: 'restoftheday_scheduler',
  config: {
    currencyStyle: "code", // One of ["code", "symbol", "name"]
    fadeSpeedInSeconds: 3.5,
    lastUpdateFormat: "HH:mm",
    maxChangeAge: 1 * 24 * 60 * 60 * 1000,
    numberDecimalsPercentages: 1,
    numberDecimalsValues: 2,
    scroll: "none", // One of ["none", "vertical", "horizontal"]
    showColors: false,
    showCurrency: false,
    showChangePercent: true,
    showChangeValue: false,
    showChangeValueCurrency: false,
    showHiddenStocks: false,
    showLastUpdate: false,
    showPortfolioValue: false,
    showPortfolioGrowthPercent: false,
    showPortfolioGrowth: false,
    updateIntervalInSeconds: 300,
    useGrouping: false,
    virtualHorizontalMultiplier: 2,
    stocks: [
      { name: "S&P 500 InfoTech", symbol: "QDVE.de"},
      { name: "Vanguard All-World", symbol: "VWCE.de"}
    ]
  }
},
		{
				module: 'MMM-GoogleCalendar',
				header: "Upcoming appointments",
				position: "bottom_right",
				config: {
						calendars: [
								{
									symbol: "calendar-day",
									calendarID: "<calendar-id>"
								},        
						],
						maximumEntries: 5,
						maximumNumberOfDays: 3,
						maxTitleLength: 20,
						displaySymbol: false,
						fetchInterval: 3600000, // once per hour
						hideOngoing: true,
						dateFormat: 'ddd',
				}
		},
{
  module: 'MMM-ModuleScheduler',
  config: {
    notification_schedule: [
        // Refresh the route every minute from 6 AM to 9:00 AM, monday to friday
        { notification: 'MMM-google-route/refresh', schedule: '* 6,9 * * 1-5' }
    ],
    
    global_schedule: [
      // SHOW MODULES WITH THE CLASS 'morning_scheduler' AT 06:00 AND HIDE AT 09:00 EVERY DAY
      {from: '0 6 * * *', to: '0 9 * * *', groupClass: 'morning_scheduler'},
      // SHOW MODULES WITH THE CLASS 'morning_scheduler' AT 09:00 AND HIDE AT 06:00 EVERY DAY
      {from: '0 9 * * *', to: '0 6 * * *', groupClass: 'restoftheday_scheduler'}
    ]
  }
},
	]
};

/*************** DO NOT EDIT THE LINE BELOW ***************/
if (typeof module !== "undefined") {module.exports = config;}

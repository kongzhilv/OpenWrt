'use strict';
'require baseclass';
'require fs';
'require rpc';
'require uci';

var callGetUnixtime = rpc.declare({
	object: 'luci',
	method: 'getUnixtime',
	expect: { result: 0 }
});

var callLuciVersion = rpc.declare({
	object: 'luci',
	method: 'getVersion'
});

var callSystemBoard = rpc.declare({
	object: 'system',
	method: 'board'
});

var callSystemInfo = rpc.declare({
	object: 'system',
	method: 'info'
});

function formatTemp(v) {
	var n = parseInt(v, 10);
	if (isNaN(n))
		return null;

	/* sysfs temp is usually millidegree Celsius */
	if (Math.abs(n) >= 1000)
		return (n / 1000).toFixed(1) + '°C';

	return n.toFixed(1) + '°C';
}

function readFirstExisting(paths) {
	var tasks = paths.map(function(p) {
		return L.resolveDefault(fs.trimmed(p), null);
	});

	return Promise.all(tasks).then(function(vals) {
		for (var i = 0; i < vals.length; i++) {
			if (vals[i] != null && vals[i] !== '')
				return vals[i];
		}
		return null;
	});
}

function readHwmonTemps() {
	return L.resolveDefault(fs.list('/sys/class/hwmon'), []).then(function(entries) {
		var tasks = entries.map(function(e) {
			var dir = '/sys/class/hwmon/' + e.name;
			return Promise.all([
				L.resolveDefault(fs.trimmed(dir + '/name'), null),
				L.resolveDefault(fs.trimmed(dir + '/temp1_input'), null)
			]).then(function(res) {
				return {
					name: res[0],
					temp: res[1]
				};
			});
		});

		return Promise.all(tasks).then(function(items) {
			var cpu = null, wifi0 = null, wifi1 = null;

			for (var i = 0; i < items.length; i++) {
				var n = items[i].name, t = items[i].temp;
				if (!n || !t)
					continue;

				if (n === 'cpu_thermal' || n === 'cpu-thermal')
					cpu = t;
				else if (n === 'mt7915_phy0' || n === 'mt76_phy0')
					wifi0 = t;
				else if (n === 'mt7915_phy1' || n === 'mt76_phy1')
					wifi1 = t;
			}

			return {
				cpu: cpu,
				wifi0: wifi0,
				wifi1: wifi1
			};
		});
	});
}

return baseclass.extend({
	title: _('System'),

	load: function() {
		return Promise.all([
			L.resolveDefault(callSystemBoard(), {}),
			L.resolveDefault(callSystemInfo(), {}),
			L.resolveDefault(callLuciVersion(), { revision: _('unknown version'), branch: 'LuCI' }),
			L.resolveDefault(callGetUnixtime(), 0),
			uci.load('system'),
			readHwmonTemps(),
			readFirstExisting([
				'/sys/class/thermal/thermal_zone0/temp'
			])
		]);
	},

	render: function(data) {
		var boardinfo   = data[0],
		    systeminfo  = data[1],
		    luciversion = data[2],
		    unixtime    = data[3],
		    hwtemps     = data[5],
		    thermalCpu  = data[6];

		luciversion = luciversion.branch + ' ' + luciversion.revision;

		var datestr = null;

		if (unixtime) {
			var date = new Date(unixtime * 1000),
				zn = uci.get('system', '@system[0]', 'zonename')?.replaceAll(' ', '_') || 'UTC',
				ts = uci.get('system', '@system[0]', 'clock_timestyle') || 0,
				hc = uci.get('system', '@system[0]', 'clock_hourcycle') || 0;

			datestr = new Intl.DateTimeFormat(undefined, {
				dateStyle: 'medium',
				timeStyle: (ts == 0) ? 'long' : 'full',
				hourCycle: (hc == 0) ? undefined : hc,
				timeZone: zn
			}).format(date);
		}

		var cpuTemp = formatTemp(hwtemps?.cpu || thermalCpu);
		var wifi0Temp = formatTemp(hwtemps?.wifi0);
		var wifi1Temp = formatTemp(hwtemps?.wifi1);

		var tempLine = null;
		if (cpuTemp || wifi0Temp || wifi1Temp) {
			var wifiPart = null;

			if (wifi0Temp && wifi1Temp)
				wifiPart = wifi0Temp + '/' + wifi1Temp;
			else if (wifi0Temp)
				wifiPart = wifi0Temp;
			else if (wifi1Temp)
				wifiPart = wifi1Temp;

			if (cpuTemp && wifiPart)
				tempLine = 'CPU: ' + cpuTemp + ', WiFi: ' + wifiPart;
			else if (cpuTemp)
				tempLine = 'CPU: ' + cpuTemp;
			else
				tempLine = 'WiFi: ' + wifiPart;
		}

		var fields = [
			_('Hostname'),         boardinfo.hostname,
			_('Model'),            boardinfo.model,
			_('Architecture'),     boardinfo.system,
			_('Temperature'),      tempLine,
			_('Target Platform'),  (L.isObject(boardinfo.release) ? boardinfo.release.target : ''),
			_('Firmware Version'), (L.isObject(boardinfo.release) ? boardinfo.release.description + ' / ' : '') + (luciversion || ''),
			_('Kernel Version'),   boardinfo.kernel,
			_('Local Time'),       datestr,
			_('Uptime'),           systeminfo.uptime ? '%t'.format(systeminfo.uptime) : null,
			_('Load Average'),     Array.isArray(systeminfo.load) ? '%.2f, %.2f, %.2f'.format(
				systeminfo.load[0] / 65535.0,
				systeminfo.load[1] / 65535.0,
				systeminfo.load[2] / 65535.0
			) : null
		];

		var table = E('table', { 'class': 'table' });

		for (var i = 0; i < fields.length; i += 2) {
			table.appendChild(E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, [ fields[i] ]),
				E('td', { 'class': 'td left' }, [ (fields[i + 1] != null) ? fields[i + 1] : '?' ])
			]));
		}

		return table;
	}
});

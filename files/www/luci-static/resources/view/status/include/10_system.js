'use strict';
'require baseclass';
'require fs';
'require rpc';

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

function readTemp(path) {
	return L.resolveDefault(fs.trimmed(path), null).then(function(v) {
		if (v == null)
			return null;

		v = String(v).trim();

		if (!v.match(/^-?[0-9]+$/))
			return null;

		var n = parseInt(v, 10);

		if (!isFinite(n))
			return null;

		if (Math.abs(n) > 1000)
			n = n / 1000;

		if (n < -40 || n > 150)
			return null;

		return n;
	});
}

function readText(path) {
	return L.resolveDefault(fs.trimmed(path), '').then(function(v) {
		return String(v || '').trim();
	});
}

function tempText(v) {
	return '%.1f°C'.format(v);
}

function isWifiName(s) {
	s = String(s || '').toLowerCase();
	return s.match(/wifi|wlan|wireless|radio|phy|mt76|mt79|mt7915|mt798|wmac|ieee80211/);
}

function isCpuName(s) {
	s = String(s || '').toLowerCase();
	return s.match(/cpu|soc|thermal|cpu-thermal|mtk|mediatek|package|board/);
}

function collectTemperatures(data) {
	var cpu = [];
	var wifi = [];
	var other = [];

	for (var i = 0; i < data.length; i++) {
		var item = data[i];

		if (!item || item.temp == null)
			continue;

		var name = [ item.type, item.name, item.label ].join(' ');

		if (isWifiName(name))
			wifi.push(item.temp);
		else if (isCpuName(name))
			cpu.push(item.temp);
		else
			other.push(item.temp);
	}

	if (cpu.length == 0 && other.length > 0)
		cpu.push(other.shift());

	var parts = [];

	if (cpu.length > 0)
		parts.push('CPU：' + tempText(cpu[0]));

	if (wifi.length > 0)
		parts.push('WiFi：' + wifi.map(tempText).join(' '));

	if (parts.length == 0)
		return null;

	return parts.join('，');
}

return baseclass.extend({
	title: _('System'),

	load: function() {
		var thermal = [];

		for (var i = 0; i < 8; i++) {
			thermal.push(Promise.all([
				readText('/sys/class/thermal/thermal_zone%d/type'.format(i)),
				readTemp('/sys/class/thermal/thermal_zone%d/temp'.format(i))
			]).then(function(r) {
				return {
					type: r[0],
					temp: r[1],
					name: '',
					label: ''
				};
			}));
		}

		var hwmon = [];

		for (var h = 0; h < 8; h++) {
			for (var t = 1; t <= 8; t++) {
				hwmon.push(Promise.all([
					readText('/sys/class/hwmon/hwmon%d/name'.format(h)),
					readText('/sys/class/hwmon/hwmon%d/temp%d_label'.format(h, t)),
					readTemp('/sys/class/hwmon/hwmon%d/temp%d_input'.format(h, t))
				]).then(function(r) {
					return {
						type: '',
						name: r[0],
						label: r[1],
						temp: r[2]
					};
				}));
			}
		}

		return Promise.all([
			L.resolveDefault(callSystemBoard(), {}),
			L.resolveDefault(callSystemInfo(), {}),
			L.resolveDefault(callLuciVersion(), { revision: _('unknown version'), branch: 'LuCI' }),
			L.resolveDefault(callGetUnixtime(), 0),
			Promise.all(thermal.concat(hwmon))
		]);
	},

	render: function(data) {
		var boardinfo   = data[0],
		    systeminfo  = data[1],
		    luciversion = data[2],
		    unixtime    = data[3],
		    temps       = collectTemperatures(data[4]);

		luciversion = luciversion.branch + ' ' + luciversion.revision;

		var datestr = null;

		if (unixtime) {
			var date = new Date(unixtime * 1000);
			datestr = date.toLocaleString();
		}

		var fields = [
			_('Hostname'),         boardinfo.hostname,
			_('Model'),            boardinfo.model,
			_('Architecture'),     boardinfo.system,
			'温度',                temps,
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
			if (fields[i + 1] == null)
				continue;

			table.appendChild(E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, [ fields[i] ]),
				E('td', { 'class': 'td left' }, [ fields[i + 1] ])
			]));
		}

		return table;
	}
});

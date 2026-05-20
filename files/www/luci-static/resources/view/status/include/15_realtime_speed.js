'use strict';
'require baseclass';
'require fs';
'require rpc';

var callWanStatus = rpc.declare({
	object: 'network.interface.wan',
	method: 'status'
});

var last = null;

function readCounter(path) {
	return L.resolveDefault(fs.trimmed(path), null).then(function(v) {
		if (v == null)
			return null;

		v = String(v).trim();

		if (!v.match(/^[0-9]+$/))
			return null;

		var n = parseInt(v, 10);

		return isFinite(n) ? n : null;
	});
}

function formatSpeed(bytesPerSecond) {
	if (bytesPerSecond == null || !isFinite(bytesPerSecond) || bytesPerSecond < 0)
		return '统计中…';

	var units = [ 'B/s', 'KB/s', 'MB/s', 'GB/s' ];
	var value = bytesPerSecond;
	var i = 0;

	while (value >= 1024 && i < units.length - 1) {
		value = value / 1024;
		i++;
	}

	return '%.2f %s'.format(value, units[i]);
}

function pickDevice(status) {
	if (status && status.l3_device)
		return status.l3_device;

	if (status && status.device)
		return status.device;

	return 'eth1';
}

return baseclass.extend({
	title: '实时上下行',

	load: function() {
		return L.resolveDefault(callWanStatus(), {}).then(function(status) {
			var dev = pickDevice(status);

			return Promise.all([
				dev,
				readCounter('/sys/class/net/%s/statistics/rx_bytes'.format(dev)),
				readCounter('/sys/class/net/%s/statistics/tx_bytes'.format(dev)),
				Date.now()
			]);
		});
	},

	render: function(data) {
		var dev = data[0],
		    rx  = data[1],
		    tx  = data[2],
		    now = data[3];

		var down = null;
		var up = null;

		if (last && last.dev == dev && rx != null && tx != null && now > last.now) {
			var dt = (now - last.now) / 1000;

			if (dt > 0) {
				down = (rx - last.rx) / dt;
				up = (tx - last.tx) / dt;
			}
		}

		if (rx != null && tx != null)
			last = { dev: dev, rx: rx, tx: tx, now: now };

		return E('table', { 'class': 'table' }, [
			E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, [ '接口' ]),
				E('td', { 'class': 'td left' }, [ dev || '-' ])
			]),
			E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, [ '下行速度' ]),
				E('td', { 'class': 'td left' }, [ formatSpeed(down) ])
			]),
			E('tr', { 'class': 'tr' }, [
				E('td', { 'class': 'td left', 'width': '33%' }, [ '上行速度' ]),
				E('td', { 'class': 'td left' }, [ formatSpeed(up) ])
			])
		]);
	}
});

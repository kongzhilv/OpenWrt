(function () {
  'use strict';

  var dict = {
    'System Overview': '系统概览',
    'Dashboard': '仪表盘',
    'Overview': '概览',
    'Charts': '图表',
    'Chart': '图表',
    'Alarms': '告警',
    'Alerts': '告警',
    'Settings': '设置',
    'Search': '搜索',
    'Nodes': '节点',
    'Metrics': '指标',
    'System': '系统',
    'CPU': '处理器',
    'Memory': '内存',
    'RAM': '内存',
    'Disk': '磁盘',
    'Disks': '磁盘',
    'Network': '网络',
    'Networking': '网络',
    'Interfaces': '网卡',
    'Processes': '进程',
    'Applications': '应用',
    'Services': '服务',
    'Users': '用户',
    'Load': '负载',
    'System Load': '系统负载',
    'Uptime': '运行时间',
    'Swap': '交换分区',
    'Storage': '存储',
    'Filesystem': '文件系统',
    'Filesystems': '文件系统',
    'Packets': '数据包',
    'Errors': '错误',
    'Drops': '丢包',
    'Received': '接收',
    'Sent': '发送',
    'Inbound': '入站',
    'Outbound': '出站',
    'Download': '下载',
    'Upload': '上传',
    'Bandwidth': '带宽',
    'Traffic': '流量',
    'Connections': '连接',
    'Sockets': '套接字',
    'Firewall': '防火墙',
    'Temperature': '温度',
    'Temperatures': '温度',
    'Fans': '风扇',
    'Voltage': '电压',
    'Power': '功耗',
    'Health': '健康状态',
    'Warning': '警告',
    'Critical': '严重',
    'Clear': '清除',
    'Reset': '重置',
    'Apply': '应用',
    'Cancel': '取消',
    'Close': '关闭',
    'Save': '保存',
    'Update': '更新',
    'Refresh': '刷新',
    'Live': '实时',
    'Now': '现在',
    'Today': '今天',
    'Last hour': '最近一小时',
    'Last day': '最近一天',
    'Last week': '最近一周',
    'seconds': '秒',
    'minutes': '分钟',
    'hours': '小时',
    'days': '天'
  };

  var keys = Object.keys(dict).sort(function (a, b) { return b.length - a.length; });

  function translateString(value) {
    if (!value) return value;
    var out = value;
    for (var i = 0; i < keys.length; i++) {
      out = out.split(keys[i]).join(dict[keys[i]]);
    }
    return out;
  }

  function shouldSkipElement(el) {
    if (!el || !el.tagName) return false;
    var name = el.tagName.toLowerCase();
    return name === 'script' || name === 'style' || name === 'code' || name === 'pre' || name === 'textarea';
  }

  function translateAttributes(el) {
    if (!el || !el.getAttribute) return;
    var attrs = ['title', 'placeholder', 'aria-label', 'alt', 'value'];
    for (var i = 0; i < attrs.length; i++) {
      var name = attrs[i];
      var val = el.getAttribute(name);
      var next = translateString(val);
      if (next && next !== val) el.setAttribute(name, next);
    }
  }

  function walk(node) {
    if (!node) return;

    if (node.nodeType === 3) {
      var val = node.nodeValue;
      var next = translateString(val);
      if (next !== val) node.nodeValue = next;
      return;
    }

    if (node.nodeType !== 1 || shouldSkipElement(node)) return;

    translateAttributes(node);

    var children = node.childNodes;
    for (var i = 0; i < children.length; i++) {
      walk(children[i]);
    }
  }

  function runOnce() {
    if (!document.body) return;
    walk(document.body);
    document.title = translateString(document.title || 'Netdata') || document.title;
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      window.setTimeout(runOnce, 1000);
    });
  } else {
    window.setTimeout(runOnce, 1000);
  }
})();

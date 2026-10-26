// KUTSU BLE GATT contract — must match the firmware (config.h / PROVISIONING.md).

const svcUuid       = '6b755473-7500-4b75-7473-750000000001';
const chrLive       = '6b755473-7500-4b75-7473-750000000002'; // notify: record JSON
const chrTimeGeo    = '6b755473-7500-4b75-7473-750000000003'; // write: {epoch,lat,lon}
const chrWifi       = '6b755473-7500-4b75-7473-750000000004'; // write: {ssid,password,room}
const chrStatus     = '6b755473-7500-4b75-7473-750000000005'; // read/notify
const chrHistory    = '6b755473-7500-4b75-7473-750000000006'; // read/write: SD log dump (#3)
const chrSettings   = '6b755473-7500-4b75-7473-750000000007'; // read/write/notify
const chrThresholds = '6b755473-7500-4b75-7473-750000000008'; // read/write

const namePrefix = 'Kutsu';

// Metrics shown in the UI, in order.
class MetricDef {
  final String key, label, unit;
  const MetricDef(this.key, this.label, this.unit);
}

const metrics = <MetricDef>[
  MetricDef('co2', 'CO₂', 'ppm'),
  MetricDef('voc', 'VOC', 'idx'),
  MetricDef('nox', 'NOx', 'idx'),
  MetricDef('temp', 'Temp', '°C'),
  MetricDef('hum', 'Hum', '%RH'),
  MetricDef('eco2', 'eCO₂', 'ppm'),
  MetricDef('tvoc', 'TVOC', 'ppb'),
  MetricDef('gas', 'Gas', 'adc'),
];

// Threshold sub-fields per metric (matches the firmware thresholds JSON).
const thrFields = <String, List<List<String>>>{
  'co2': [['w', 'warn'], ['h', 'alert']],
  'eco2': [['w', 'warn'], ['h', 'alert']],
  'tvoc': [['w', 'warn'], ['h', 'alert']],
  'voc': [['w', 'warn'], ['h', 'alert']],
  'nox': [['w', 'warn'], ['h', 'alert']],
  'gas': [['w', 'warn'], ['h', 'alert']],
  'temp': [['wh', 'warn >'], ['hh', 'alert >'], ['hl', 'alert <']],
  'hum': [['wl', 'warn <'], ['wh', 'warn >'], ['hl', 'alert <'], ['hh', 'alert >']],
};
const thrLabel = <String, String>{
  'co2': 'CO₂ ppm', 'eco2': 'eCO₂ ppm', 'tvoc': 'TVOC ppb', 'voc': 'VOC idx',
  'nox': 'NOx idx', 'gas': 'Gas adc', 'temp': 'Temp °C', 'hum': 'Hum %RH',
};

double? asDouble(dynamic v) => v is num ? v.toDouble() : null;
int? asInt(dynamic v) => v is num ? v.toInt() : null;

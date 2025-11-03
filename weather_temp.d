/*
   Simple weather temperature application (to write in bar such as dwmblocks) using the Open-Meteo API.
   Copyright 2024-2025 Sam Saint-Pettersen.

   Released under the MIT License.
*/

import std.file;
import std.conv;
import std.stdio;
import std.string;
import std.process;
import std.algorithm;

struct weather_opts {
    float latitude;
    float longitude;
    string timezone;
    char unit;
}

int get_weather_temp(weather_opts w) {
    string endpoint = format("https://api.open-meteo.com/v1/forecast?latitude=%.2f", w.latitude);
    endpoint ~= format("&longitude=%.2f&hourly=temperature_2m&current=temperature_2m", w.longitude);

    // UTC timezone does not need a parameter to the API.
    if (w.timezone != "UTC")
        endpoint ~= format("&timezone=%s", w.timezone);

    string curl_switch = "";
    string json = "/tmp/weather_temp.json";
    version(Windows) {
        curl_switch = " -k ";
        json = "weather_temp.json";
    }

    string request = format("curl -s%s \"%s\" | jq .current > %s", curl_switch, endpoint, json);
    auto api = executeShell(request);
    if (api.status != 0) {
        writeln("Failed");

        return -1;
    }

    string get_temp = format("jq .temperature_2m %s", json);
    auto temp = executeShell(get_temp);
    float curr_temp = to!float(strip(temp.output));

    if (w.unit == 'F') {
        curr_temp = ((curr_temp * 1.8) + 32);
    }
    else if (w.unit == 'K') {
        curr_temp = (curr_temp + 273.15);
    }

    writefln("%.1f %c", curr_temp, w.unit);

    return 0;
}

weather_opts read_config_file() {
    weather_opts w;
    string cfg = "/etc/weather_temp.cfg";
    version(Windows) {
        cfg = "weather_temp.cfg";
    }
    if (cfg.exists) {
        auto f = File(cfg);
        foreach (line; f.byLine()) {
            string l = to!string(line);
            if (l.startsWith("#")) {
                // Ignore any comment lines in configuration file.
                continue;
            }

            if (l.canFind(",")) {
                auto ll = l.split(",");
                w.latitude = to!float(ll[0]);
                w.longitude = to!float(ll[1]);
            }
            else if (l.canFind("/")) {
                w.timezone = l;
            }
            else if (l.canFind("Z")) {
                w.timezone = "UTC"; // Zulu time is UTC.
            }
            else if (l.canFind("F") || l.canFind("C") || l.canFind("K")) {
                w.unit = to!char(l);
            }
        }

        return w;
    }

    // Use New York City if a configuration file is unavailable.
    w.latitude = 40.71427;
    w.longitude = -74.00597;
    w.timezone = "America/New_York";
    w.unit = 'F';

    return w;
}

int main() {
    int status = get_weather_temp(read_config_file());
    return status;
}

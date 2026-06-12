import std.file;
import std.conv;
import std.stdio;
import std.getopt;
import std.string;
import std.process;
import std.algorithm;

struct weather_opts {
    float latitude;
    float longitude;
    string timezone;
    string unit;
    bool verbose;
    bool only_temp;
}

int get_weather_temp(weather_opts w) {
    string endpoint = format("https://api.open-meteo.com/v1/forecast?latitude=%.2f",
    w.latitude);

    endpoint ~= format("&longitude=%.2f&current=temperature_2m,relative_humidity_2m",
    w.longitude);

    // UTC timezone does not need a parameter to the API.
    if (w.timezone != "UTC")
        endpoint ~= format("&timezone=%s", w.timezone);

    // Thanks, Markus - we should fail when the API returns non HTTP 2xx code:
    string curl_switch = "--fail";
    string json = "/tmp/weather_temp.json";
    version(Windows) {
        curl_switch = "-k --fail";
        json = "weather_temp.json";
    }

    string request = format("curl -s %s \"%s\" | jq .current > %s", curl_switch, endpoint, json);
    if (w.verbose) {
        writefln("Running '%s'...", request);
    }

    auto api = executeShell(request);
    if (api.status != 0) {
        writeln("Failed");
        return -1;
    }

    string get_temp  = format("jq .temperature_2m %s", json);
    string get_humid = format("jq .relative_humidity_2m %s", json);
    if (w.verbose) {
        writefln("Running '%s'...", get_temp);
        if (!w.only_temp) writefln("Running '%s'...", get_humid);
    }

    auto temp = executeShell(get_temp);
    float curr_temp = to!float(strip(temp.output)); // API returns temp in Celsius.

    auto humid = executeShell(get_humid);
    int curr_humid = to!int(strip(humid.output)); // API returns humidity in %.

    float f_temp = ((curr_temp * 1.8) + 32);
    string unit = w.unit;

    switch (w.unit) {
        case "C": // Celsius
            break;

        case "F": // Fahrenheit
            curr_temp = f_temp;
            break;

        case "K": // Kelvin
            curr_temp = (curr_temp + 273.15);
            break;

        case "R": // Rankine
        case "Ra":
            curr_temp = (f_temp + 459.67);
            unit = "R";
            break;

        case "Ré": // Réaumur
        case "Re":
            curr_temp = (curr_temp * 0.8);
            unit = "Ré";
            break;

        case "Rø": // Rømer
        case "Ro":
            curr_temp = ((curr_temp * 0.525) + 7.5);
            unit = "Rø";
            break;

        default: // Invalid unit code was provided.
            writeln("Error: Invalid unit");
            return -1;
    }

    if (w.only_temp) {
        writefln("%.1f %s", curr_temp, unit);
        return 0;
    }

    writefln("%.1f %s (%d %%)", curr_temp, unit, curr_humid);
    return 0;
}

weather_opts read_config_file(bool verbose, bool only_temp) {
    weather_opts w;
    w.verbose = verbose;
    w.only_temp = only_temp;

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
            else {
                w.unit = l;
            }
        }

        return w;
    }

    // Use New York City if a configuration file is unavailable.
    w.latitude = 40.71427;
    w.longitude = -74.00597;
    w.timezone = "America/New_York";
    w.unit = "F";

    return w;
}

int main(string[] args) {
    int status = 0;
    bool verbose = false;
    bool only_temp = false;

    auto cli = getopt(
        args,
        "verbose|v", "Show underlying invokations to curl and jq.", &verbose,
        "temp|t", "Only print temperature, not humidity.", &only_temp,
    );

    // -h|--help
    if (cli.helpWanted) {
        defaultGetoptPrinter(format("%s\n", args[0]), cli.options);
        return status;
    }

    status = get_weather_temp(read_config_file(verbose, only_temp));
    return status;
}

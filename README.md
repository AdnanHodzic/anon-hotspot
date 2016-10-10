# anon-hotspot
On demand Debian Linux (Tor) Hotspot setup tool

### Turn Raspberry Pi 3/or any other Debian Linux based device into a (Tor) WiFi Hotspot

You need two things:

1. Clone anon-hotspot [git repo](https://github.com/AdnanHodzic/anon-hotspot.git)
2. Raspberry PI 3 or any other Debian Linux based device with ethernet port and wifi card

*RPI3 or any other device you want to run this on needs to be connected to internet via ethernet port, while WiFi interface will be turned into an AP/Hotspot.*

While this tool was made and tested on [Raspbian (jessie)](https://www.raspberrypi.org/downloads/raspbian/) on RPI3. It'll work on any other Debian Linux based device. So, if you don't have RPI3 laying around, but have an old computer which you'd like to turn into Tor Hotspot be my guest. If you run into problems, please [create an issue.](https://github.com/AdnanHodzic/anon-hotspot/issues)

Since this tool is still under development, it's recommended you run it on freshly installed Raspbian (>= Jessie) and not on your prod environments. 

### anon-hotspot

Just run it! i.e:

`sudo ./anon-hotspot`

![anon-hotspot welcome screen](http://foolcontrol.org/wp-content/uploads/2016/09/anon-hotspot.png)

### Features:

__configuration__

* tor-hotspot (configure Tor WiFi hotspot)
* hotspot (configure WiFi hotspot)
* tor (configure Tor for existing Wifi hotspot)
* cred (change Tor/WiFi Hotspot ssid/passphrase)
* remove (remove Tor/Wifi Hotspot & revert to original settings)

__operations__

* start (start Tor/WiFi hotspot)
* stop (stop Tor/WiFi hotspot)

### Supported platforms:

* Raspbian: >= Jessie 8.0
* Debian: >= Jessie 8.0
* Ubuntu: >= 15.04
* Elementary OS: >= Loki
* Kali Linux: >= 2.0

### Discussion
Blog post: [anon-hotspot: On demand Debian Linux (Tor) Hotspot setup tool](http://foolcontrol.org/?p=1853)

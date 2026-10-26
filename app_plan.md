# Kutsu Comanion App description

# App update 3
1. Pair device to the phone in a way that the device reconnects to the phone automatically if disconnected.
1.1. Allow user in settings to choose whether they want to bind (pair) the device to their phone for autoconnect or not.
2. When in handheld mode, the device shouldn't try to connect to a saved network.
3. Allow importing data from device SD card if the card is present. If data has no geolocation, import it only to Stats screen. If data has geolocation, import it into Map screen as well.
4. On Map screen - Add "Global" tab that displays all community entries from the online database.
4.1. Add different map rendering options.
4.2. Add "Add Marker" button to Map screen. After pressing the button, a map marker appears in the location where the user taps next. Then a dialog appears where user can write a title (for example Home or Recycling plant). Add a color picker so the user can choose a color for their marker. Add pre defined colors like red, green, blue, yellow, purple.
4.3. Make new readings appear on Map screen dynamically.
5. On Stats screen - In ENVIRONMENT TREND section, add visual time markers to bottom (horizontal) plane for better readability.  
5.1. Make it so that the user can scroll and zoom the stats. 
5.2. Statas should be refreshed when a different Kutsu device is connected to the mobile device.
5.3. Add auto refresh so the user doesn't need to manually update the screen for new information.
6. On Settings screen - Add a new submenu under "SETTINGS" section called "Sensors" where user can define sensor refresh rate. Add a "Restore to Default" button to the bottom of that submenu.
7. On Settings screen - Add a new submenu under "SETTINGS" section called "Trends" where user can define their Trends (on Stats screen) display preferences.
7.1. Add Display per = Session or Location
7.1.1. If Session = On Stats screen in "ENVIRONMENT TREND" section display Calendar button where user can choose a date and session which they want to display. Default is most recent session.
7.1.2. If Location = On Stats creen display Radius button where the user can choose a radius (in meters) of how many data entries are considered in trends. Display Calendar button where user can define date, date period and time period. Then send user to Map screen so the user can choose the location for trends. When in this pipeline the map should be filtered and allow user to choose only locations that have recorded data for that period. When in this pipeline, user should be allowed to choose whether they want to display trends from All time tab, This run tab or Global tab.

# App Update 2
1. On Map screen - Add center to user location button to top right corner of map.
2. On Map screen - When zoomed in, add floating readings within the radius of reading goelocation for better visualisation.
3. On Stats screen in Environment trends - Add a horizontal time visualisation so when user drags finger across the graph, they can see exact readings and time (for better trend and change visualisation and analysis)

Bugs to fix:
1. On Map screens, pressing on geolocation dots doesn't open readings dialog.



# App Update 1

1. Add date based data sorting.
1.1. On Map screen All time tab, have an additional calendar date picker. Default state is all time. When choosing a date, user can display results of all runs on picked date. User should have an additional drop down menu where they can choose what specific run results to display for the picked date.
2. On Map screen in both tabs, add a clear central dot to every reading entry so that it's easy and clear where to tap to open detailed reading info.
3. When zoomed in, entries should be clearly defined and separated. When zoomed out the map should get a heatmap overlay that is more generalised and visually readable. 

4. Create an online database (for example Firebase) and add a button so that users can contribute their data to a global community map. By default user contributions are anonymous. (maybe in the future we will add user profiles and scoreboards, but not certain right now)


# General
App name: Kutsu Companion


# Loading sequence:
1. App launch
2. Logo and intro screen
3. Device screen

# Bottom menu items:
1. Device
2. Live
3. Map
4. Data
5. Settings

# Device screen
## When not connected to a device
"CONNECT OVER BLUETOOTH" section
Scan for Kutsu devices button
Power the device and keep it nearby. It advertises as "Name-XX".

"FOUND" section
Device icon + Device name + MAC address + Connect button

## Whem connected to a device
"DEVICE" section
- Green dot "Connected" text and "solo" when in handheld mode / "master" when in stationary mode and master node on network / "slave" when in stationary mode and contributing readings to a master node.
- "Disconnect" button
- Name = Device name
- Device ID = MAC address
- Wifi = connected/[SSID]
- Room = [user defined room name]
- Clock = synced / not synced
- Location = City, Country

# Live screen
## Device section
- Device name
- Location = City, Country, Lattitude, Longitude
- Time
- Temp
- Humidity
- CO2, ppm, [reading] + graph
- VOC, idx, [reading] + graph
- NOx, idx, [reading] + graph
- (if any other sensor found by boot init, = Chemical, ppm, [reading] + graph)
- Device runtime: hours/minutes/seconds by default. If running for more than 24h = days/hours/minutes.

# Map screen
On top of screen there are two tabs. "All time" tab and "This run" tab. On right side of the same row "Filter" button.

## Filter
- Temperature
- Humidity
- CO2
- VOC
- NOx

Filtration displays or hides selected items when opening detailed location readings dialog by pressing the circle.
## "All time" tab
Includes all entries saved to device. Map updates in live with user location as blue arrow pointing in device direction of movement.
Inside All time tab all stored entries are displayed. Ideally when zoomed in entries are displayed as colorful bubbles. Green when all readings are in saze area. Yellow when any reading (CO2, NOx, VOC) is in warning zone. Red if any reading is in alert zone. When zoomed out the color bubbles are converted into a heatmap. Areas that have location and reading data become a heatmap. Areas that have no submitted data do not have heatmap overlay.

## "This run" tab
Only includes entries from running session. Map udates in live with user location as blue arrow pointing in device direction of movement. This run tab also includes a route that the device has moved through.



# Data screen (break down into sections and move to Settings (old setup) screen)
## "COLLECTED DATA" section
- Stored samples
- Avg CO2 (recent) = [average reading] ppm
- Avg temp = [average reading] degrees C
- Avg humidity = [average reading] %
- "Clear stored data" button

## "WARDRIVING" section
- BLE Devices
- 2.4G APs
- 5G APs
- Upload to Wigle (coming soon) button
- "Delete stored data" button

- Recent sample log should be removed.

# Add Stats screen instead of Data screen
- Graphs, diagrams and chats with collected environment data.

## Add "EXPORT" section
- "Export as .csv" button

## Add "DEBUG" section
- Device internal log

# Setup screen
- Rename to Settings
- "SETTINGS" section
- - Device settings tab
- - - Includes Identity; Mode; Outputs (separate Wifi & BLE to wardriving subsection); Wardriving (Wifi & BLE scanning)
- - Alerts (move ALARM SIGNALS to Alerts)
- - - Put Warning thresholds under Alerts
- - - Include Restore defaults button
- - Wifi Setup
- - Dashboard 
- - Rename Nearby WiFi & BLE to Wardriving (coming soon) 
- - - Wigle data submission credentials setup
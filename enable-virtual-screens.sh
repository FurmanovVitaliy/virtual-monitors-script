#!/bin/bash

# jq check
if ! which jq > /dev/null 2>&1; then
    echo "jq not instaled"
    exit 0
fi

# check  drm_info
if ! which drm_info > /dev/null 2>&1; then
    echo "drm_info not instaled"
    exit 0
fi


SCRIPT_PATH="$(dirname "$(realpath "$0")")"
source "$SCRIPT_PATH/bash-lib.sh"

DRM_JSON="$SCRIPT_PATH/drm.json"
OUTPUT_JSON="$SCRIPT_PATH/display-info.json"
VIRTUAL_SCREEN_COUNT=$(( $(get_screen_count) - 1 ))
CARDS=$(jq -r 'keys[]' "$DRM_JSON")

#create the output json file if it doesn't exist
if [ ! -f "$OUTPUT_JSON" ]; then
    echo "[]" > "$OUTPUT_JSON"
    log "Created $OUTPUT_JSON"
else
    #clear the output json file if it already exists
    echo "[]" > "$OUTPUT_JSON"
    log "Cleared $OUTPUT_JSON"
fi


log "Enabling ${VIRTUAL_SCREEN_COUNT} virtual screens from zaphodhead-xorg.conf"

if  [ ! -f /etc/X11/xorg.conf.d/xorg.conf ]; then
    log "No xorg.conf found, skipping in 'etc/X11/xorg.conf.d/'"
    exit 0
fi

for (( screen_number = 1 ; screen_number <= VIRTUAL_SCREEN_COUNT ; screen_number++ )); do
    #find the port name and connector id for the screen via xrandr
    output=$(xrandr --screen $screen_number --verbose)
    port_name=$(echo "$output" | grep 'connected\|disconnected' | awk '{print $1}')
    connector_id="$(echo "$output" | grep 'CONNECTOR_ID' | awk '{print $2}')"
    
    if [ -z "$connector_id" ] || [ "$connector_id" == "null" ]; then
        log_error "Failed to get connector_id for screen 0.$screen_number with $port_name"
        continue
    fi

    card_path="null"  #
    crtc_id="null"    # crtc_value or crtc_raw in connectors in drm.json
    plane_id="null"   # 

    #! ENABLE SCREEN VIA XRANDR COMMAND (extra properties can be set here)
   MODE_NAME="1920x1080_60.00_$screen_number"
    if ! xrandr --screen $screen_number --verbose | grep -q "$MODE_NAME"; then
      xrandr --screen $screen_number --newmode "$MODE_NAME" 173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync
    fi
    xrandr --screen $screen_number --addmode "$port_name" "$MODE_NAME"
    xrandr --screen $screen_number --output "$port_name" --mode "$MODE_NAME"

    #! UPDATE DRM INFO AFTER SREEN ENABLING
    drm_info -j > "$DRM_JSON"
    if [ $? -eq 0 ]; then
      echo ""
      log "Source file $DRM_JSON successfully updated/created."
      echo ""
    else
      log "Failed to create/update file $DRM_JSON."
      exit 1
    fi

    # crtc and plane can be found properly only if screen alrady enabled
    for device_path in $CARDS; do
      #find the crtc_id for the connector in the drm.json file
      crtc_id=$(jq --arg key "$device_path" --argjson id "$connector_id" \
      '.[$key].connectors[] | select(.id == $id) | .properties."CRTC_ID".value' "$DRM_JSON")
      # if crtc is null, try to find it in the next card
      if [ "$crtc_id" == "null" ] || [ -z "$crtc_id" ] || [ "$crtc_id" == "0" ] || [ "$crtc_id" == 0 ] ; then
          log_error "Failed to get crtc_id for connector $connector_id on card $device_path with port $port_name"
          continue
      else
          card_path="$device_path"
          log "Found  crtc_id $crtc_id for connector $connector_id on card $device_path with port $port_name"
          break  
      fi
    done

    #if crrc_id is still null, skip the screen
    if [ "$crtc_id" == "null" ] || [ -z "$crtc_id" ] || [ "$crtc_id" == "0" ] || [ "$crtc_id" == 0 ] ; then
        log_error "Failed to get crtc_id for connector $connector_id on any card $card_path with port $port_name"
        continue
    fi

    #find the plane_id for the crtc in the drm.json file
    plane_id=$(jq --arg key "$card_path" --argjson crtc_id "$crtc_id" \
    '.[$key].planes[] | select(.crtc_id == $crtc_id) | .id' $DRM_JSON)

    #if plane_id is null, skip the screen
    if [ "$plane_id" == "null" ] || [ -z "$plane_id" ] || [ "$plane_id" == "0" ] || [ "$plane_id" == 0 ] ; then
        log_error "Failed to get plane_id for crtc $crtc_id on card $card_path with port $port_name"
        continue
    else
        log "Found plane_id $plane_id for crtc $crtc_id on card $card_path with port $port_name"
        #! UPDATE OUTPUT JSON FILE  
        jq --arg screen "0.$screen_number" \
          --arg port_name "$port_name" \
          --argjson connector_id "$connector_id" \
          --arg device_path "$card_path" \
          --argjson crtc_id "$crtc_id" \
          --argjson plane_id "$plane_id" \
          '. += [{ "screen": $screen, "card": "card0", "port_name": $port_name, "connector_id": $connector_id, "device_path": $device_path, "crtc_id": $crtc_id, "plane_id": $plane_id }]' \
          "$OUTPUT_JSON" > "$OUTPUT_JSON.tmp" && mv "$OUTPUT_JSON.tmp" "$OUTPUT_JSON"

        log "Screen 0.$screen_number enabled / screen info updated in $OUTPUT_JSON"
    fi
done

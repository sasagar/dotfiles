#!/usr/bin/env bash

# --- 設定 ---
export DIR_TEMPORARY="/tmp/tmux-weather_${USER}"
mkdir -p "$DIR_TEMPORARY"

WEATHER_UNIT_DEFAULT="metric"
WEATHER_UPDATE_PERIOD_DEFAULT="600"
WEATHER_LOCATION_DEFAULT="1850147" # Tokyo

export WEATHER_UNIT="${WEATHER_UNIT:-$WEATHER_UNIT_DEFAULT}"
export WEATHER_UPDATE_PERIOD="${WEATHER_UPDATE_PERIOD:-$WEATHER_UPDATE_PERIOD_DEFAULT}"
export WEATHER_LOCATION="${WEATHER_LOCATION:-$WEATHER_LOCATION_DEFAULT}"

# --- ヘルパー関数 ---
__read_tmp_file() {
  local tmp_file="$1"
  if [ -f "$tmp_file" ]; then
    local cached_data=$(cat "${tmp_file}")
    tmux set-option -g @weather_display "${cached_data}"
    exit 0
  fi
}

__get_temperature_color() {
  local degree="$1"
  local int_degree=$(printf "%.0f" "$degree")
  if [ "$int_degree" -lt 0 ]; then echo "#94e2d5"
  elif [ "$int_degree" -lt 10 ]; then echo "#89b4fa"
  elif [ "$int_degree" -lt 20 ]; then echo "#a6e3a1"
  elif [ "$int_degree" -lt 25 ]; then echo "#f9e2af"
  elif [ "$int_degree" -lt 30 ]; then echo "#fab387"
  else echo "#f38ba8"
  fi
}

__get_weather_image() {
  local condition="$1"
  local sunrise="$2"
  local sunset="$3"
  local degree=$(printf "%.0f" "$4")
  local time_now=$(date +%H%M)
  case "$condition" in
    "clear sky")
      if [ "$time_now" -ge "$sunset" -o "$time_now" -le "$sunrise" ]; then
        [ "$degree" -le 5 ] && echo "" || echo ""
      else
        [ "$degree" -ge 25 ] && echo "󱣗" || echo "󰖙"
      fi ;;
    "few clouds") echo "" ;;
    "scattered clouds") echo "" ;;
    "broken clouds" | "overcast clouds") echo "" ;;
    "rain" | "light rain" | "moderate rain" | "heavy intensity rain" | "drizzle"*) echo "" ;;
    "Snow" | "light snow" | "Heavy snow"*) echo "" ;;
    "thunderstorm"*) echo "" ;;
    *) echo "" ;;
  esac
}

# --- メイン実行 ---
__run_weather() {
  local tmp_file="${DIR_TEMPORARY}/weather_openweathermap.txt"
  
  if [ -f "$tmp_file" ]; then
    last_update=$(stat -f "%m" "${tmp_file}" 2>/dev/null || stat -c "%Y" "${tmp_file}" 2>/dev/null)
    time_now_epoch=$(date +%s)
    if [ $((time_now_epoch - last_update)) -lt "$WEATHER_UPDATE_PERIOD" ]; then
      __read_tmp_file "$tmp_file"
    fi
  fi

  # APIキー取得
  if [ -z "$WEATHER_API" ]; then
     WEATHER_API=$(tmux show-env -g WEATHER_API 2>/dev/null | cut -d= -f2)
  fi
  [ -z "$WEATHER_API" ] && exit 1

  weather_data=$(curl --max-time 4 -s "http://api.openweathermap.org/data/2.5/weather?id=${WEATHER_LOCATION}&units=${WEATHER_UNIT}&appid=${WEATHER_API}")
  
  if [ $? -eq 0 ] && [ -n "$weather_data" ]; then
    degree=$(echo "$weather_data" | jq -r '.main.temp // empty')
    [ -z "$degree" ] && __read_tmp_file "$tmp_file"

    condition=$(echo "$weather_data" | jq -r '.weather[0].description')
    sunrise_u=$(echo "$weather_data" | jq -r '.sys.sunrise')
    sunset_u=$(echo "$weather_data" | jq -r '.sys.sunset')
    sunrise=$(date -r ${sunrise_u} +%H%M 2>/dev/null || date -d @${sunrise_u} +%H%M 2>/dev/null)
    sunset=$(date -r ${sunset_u} +%H%M 2>/dev/null || date -d @${sunset_u} +%H%M 2>/dev/null)

    color=$(__get_temperature_color "$degree")
    symbol=$(__get_weather_image "$condition" "$sunrise" "$sunset" "$degree")
    temp="$(printf "%.1f" "$degree")°C"
    st_bg="#333333"

    result="#[fg=${color},bg=${st_bg}]#[fg=${st_bg},bg=${color},bold]${symbol} ${temp}#[fg=${color},bg=${st_bg}]"
    
    tmux set-option -g @weather_display "${result}"
    echo "${result}" > "${tmp_file}"
  fi
}

__run_weather

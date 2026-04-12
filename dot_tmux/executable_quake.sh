
#!/usr/bin/env bash

# --- 設定 ---
ALERT_THRESHOLD=120 # 120秒間表示
DIR_TEMPORARY="/tmp/tmux-quake_${USER}"
mkdir -p "$DIR_TEMPORARY"

# --- 地震情報の取得 (P2P地震情報 API) ---
quake_data=$(curl --max-time 3 -s "https://api.p2pquake.net/v2/history?codes=551&limit=1")

if [ $? -eq 0 ] && [ -n "$quake_data" ]; then
    time_str=$(echo "$quake_data" | jq -r '.[0].time')
    max_scale=$(echo "$quake_data" | jq -r '.[0].earthquake.maxScale')
    hypocenter=$(echo "$quake_data" | jq -r '.[0].earthquake.hypocenter.name')

    # 震度表示とレベル分け
    case "$max_scale" in
        30) scale="3";  level=3 ;;
        40) scale="4";  level=4 ;;
        45) scale="5弱"; level=5 ;;
        50) scale="5強"; level=5 ;;
        55) scale="6弱"; level=5 ;;
        60) scale="6強"; level=5 ;;
        70) scale="7";  level=5 ;;
        *)  scale="不明"; level=0 ;;
    esac

    # 震度3未満は非表示にして終了
    if [ "$level" -lt 3 ]; then
        tmux set-option -g @quake_display ""
        exit 0
    fi

    # 経過時間の計算 (macOS/Linux両対応)
    quake_time=$(date -j -f "%Y/%m/%d %H:%M:%S" "$time_str" "+%s" 2>/dev/null || date -d "${time_str//\//-}" +%s 2>/dev/null)
    now=$(date +%s)
    diff=$((now - quake_time))

    # --- デザイン構築 (震度に応じたスタイル) ---
    if [ "$diff" -ge 0 ] && [ "$diff" -le "$ALERT_THRESHOLD" ]; then
        st_bg="#333333" # ステータスラインの背景色
        
        if [ "$level" -eq 5 ]; then
            # 【震度5以上: パターンA】白文字 × 鮮烈な赤 × サイレン
            alert_bg="#ff0000"
            alert_fg="#ffffff"
            icon="🚨"
            msg=" 震度${scale}!! : ${hypocenter} "
        elif [ "$level" -eq 4 ]; then
            # 【震度4: 警告】黒文字 × 鮮烈な赤 × 警告アイコン
            alert_bg="#ff0000"
            alert_fg="#333333"
            icon=""
            msg=" 地震: ${hypocenter} (震度${scale}) "
        else
            # 【震度3: 通知】黒文字 × 通常の赤 × 警告アイコン
            alert_bg="#f38ba8"
            alert_fg="#333333"
            icon=""
            msg=" 地震: ${hypocenter} (震度${scale}) "
        fi

        # デザイン組み立て (カプセルスタイル)
        result="#[fg=${alert_bg},bg=${st_bg}]#[fg=${alert_fg},bg=${alert_bg},bold]${icon}${msg}${icon}#[fg=${alert_bg},bg=${st_bg}] "
        
        tmux set-option -g @quake_display "${result}"
    else
        # 2分以上経過していたら非表示
        tmux set-option -g @quake_display ""
    fi
else
    # 取得失敗時は非表示
    tmux set-option -g @quake_display ""
fi

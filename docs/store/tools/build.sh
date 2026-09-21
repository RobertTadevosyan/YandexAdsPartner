#!/usr/bin/env bash
# Renders framed store screenshots and the feature graphic.
#
# Sources (docs/store/screenshots/src):
#   <lang>_<screen>.jpg            Android phone captures from the emulator (Play phone set)
#   <lang>_iphone67_<screen>.png   rendered by test/store_screenshots_test.dart (App Store iPhone set)
#   <lang>_ipad13_<screen>.png     same renderer (App Store iPad set)
#   <lang>_tablet10_<screen>.png   same renderer (Play 10" tablet set)
#   <lang>_ioswidget.png           WidgetKit medium view rendered on macOS (App Store iPhone "widget" shot)
#
# Regenerate the rendered sources with:
#   flutter test --update-goldens --dart-define=STORE_SHOTS=true \
#     --dart-define=ADPOCKET_DEMO=true --dart-define=ADPOCKET_DEMO_PROFILE=store test/store_screenshots_test.dart
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
STORE="$ROOT/docs/store"
SRC="$STORE/screenshots/src"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || { echo "Google Chrome not found"; exit 1; }
TMP="$(mktemp -d)"

render() { # out.png width height url
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --window-size="$2,$3" --screenshot="$1" "$4" >/dev/null 2>&1
}
enc() { python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$1"; }
jpg() { sips -s format jpeg -s formatOptions 88 "$1" --out "$2" >/dev/null; }

# screen|title|subtitle
EN=(
 "overview|Your revenue today|Yesterday, the week and the month right next to it"
 "reports|Any report from partner.yandex.ru|Filters, groupings, totals and CSV export"
 "chart|Trends at a glance|30-day chart and period metrics: eCPM, fill rate, CTR"
 "widget|Widgets that refresh themselves|Today's revenue on your home screen, Android and iOS"
 "accounts|Several accounts, one app|Switch between YAN accounts with a tap"
 "security|Private and secure|Token in the system Keystore, optional app lock, no servers"
)
RU=(
 "overview|Доход за сегодня|Вчера, неделя и месяц — рядом, для сравнения"
 "reports|Любой отчёт из кабинета РСЯ|Фильтры, группировки, итоги, экспорт в CSV"
 "chart|Динамика одним взглядом|График за 30 дней, eCPM, fill rate и CTR за период"
 "widget|Виджет обновляется сам|Доход за сегодня на главном экране, Android и iOS"
 "accounts|Несколько аккаунтов|Переключение между аккаунтами РСЯ одним касанием"
 "security|Приватно и безопасно|Токен в Keystore, блокировка приложения, без серверов"
)
FOOT_EN="Not an official Yandex application"
FOOT_RU="Неофициальное приложение, не связано с Яндексом"

# set  lang  outdir  device  width  height  srcprefix  srcext  foot  rows...
build_set() {
  local lang="$1" out="$2" device="$3" w="$4" h="$5" prefix="$6" ext="$7" foot="$8"; shift 8
  local rows=("$@"); local i=1
  mkdir -p "$out"
  for row in "${rows[@]}"; do
    IFS='|' read -r name title sub <<<"$row"
    local url="file://$STORE/tools/frame.html?device=$device&t=$(enc "$title")&s=$(enc "$sub")&f=$(enc "$foot")"
    if [ "$name" = "widget" ]; then
      case "$device" in
        phone) local src="$SRC/${lang}_widget.jpg"; [ -f "$src" ] || { echo "missing $src"; continue; }; url="$url&img=file://$src" ;;
        iphone) local wsrc="$SRC/${lang}_ioswidget.png"; [ -f "$wsrc" ] || { echo "missing $wsrc"; continue; }; url="file://$STORE/tools/frame.html?device=widget-ios&t=$(enc "$title")&s=$(enc "$sub")&f=$(enc "$foot")&wimg=file://$wsrc" ;;
        *) continue ;;   # no home-screen shot for tablets
      esac
    else
      local src="$SRC/${lang}_${prefix}${name}.${ext}"
      [ -f "$src" ] || { echo "missing $src"; continue; }
      url="$url&img=file://$src"
    fi
    render "$TMP/shot.png" "$w" "$h" "$url"
    jpg "$TMP/shot.png" "$out/$(printf '%02d' $i)_$name.jpg"
    i=$((i+1))
  done
  echo "$out: $((i-1)) images"
}

for lang in en ru; do
  if [ "$lang" = en ]; then rows=("${EN[@]}"); foot="$FOOT_EN"; else rows=("${RU[@]}"); foot="$FOOT_RU"; fi
  build_set "$lang" "$STORE/screenshots/play/$lang"          phone  1080 1920 ""          jpg "$foot" "${rows[@]}"
  build_set "$lang" "$STORE/screenshots/play-tablet/$lang"   tablet 2560 1600 "tablet10_" png "$foot" "${rows[@]}"
  build_set "$lang" "$STORE/screenshots/appstore/$lang"      iphone 1290 2796 "iphone67_" png "$foot" "${rows[@]}"
  build_set "$lang" "$STORE/screenshots/appstore-ipad/$lang" ipad   2064 2752 "ipad13_"   png "$foot" "${rows[@]}"
done

render "$TMP/feature.png" 1024 500 "file://$STORE/tools/feature.html?icon=file://$ROOT/assets/icons/icon.png&h=$(enc 'Yandex Advertising Network stats in your pocket')&p=$(enc 'Revenue today, full reports, home-screen widgets and daily summaries. Private: no server, no ads. Unofficial.')"
cp "$TMP/feature.png" "$STORE/feature_graphic.png"
sips -Z 512 "$ROOT/assets/icons/icon.png" --out "$STORE/icon_512.png" >/dev/null
rm -rf "$TMP"
echo "done"

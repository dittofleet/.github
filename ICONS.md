# Icons

Each tool has a light and dark icon in `assets/`: hand-written SVGs, exported to 1024px PNG and ICNS.

## Make one

What makes the set read as a family is the squircle tile, its shadow and the glyph area (`<g transform="translate(23 23) scale(.54)">`); take those from any existing icon. The symbol and colours are yours to design.

Most icons follow this colour scheme:

| | Light | Dark |
| --- | --- | --- |
| Tile gradient | hue → deeper shade | `#3a3a3e` → `#1f1f22` |
| Symbol | `#fff` | hue |
| Secondary | `#fff` at `.72` opacity | soft tint |
| Cut-outs | deeper shade | `#26262a` |

## Export

Render with Chrome; other SVG renderers get the shadow wrong. From the tool's repo root:

```sh
chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
tmp=$(mktemp -d)
for v in icon icon-dark; do
  "$chrome" --headless=new --disable-gpu --hide-scrollbars --user-data-dir="$tmp/chrome" \
    --force-device-scale-factor=1 --default-background-color=00000000 \
    --window-size=1024,1024 --screenshot="$PWD/assets/$v.png" "file://$PWD/assets/$v.svg"
  mkdir "$tmp/$v.iconset"
  for s in 16 32 128 256 512; do
    sips -z $s $s assets/$v.png --out "$tmp/$v.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) assets/$v.png --out "$tmp/$v.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns -o assets/$v.icns "$tmp/$v.iconset"
done
rm -rf "$tmp"
```

Check both at 32px and 16px beside a few siblings. The README starts with `<img src="assets/icon.svg" width="80" alt="<tool> icon">`.

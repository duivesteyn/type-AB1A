#!/usr/bin/env python3
"""Rebuild art/Clock-Live-Preview.html from the app's own artwork.

Run ./Scripts/render-previews.sh first: it writes the body and glass layers to
build/Previews. Hand, hub and button geometry is read from ClockDesign.swift so the
browser preview cannot drift from the native clock.
"""
import base64, re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
design = (root / 'Sources/Shared/ClockDesign.swift').read_text()

def num(name):
    return float(re.search(rf'static let {name}: CGFloat = ([\d.]+)', design).group(1))

def hand(name):
    m = re.search(rf'static let {name} = Hand\(length: ([\d.]+), width: ([\d.]+), tail: ([\d.]+)\)', design)
    return tuple(float(v) for v in m.groups())

def b64(path):
    return base64.b64encode((root / path).read_bytes()).decode()

hx, hy, hw, hh = (float(v) for v in re.search(r'static let housing = CGRect\(x: ([\d.]+), y: ([\d.]+), width: ([\d.]+), height: ([\d.]+)\)', design).groups())
button_w, rest, travel = num('buttonWidth'), num('buttonRest'), num('buttonTravel')
hour, minute, second = hand('hourHand'), hand('minuteHand'), hand('secondHand')
cw_r, cw_off, hub_r = num('counterweightRadius'), num('counterweightOffset'), num('hubRadius')
cap_x, cap_top, cap_bottom = 627 - button_w / 2, hy - rest, hy + 24

def white_hand(id_, h):
    length, width, tail = h
    return (f'<g filter="url(#lift{id_})"><g id="{id_}" transform="translate(627 677)">'
            f'<rect x="{-width/2:g}" y="{-length:g}" width="{width:g}" height="{length+tail:g}" rx="{width/2:g}" fill="url(#handWhite)"/></g></g>')

def shadow(id_, lift):
    return (f'<filter id="lift{id_}" x="-50%" y="-50%" width="200%" height="200%">'
            f'<feDropShadow dx="{lift*0.25:g}" dy="{lift:g}" stdDeviation="{(4+lift)/2:g}" flood-color="#000" flood-opacity=".5"/></filter>')

svg = f'''<svg viewBox="76 98 1102 1102" aria-label="Clock with live vector hands"><defs>
<linearGradient id="handWhite" x1="0" y1="0" x2="1" y2="0"><stop stop-color="#FFFFFF"/><stop offset=".45" stop-color="#F5F5F2"/><stop offset="1" stop-color="#D4D4CF"/></linearGradient>
<linearGradient id="secondYellow" x1="0" y1="0" x2="1" y2="0"><stop stop-color="#FFE14A"/><stop offset=".5" stop-color="#FFD203"/><stop offset="1" stop-color="#EABF00"/></linearGradient>
<radialGradient id="hubYellow" cx=".34" cy=".3" r=".72"><stop stop-color="#FFE866"/><stop offset=".5" stop-color="#FFD203"/><stop offset="1" stop-color="#E8BC00"/></radialGradient>
<linearGradient id="capFront" x1="0" y1="0" x2="0" y2="1"><stop stop-color="#37383B"/><stop offset=".45" stop-color="#232426"/><stop offset="1" stop-color="#1A1B1D"/></linearGradient>
{shadow('hour', 4)}{shadow('minute', 5)}{shadow('second', 7)}{shadow('hub', 7)}
</defs>
<g id="cap"><path d="M{cap_x:g} {cap_bottom:g} V{cap_top+9:g} Q{cap_x:g} {cap_top:g} {cap_x+9:g} {cap_top:g} H{cap_x+button_w-9:g} Q{cap_x+button_w:g} {cap_top:g} {cap_x+button_w:g} {cap_top+9:g} V{cap_bottom:g} Z" fill="url(#capFront)"/>
<rect x="{cap_x+2:g}" y="{cap_top:g}" width="{button_w-4:g}" height="9" rx="4" fill="#47484B"/>
<ellipse cx="627" cy="{cap_top+4.5:g}" rx="22" ry="2.6" fill="#88D672"/></g>
<image x="76" y="98" width="1102" height="1102" href="data:image/png;base64,{b64('build/Previews/Layer-Body.png')}"/>
{white_hand('hour', hour)}
{white_hand('minute', minute)}
<g filter="url(#liftsecond)"><g id="second" transform="translate(627 677)"><rect x="{-second[1]/2:g}" y="{-second[0]:g}" width="{second[1]:g}" height="{second[0]+second[2]:g}" rx="{second[1]/2:g}" fill="url(#secondYellow)"/><circle cy="{cw_off:g}" r="{cw_r:g}" fill="url(#secondYellow)"/></g></g>
<circle cx="627" cy="677" r="{hub_r:g}" fill="url(#hubYellow)" stroke="#D9AE00" stroke-width="2" filter="url(#lifthub)"/>
<image x="76" y="98" width="1102" height="1102" href="data:image/png;base64,{b64('build/Previews/Layer-Glass.png')}"/>
<rect id="topControl" x="{cap_x-20:g}" y="98" width="{button_w+40:g}" height="{cap_bottom-98+10:g}" fill="transparent" tabindex="0" role="button" aria-label="Set alarm" aria-pressed="false"/></svg>'''

html = f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Type AB1 — live artwork preview</title><style>
:root{{color-scheme:light dark;--bg:#e9ebed;--fg:#222;--muted:#555;--panel:#f5f5f2;--line:#bbb}}
@media (prefers-color-scheme:dark){{:root{{--bg:#16171a;--fg:#eee;--muted:#aaa;--panel:#232427;--line:#444}}}}
body{{margin:0;background:var(--bg);color:var(--fg);font:15px system-ui;display:grid;place-items:center;min-height:100vh}}.wrap{{width:min(100% - 32px,620px);text-align:center;padding:20px 0}}svg{{width:100%;height:auto;max-height:72vh}}button,select{{font:inherit;padding:9px 15px;border:1px solid var(--line);border-radius:7px;background:var(--panel);color:var(--fg);margin:4px}}p{{color:var(--muted)}}#topControl{{cursor:pointer}}#topControl:focus{{outline:none}}#topControl:focus-visible{{stroke:#88D672;stroke-width:3}}dialog{{max-width:420px;border:1px solid var(--line);border-radius:20px;padding:28px;background:var(--panel);color:var(--fg)}}</style>
<div class="wrap"><h1 style="font-size:20px;font-weight:500;margin:0">Type AB1</h1><p id="zoneStatus">System clock · your Mac’s time zone</p>{svg}
<div><button id="toggle">Set alarm — button up</button><select id="tz" aria-label="Time zone"><option value="system">System time zone</option><option>Australia/Adelaide</option><option>Europe/London</option><option>Pacific/Auckland</option><option>America/New_York</option><option>UTC</option></select></div><p id="state">Preview: alarm off · button down</p><p>Artwork preview only; the alarm button demonstrates its state and does not schedule a sound.</p><button id="aboutOpen">About this little clock</button><dialog id="aboutDialog" aria-labelledby="aboutTitle"><img width="96" height="96" alt="Clock icon" src="data:image/png;base64,{b64('Resources/icon-256.png')}"><h2 id="aboutTitle">Type AB1</h2><p>A little square. A yellow second. A quieter desktop.</p><p>A tribute to the AB 1, designed by Dietrich Lubs in 1987, and to a design tradition that knew when to stop.</p><p>Made by Benjamin Duivesteyn · MIT License</p><button id="aboutClose">Back to the ticking</button></dialog></div>
<script>
document.getElementById('aboutOpen').onclick=()=>document.getElementById('aboutDialog').showModal();document.getElementById('aboutClose').onclick=()=>document.getElementById('aboutDialog').close();
let armed=false,p=0,raf;const cap=document.getElementById('cap'),topControl=document.getElementById('topControl');
function drawButton(v){{p=v;cap.setAttribute('transform',`translate(0 ${{-{travel:g}*v}})`);}}
function toggle(){{armed=!armed;cancelAnimationFrame(raf);const from=p,to=armed?1:0,start=performance.now(),reduce=matchMedia('(prefers-reduced-motion: reduce)').matches;document.getElementById('state').textContent=armed?'Preview: alarm armed · button up':'Preview: alarm off · button down';document.getElementById('toggle').textContent=armed?'Turn alarm off — button down':'Set alarm — button up';topControl.setAttribute('aria-pressed',String(armed));topControl.setAttribute('aria-label',armed?'Turn alarm off':'Set alarm');function step(now){{let t=reduce?1:Math.min((now-start)/160,1);let ease=t*t*(3-2*t);drawButton(from+(to-from)*ease);if(t<1)raf=requestAnimationFrame(step);}}raf=requestAnimationFrame(step);}}
document.getElementById('toggle').onclick=toggle;topControl.onclick=toggle;topControl.onkeydown=e=>{{if(e.key==='Enter'||e.key===' '){{e.preventDefault();toggle();}}}};
const tz=document.getElementById('tz');try{{const saved=localStorage.getItem('clock.zone');if([...tz.options].some(o=>o.value===saved))tz.value=saved;}}catch{{}}
let formatter;function zone(){{try{{localStorage.setItem('clock.zone',tz.value);}}catch{{}}formatter=new Intl.DateTimeFormat('en-GB',{{timeZone:tz.value==='system'?undefined:tz.value,hour:'numeric',minute:'numeric',second:'numeric',hourCycle:'h23'}});tick();}}
function tick(){{const z=formatter.resolvedOptions().timeZone;document.getElementById('zoneStatus').textContent='System clock · '+(tz.value==='system'?'system time zone: ':'display city: ')+z;let x={{}};for(const a of formatter.formatToParts(new Date()))x[a.type]=a.value;const h=Number(x.hour),m=Number(x.minute),s=Number(x.second);for(const [id,a] of [['hour',30*((h%12)+m/60+s/3600)],['minute',6*(m+s/60)],['second',6*s]])document.getElementById(id).setAttribute('transform',`translate(627 677) rotate(${{a}})`);}}
document.getElementById('tz').onchange=zone;zone();function alignedTick(){{tick();setTimeout(alignedTick,1000-Date.now()%1000+5);}}alignedTick();document.addEventListener('visibilitychange',()=>{{if(!document.hidden)tick();}});drawButton(0);
</script></html>
'''
(root / 'art/Clock-Live-Preview.html').write_text(html)
print(f'Wrote art/Clock-Live-Preview.html ({len(html)//1024} KB)')

#!/bin/bash
# mac-checkup · diagnóstico de SOLO LECTURA. No mata procesos, no borra, no cambia ajustes.
# Uso: bash diagnostico.sh   (tarda de 10 a 60 s, según el tamaño de las cachés)
# Imprime secciones "== NOMBRE ==" que el skill lee para armar el reporte.

set -u
H() { printf '\n== %s ==\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }
# etime de ps ([[dd-]hh:]mm:ss) a segundos
secs() { echo "$1" | awk -F'[-:]' '{n=NF; s=$n+$(n-1)*60; if(n>=3)s+=$(n-2)*3600; if(n>=4)s+=$(n-3)*86400; print s}'; }
cwd_of() { lsof -p "$1" -a -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2- | sed "s#^$HOME#~#"; }
size_of() { [ -e "$1" ] && du -sh "$1" 2>/dev/null | cut -f1; }
# Carpetas de código que existen, sin repetir: el disco de la Mac no distingue mayúsculas,
# así que ~/Developer y ~/developer son la misma (mismo inodo).
code_dirs() {
  seen=" "
  for d in Developer developer Projects projects Code code dev src repos GitHub github Sites orca conductor workspace; do
    p="$HOME/$d"; [ -d "$p" ] || continue
    i=$(stat -f %i "$p"); case "$seen" in *" $i "*) continue;; esac
    seen="$seen$i "; echo "$p"
  done
}

H "SISTEMA"
echo "macOS $(sw_vers -productVersion) · $(sysctl -n machdep.cpu.brand_string) · $(( $(sysctl -n hw.memsize) / 1073741824 )) GB RAM · $(sysctl -n hw.ncpu) núcleos"
echo "Encendida: $(uptime | sed -E 's/.*up ([^,]*(, [0-9]+:[0-9]+)?),.*/\1/')"
echo "Carga: $(sysctl -n vm.loadavg)"

H "MEMORIA"
sysctl -n vm.swapusage
memory_pressure 2>/dev/null | tail -1
vm_stat | grep -E 'Pageins|Pageouts'

H "APPS QUE MÁS MEMORIA USAN (suma de todos sus procesos, MB)"
ps -Aceo rss=,comm= | awk '{r=$1; $1=""; sub(/^ /,""); n=$0; sub(/ Helper.*$/,"",n); m[n]+=r; c[n]++} END {for (k in m) printf "%8.0f MB  %3d proc  %s\n", m[k]/1024, c[k], k}' | sort -rn | head -15

H "PROCESOS QUE MÁS CPU USAN"
ps -Aceo pid,pcpu,etime,rss,comm -r | head -13

H "POSIBLES PROCESOS TRABADOS (>=50% CPU por más de 1 h)"
ps -Ao pid=,pcpu=,etime=,rss=,command= | while read -r pid cpu et rss cmd; do
  c=${cpu%.*}; [ "${c:-0}" -ge 50 ] || continue
  [ "$(secs "$et")" -ge 3600 ] || continue
  net=$(lsof -nP -p "$pid" -a -i 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
  files=$(lsof -nP -p "$pid" 2>/dev/null | awk '$4 ~ /^[0-9]+[rwu]$/ && $5=="REG"' | wc -l | tr -d ' ')
  echo "PID $pid · ${cpu}% CPU · lleva $et · $((rss/1024)) MB · conexiones de red: $net · archivos abiertos: $files"
  echo "   comando: $(echo "$cmd" | cut -c1-160)"
  echo "   carpeta: $(cwd_of "$pid")"
done

H "SERVIDORES DE DESARROLLO ESCUCHANDO EN UN PUERTO"
lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1 && $1 ~ /^(node|bun|deno|python|Python|ruby|php|java|next-serv|vite|go|uvicorn|gunicorn|rails|esbuild)/ {split($9,a,":"); print $2, a[length(a)]}' | sort -u -k1,1 | while read -r pid port; do
  echo ":$port · PID $pid · lleva $(ps -o etime= -p "$pid" | tr -d ' ') · $(ps -o command= -p "$pid" | cut -c1-70)"
  echo "   carpeta: $(cwd_of "$pid")"
done

H "SESIONES DE AGENTES DE IA EN TERMINAL"
for name in claude codex aider gemini opencode cursor-agent amp; do
  ps -Ao pid=,etime=,tty=,rss=,comm= | awk -v n="$name" '$5==n || $5 ~ "/"n"$"' | while read -r pid et tty rss comm; do
    echo "$name · PID $pid · abierta hace $et · $tty · $((rss/1024)) MB · $(cwd_of "$pid")"
  done
done

H "DOCKER Y MÁQUINAS VIRTUALES"
ps -Aceo pid=,pcpu=,rss=,comm= | grep -E 'Virtualization\.VirtualMachine|qemu-system|OrbStack|colima|vmware-vmx|prl_vm_app| UTM$' | awk '{printf "PID %s · %s%% CPU · %d MB · %s\n", $1, $2, $3/1024, $4}'
if have docker && docker info >/dev/null 2>&1; then
  echo "Memoria asignada a Docker: $(docker info --format '{{.MemTotal}}' | awk '{printf "%.1f GB", $1/1073741824}')"
  echo "Contenedores encendidos: $(docker ps -q | wc -l | tr -d ' ') · apagados: $(docker ps -aq --filter status=exited | wc -l | tr -d ' ')"
  echo "-- por proyecto (encendidos) --"
  docker ps --format '{{.Label "com.docker.compose.project"}}|{{.Names}}' | awk -F'|' '{p=$1; if(p==""){p=$2; sub(/^supabase_[a-z_]+_/,"supabase:",p); if(p==$2)p="(sueltos)"} c[p]++} END {for(k in c) printf "%3d  %s\n", c[k], k}' | sort -rn
  echo "-- consumo por contenedor --"
  docker stats --no-stream --format '{{.MemUsage}}|{{.CPUPerc}}|{{.Name}}' | sort -t'|' -k1 -h -r | head -15 | awk -F'|' '{printf "%-22s %7s  %s\n", $1, $2, $3}'
  echo "-- contenedores con más de 7 días encendidos --"
  docker ps --format '{{.Status}}|{{.Names}}' | grep -E 'Up ([0-9]+ (weeks|months)|[0-9]{2,} days|[7-9] days)' | awk -F'|' '{print "  " $2 " · " $1}'
  echo "-- espacio en disco --"
  docker system df
  echo "OJO: 'supabase stop' BORRA los contenedores (conserva los datos). Después de eso, 'docker image prune -a' también borra sus imágenes."
else
  echo "Docker no está instalado o no está encendido."
fi

H "DISCO"
df -h /System/Volumes/Data 2>/dev/null | tail -1 | awk '{print "Usado " $3 " de " $2 " · libre " $4 " (" $5 ")"}'
free_pct=$(df -k /System/Volumes/Data | tail -1 | awk '{printf "%d", $4*100/$2}')
[ "$free_pct" -lt 15 ] && echo "ALERTA: queda ${free_pct}% libre. Con menos de ~15% el swap y las actualizaciones se vuelven lentos."
echo "-- snapshots locales de Time Machine (ocupan espacio que Finder no muestra) --"
tmutil listlocalsnapshots / 2>/dev/null | grep -c 'com.apple' | awk '{print "  " $1 " snapshots"}'

H "PROYECTOS VIEJOS CON node_modules / .next (último commit hace más de 30 días)"
now=$(date +%s)
for base in $(code_dirs); do
  for p in "$base"/*/ "$base"/*/*/; do
    p=${p%/}; [ -d "$p/node_modules" ] || [ -d "$p/.next" ] || continue
    last=$(git -C "$p" log -1 --format=%ct 2>/dev/null || stat -f %m "$p")
    age=$(( (now - ${last:-$now}) / 86400 )); [ "$age" -ge 30 ] || continue
    nm=$(size_of "$p/node_modules"); nx=$(size_of "$p/.next")
    echo "  hace ${age} días · node_modules ${nm:--} · .next ${nx:--} · ${p/#$HOME/~}"
  done
done

H "ARCHIVOS GRANDES E INSTALADORES OLVIDADOS"
echo "-- archivos de más de 1 GB en Descargas, Escritorio, Películas y Documentos --"
find "$HOME/Downloads" "$HOME/Desktop" "$HOME/Movies" "$HOME/Documents" -maxdepth 3 -type f -size +1G 2>/dev/null | while read -r f; do printf "  %7s  %s\n" "$(du -h "$f" | cut -f1)" "${f/#$HOME/~}"; done
echo "-- instaladores y comprimidos en Descargas (.dmg .pkg .zip .iso) --"
find "$HOME/Downloads" -maxdepth 2 -type f \( -iname '*.dmg' -o -iname '*.pkg' -o -iname '*.zip' -o -iname '*.iso' \) -print0 2>/dev/null | xargs -0 du -ck 2>/dev/null | tail -1 | awk '{printf "  %.1f GB en total\n", $1/1048576}'
find "$HOME/Downloads" -maxdepth 2 -type f \( -iname '*.dmg' -o -iname '*.pkg' -o -iname '*.zip' -o -iname '*.iso' \) 2>/dev/null | wc -l | awk '{print "  " $1 " archivos"}'

H "OTROS LUGARES QUE CRECEN SIN QUE TE DES CUENTA"
check2() { s=$(size_of "$2"); [ -n "$s" ] && printf "%7s  %s  (%s)\n" "$s" "$1" "${2/#$HOME/~}"; }
check2 "Respaldos de iPhone/iPad" "$HOME/Library/Application Support/MobileSync/Backup"
check2 "Adjuntos de Mensajes" "$HOME/Library/Messages/Attachments"
check2 "Descargas de Mail" "$HOME/Library/Containers/com.apple.mail/Data/Library/Mail Downloads"
check2 "Xcode iOS DeviceSupport" "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
check2 "Emuladores de Android" "$HOME/.android/avd"
check2 "Logs de apps" "$HOME/Library/Logs"
check2 "WhatsApp" "$HOME/Library/Group Containers/group.net.whatsapp.WhatsApp.shared"
check2 "Slack" "$HOME/Library/Containers/com.tinyspeck.slackmacgap/Data/Library/Application Support/Slack"
check2 "Perfil de Chrome" "$HOME/Library/Application Support/Google/Chrome"
check2 "Conda" "$HOME/miniconda3"
check2 "Conda" "$HOME/anaconda3"
if have docker && docker info >/dev/null 2>&1; then
  echo "Volúmenes de Docker huérfanos: $(docker volume ls -qf dangling=true | wc -l | tr -d ' ')"
fi

H "APPS QUE NO ABRES DESDE HACE MÁS DE 6 MESES (o que macOS nunca vio abrir)"
cutoff=$(( $(date +%s) - 180*86400 ))
for a in /Applications/*.app; do
  case "$a" in *Uninstaller*|*Desinstalar*) continue;; esac
  d=$(mdls -raw -name kMDItemLastUsedDate "$a" 2>/dev/null)
  if [ "$d" = "(null)" ] || [ -z "$d" ]; then when="sin registro de uso"
  else
    t=$(date -j -f '%Y-%m-%d %H:%M:%S %z' "$d" +%s 2>/dev/null) || continue
    [ "$t" -lt "$cutoff" ] || continue; when="último uso ${d%% *}"
  fi
  printf "  %7s  %-22s  %s\n" "$(du -sh "$a" 2>/dev/null | cut -f1)" "$when" "$(basename "$a" .app)"
done | sort -rh

H "CACHÉS QUE SE PUEDEN LIMPIAR (tamaño)"
check() { s=$(size_of "$2"); [ -n "$s" ] && printf "%7s  %s  (%s)\n" "$s" "$1" "${2/#$HOME/~}"; }
check "Papelera" "$HOME/.Trash"
check "Cachés de apps (general)" "$HOME/Library/Caches"
check "Xcode DerivedData" "$HOME/Library/Developer/Xcode/DerivedData"
check "Simuladores de iOS" "$HOME/Library/Developer/CoreSimulator/Devices"
check "Xcode Archives" "$HOME/Library/Developer/Xcode/Archives"
check "npm" "$HOME/.npm"
check "bun" "$HOME/.bun/install/cache"
check "pnpm" "$HOME/Library/pnpm/store"
check "Yarn" "$HOME/Library/Caches/Yarn"
check "pip" "$HOME/Library/Caches/pip"
check "Playwright (navegadores)" "$HOME/Library/Caches/ms-playwright"
check "Puppeteer" "$HOME/.cache/puppeteer"
check "Gradle" "$HOME/.gradle/caches"
check "Cargo" "$HOME/.cargo/registry"
check "Ollama (modelos)" "$HOME/.ollama/models"
have brew && check "Homebrew" "$(brew --cache 2>/dev/null)"

H "SPOTLIGHT"
mdutil -s /System/Volumes/Data 2>/dev/null | tail -1
ps -Aceo pcpu=,comm= | grep -E 'mds|mdworker' | awk '{s+=$1} END {printf "CPU de Spotlight ahora: %.0f%%\n", s}'
echo "-- carpetas de código que Spotlight está indexando (conviene excluirlas) --"
for p in $(code_dirs); do
  if [ -n "$(mdfind -onlyin "$p" -name package.json 2>/dev/null | head -1)" ]; then echo "  INDEXADA  ${p/#$HOME/~}"; else echo "  excluida o sin package.json  ${p/#$HOME/~}"; fi
done

H "CARPETAS QUE ABRE EL SELECTOR DE ARCHIVOS"
for d in Desktop Downloads Documents; do printf "%-10s %5s elementos en el primer nivel\n" "$d" "$(ls -A "$HOME/$d" 2>/dev/null | wc -l | tr -d ' ')"; done
if [ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Desktop" ] || [ "$(defaults read com.apple.finder FXICloudDriveDesktop 2>/dev/null)" = "1" ]; then
  echo "Escritorio y Documentos: se sincronizan con iCloud (probable)"
else
  echo "Escritorio y Documentos: locales"
fi

H "IMÁGENES DE DISCO MONTADAS (instaladores olvidados)"
hdiutil info 2>/dev/null | grep 'image-path' | sed -E 's/.*image-path *: *//' | sed "s#^$HOME#~#"

H "PROGRAMAS QUE ARRANCAN SOLOS (LaunchAgents/Daemons)"
for d in "$HOME/Library/LaunchAgents" /Library/LaunchAgents /Library/LaunchDaemons; do
  [ -d "$d" ] || continue
  echo "-- ${d/#$HOME/~}"; ls "$d" 2>/dev/null | sed 's/\.plist$//; s/^/  /'
done

echo; echo "Fin del diagnóstico. No se cambió nada."

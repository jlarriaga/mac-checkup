---
name: mac-checkup
description: Revisa por qué una Mac está lenta o sin espacio y la deja mejor, de la mano y paso por paso. Diagnostica sin tocar nada (memoria, swap, procesos trabados, servidores de desarrollo olvidados, Docker, sesiones de agentes de IA, Spotlight, cachés, archivos grandes), explica cada hallazgo en palabras simples con lo que libera y por qué, y pide aprobación uno por uno antes de hacer cualquier cosa. Usar cuando el usuario diga que su Mac está lenta, que se traba, que no tiene espacio, que tarda en abrir o adjuntar archivos, o pida "limpiar", "optimizar" o "darle mantenimiento" a su Mac.
---

# /mac-checkup · deja tu Mac mejor, paso por paso

Para gente que programa (o "vibecodea") todo el día y nunca limpia: servidores de desarrollo que
quedan prendidos días, contenedores de Docker de proyectos viejos, diez sesiones de agentes
abiertas, scripts trabados al 100% de CPU, gigas de cachés. Nada de eso se apaga solo.

**Responde en el idioma del usuario.** Habla en palabras simples: el usuario quizá no sabe qué es
el swap o un contenedor. Explica el *qué* y el *por qué* en una línea, sin sermón.

## Reglas que no se rompen

1. **Primero se mira, luego se toca.** El diagnóstico es de solo lectura. No matas, borras ni
   cambias nada hasta que el usuario apruebe ESE punto en concreto.
2. **Uno por uno.** Cada acción se pregunta por separado (con la herramienta de preguntas si
   existe), se ejecuta, se verifica, y hasta entonces se pregunta la siguiente. Nunca "¿hago
   todo?". Si el usuario responde algo distinto de sí/no, léelo con cuidado y haz lo que dijo.
3. **Cada pregunta dice: qué es, qué libera (con número), por qué conviene, qué pasa después
   y si se puede deshacer.** Formato:
   > **3/9 · Apagar el Supabase de `elchecador`** — libera ~1.5 GB de RAM. Lleva 10 días
   > prendido y el último commit fue hace 11. Los datos se conservan; para volverlo a usar:
   > `supabase start`. ¿Lo apago?
4. **Nunca borres archivos del usuario** (Descargas, Escritorio, Documentos, videos, `.mbox`).
   Solo los señalas con su tamaño; borrarlos lo decide y lo hace el usuario. La Papelera se vacía
   solo con un sí explícito porque no hay vuelta atrás.
5. **Nunca uses `sudo`, nunca toques `/System`, nunca `rm -rf` a una caché a mano.** Usa el
   comando propio de cada herramienta (`npm cache clean --force`, `brew cleanup`,
   `docker builder prune`, `xcrun simctl delete unavailable`). Si algo pide contraseña de
   administrador, pásalo a la lista de "te toca a ti".
6. **No cierres sesiones de agentes de IA (claude, codex, etc.) por tu cuenta.** Matarlas corta
   lo que el usuario tenga a medias. Lístalas y que él las cierre desde su terminal
   (`claude --resume` recupera la conversación).
7. **Verifica cada acción con un dato** (el puerto quedó libre, el proceso ya no existe, cuántos
   GB se liberaron). Si te equivocaste en algo que dijiste antes, corrígelo en voz alta antes del
   siguiente paso.

## Paso 1 · Diagnóstico (solo lectura)

```bash
bash ~/.claude/skills/mac-checkup/scripts/diagnostico.sh
```

Tarda 10–60 s. Si algo puntual necesita más contexto (qué hace un proceso, de qué proyecto es
un servidor, si un proyecto sigue activo), investígalo con comandos de solo lectura: `ps`,
`lsof -p <pid>`, `git -C <carpeta> log -1`, `cat package.json`, leer el script que corre.

## Paso 2 · Reporte

Una tabla corta ordenada por impacto, en tres grupos:

- **Lo que más pesa** (memoria/CPU/disco) con el número.
- **Lo que puedo hacer yo** (numerado: 1/N, 2/N…) con lo que libera cada uno.
- **Lo que te toca a ti** (ajustes de la interfaz, cosas con contraseña, decidir qué borrar).

Cierra con: "Te voy a preguntar uno por uno". Y empieza con la pregunta 1.

## Paso 3 · Uno por uno

Ordena por impacto: primero lo que libera RAM/CPU (la lentitud), luego disco.

## Paso 4 · Cierre

Tabla de lo hecho (acción → resultado medido), lo que el usuario dijo que no, y los pasos
manuales con instrucciones exactas (menú → submenú → botón). Si el swap estaba alto, recuerda
que **solo se vacía reiniciando** y ofrece volver a medir después del reinicio.

---

## Catálogo de hallazgos

Umbral → qué significa en simple → qué hacer → trampas.

### Memoria y CPU (esto es la lentitud)

**Swap alto** (usado > 50% del total, o pageins en cientos de millones)
La RAM se acabó y macOS está usando el disco como memoria; todo lo que abre una ventana nueva
(como el selector de archivos al adjuntar) se tarda. No se arregla con un comando: se arregla
liberando RAM (lo de abajo) y **reiniciando**. Uptime de más de 7 días lo empeora.

**Proceso trabado** (≥ 50% CPU por más de 1 h)
Si además tiene **0 conexiones de red y 0 archivos abiertos**, está girando sin hacer nada (un
ciclo infinito). Antes de proponer matarlo: lee qué comando es y de qué proyecto, y si escribe a
una base de datos (`--remote`, `--prod`), lee el script para decir si matarlo a la mitad deja
algo roto. Matar: `kill <pid>` (y su padre si es un `bun run`/`npm run`); `kill -9` solo si no
muere en 2 s. Verifica con `ps -p <pid>`. Ofrece investigar por qué se trabó.

**Servidores de desarrollo olvidados** (`next dev`, `vite`, `serve`, `python -m http.server`…)
Cada uno come RAM y CPU vigilando archivos. Candidato a apagar: lleva días prendido **y** su
proyecto no tiene commits recientes, o vive en una carpeta temporal (`/tmp`, `scratchpad`,
`.claude/worktrees/agent-*`). No propongas apagar uno con commits de hoy. Apagar: `kill` al
proceso (y a su `zsh`/`npm run` padre). Verifica que el puerto quedó libre
(`lsof -nP -iTCP:<puerto> -sTCP:LISTEN`).

**Docker**
- Agrupa por proyecto y cruza con la actividad del repo (`git log -1`). Proyecto sin commits en
  más de ~7 días → candidato a apagar.
- **Supabase local**: `supabase stop` desde la carpeta del proyecto. **Ojo: borra los
  contenedores** (los datos quedan en volúmenes). Dilo así, no digas "se conservan".
- Contenedores sueltos: `docker stop <nombres>` (se conservan; `docker start` para volver).
- Antes de apagar algo que "podría usar" un servidor que sí está activo, revisa su `.env` (solo
  los NOMBRES de las variables y los puertos, nunca imprimas valores secretos) para ver si de
  verdad lo usa.
- `supabase_analytics_*` y `supabase_vector_*` suelen comer ~1 GB por proyecto y casi nadie los
  usa en local. Se apagan con `[analytics] enabled = false` en `supabase/config.toml`, pero ese
  archivo va en git: pregunta, no lo cambies por default.
- Memoria asignada a la VM de Docker > 6 GB en una Mac de 16–24 GB → sugiere bajarla en
  Docker Desktop → Settings → Resources (te toca a ti).

**Sesiones de agentes de IA** (claude, codex, aider…)
Cada una pesa 100–400 MB y hay gente con 15 abiertas. Lista las de más de ~3 días con su carpeta;
el usuario las cierra (regla 6).

**Chrome** con muchos GB → sugerir cerrar pestañas o usar Memory Saver (Ajustes de Chrome →
Rendimiento). No lo cierres tú.

### Disco

Pregunta cada uno por separado, con su tamaño:

| Qué | Cómo se limpia | Qué pasa después |
|---|---|---|
| Caché de builds de Docker | `docker builder prune -af` | Los próximos builds tardan un poco más |
| Imágenes de Docker sin usar | `docker image prune -af` | Se vuelven a descargar al usarlas. **Incluye las de proyectos que apagaste con `supabase stop`**; dilo antes de preguntar |
| Volúmenes de Docker huérfanos | `docker volume ls -f dangling=true` → enséñalos → `docker volume prune` | **Son datos de bases de datos viejas; se pierden.** Pregunta con la lista enfrente |
| npm | `npm cache clean --force` | Las instalaciones bajan los paquetes de nuevo |
| bun | `bun pm cache rm` | Igual |
| pnpm | `pnpm store prune` | Solo borra lo que ningún proyecto usa |
| pip | `pip cache purge` | Igual |
| Homebrew | `brew cleanup --prune=all` | Borra versiones viejas y descargas |
| Xcode DerivedData | `rm -rf ~/Library/Developer/Xcode/DerivedData/*` (excepción a la regla 5: Xcode no tiene comando y es 100% regenerable) | El próximo build de Xcode es más lento |
| Simuladores de iOS | `xcrun simctl delete unavailable` | Solo borra los de versiones que ya no tienes |
| Xcode iOS DeviceSupport | Enséñalo; que el usuario borre versiones viejas de iOS | Se regenera al conectar un iPhone |
| Playwright / Puppeteer | `npx playwright uninstall --all` | Se reinstalan con `npx playwright install` |
| `node_modules` de proyectos sin commits en 30+ días | `rm -rf <proyecto>/node_modules` (y `.next`), **un proyecto a la vez, nombrándolo** | Se recupera con `npm install` / `bun install`. Antes revisa que no sea un worktree con cambios sin commit (`git status`) |
| Papelera | Solo con sí explícito; mejor que el usuario la vacíe | **No hay vuelta atrás** |

Cosas que **solo señalas** (regla 4): archivos > 1 GB en Descargas/Escritorio, instaladores
`.dmg/.pkg/.zip` olvidados, respaldos viejos de iPhone, WhatsApp/Mensajes con muchos GB (se
limpian desde la app: WhatsApp → Ajustes → Almacenamiento), apps sin abrir en 6+ meses.
**"Sin registro de uso" no significa que no se use** (Xcode o Excel pueden salir así): pregúntalo,
no lo recomiendes.

Imágenes de disco montadas (instaladores olvidados) → `hdiutil detach <disco>`; inofensivo.

### Spotlight y el selector de archivos

- **Carpetas de código indexadas** (`~/Developer`, `~/Projects`… con `node_modules`): Spotlight
  gasta CPU indexando miles de archivos que nadie busca. Se excluyen en **Ajustes del Sistema →
  Spotlight → Privacidad de búsqueda → +** (te toca a ti; ⌘⇧H lleva a la carpeta personal).
  Verifica después con `mdfind -onlyin <carpeta> -name package.json` → debe dar 0, y compara
  contra `~/Documents`, que sí debe dar resultados.
- **`.metadata_never_index` ya no funciona** en macOS moderno. No lo propongas.
- **No excluyas Documentos, Descargas ni Escritorio**: es donde la gente busca lo que adjunta;
  sin Spotlight, "Recientes" y la búsqueda del selector dejan de encontrarlos.
- **Descargas con más de ~500 elementos** en el primer nivel hace lento el selector. Sugiere
  mover lo viejo a una subcarpeta (lo hace el usuario).
- **Escritorio y Documentos en iCloud** hace que el selector consulte a iCloud. Opcional
  apagarlo (Ajustes → [nombre] → iCloud → iCloud Drive) y solo después de confirmar que todo
  está descargado.
- `mds`/`mdworker` alto justo después de excluir carpetas es normal: está sacándolas del
  índice. Baja solo en minutos.

### Arranque

Los agentes de actualización (Google, Microsoft, Zoom, Adobe) casi no consumen. No vale la pena
el riesgo de tocarlos; menciónalo en una línea y ya. Si hay algo desconocido o de un programa
que el usuario ya desinstaló, señálalo.

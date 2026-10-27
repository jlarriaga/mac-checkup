# mac-checkup

Un skill para [Claude Code](https://claude.com/claude-code) que revisa por qué tu Mac está lenta o
sin espacio y la deja mejor **contigo, paso por paso**.

Hecho para quien programa (o *vibecodea*) todo el día y nunca le da mantenimiento a su Mac: servidores
de desarrollo que llevan días prendidos, Docker con proyectos de hace semanas, quince sesiones de
agentes abiertas, un script trabado al 100% de CPU, 20 GB de caché de npm. Nada de eso se apaga solo,
y un día adjuntar un archivo tarda diez segundos.

## Qué hace

1. **Revisa sin tocar nada.** Un script de solo lectura mide memoria, swap, procesos trabados,
   servidores olvidados, Docker, sesiones de IA, Spotlight, cachés y archivos gigantes.
2. **Te explica lo que encontró** en palabras simples, con lo que libera cada cosa.
3. **Te pregunta uno por uno.** Por cada hallazgo te dice qué es, cuánto libera, por qué conviene y
   si se puede deshacer. Tú dices sí o no; lo hace, lo verifica y pasa al siguiente.
4. **Te deja la lista de lo que te toca a ti** (ajustes de macOS, decidir qué archivos borrar) con
   los pasos exactos.

Nunca borra tus archivos, nunca usa `sudo` y nunca cierra tus sesiones de trabajo por su cuenta.

## Instalar

```bash
git clone https://github.com/jlarriaga/mac-checkup ~/.claude/skills/mac-checkup
```

## Usar

Abre Claude Code y escribe:

```
/mac-checkup
```

o simplemente *"mi Mac está lenta, ¿me ayudas?"*.

¿Solo quieres ver el diagnóstico, sin Claude?

```bash
bash ~/.claude/skills/mac-checkup/scripts/diagnostico.sh
```

## Qué revisa

| Lentitud | Espacio |
|---|---|
| Swap y presión de memoria | Cachés de npm, bun, pnpm, pip, Homebrew |
| Procesos trabados (mucha CPU, sin actividad) | Docker: caché de builds, imágenes y volúmenes |
| Servidores de desarrollo olvidados | Xcode: DerivedData, simuladores, runtimes de iOS viejos |
| Docker: contenedores de proyectos inactivos | `node_modules` de proyectos sin tocar en 30+ días |
| Sesiones de agentes de IA abiertas hace días | Archivos de más de 1 GB e instaladores olvidados |
| Spotlight indexando tu código | Papelera, WhatsApp, Chrome, respaldos de iPhone |
| Descargas e iCloud frenando el selector de archivos | Apps que no abres hace meses |

Requiere macOS. Probado en macOS 26 con Apple Silicon.

---

**English:** a Claude Code skill that diagnoses a slow or full Mac (read-only), explains each finding
in plain words with how much it frees, and asks for approval one item at a time before changing
anything. The skill answers in your language.

MIT License.

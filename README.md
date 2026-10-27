# Empire Plasma — Mist Edition

Dotfiles minimalistas para **CachyOS + KDE Plasma 6**, pensados para un PC de juego (Age of Empires II: DE, Steam, OBS).
Una sola barra superior fina y opaca, colores sacados del wallpaper del bosque con niebla, y nada que consuma CPU en segundo plano.

![Vista previa: barra superior sobre el wallpaper](docs/preview.jpg)

![Vista previa con el calendario y el menú de apagado abiertos](docs/preview-popups.jpg)

> **Sobre las imágenes:** son una **maqueta renderizada** (HTML + tu wallpaper) con las medidas y colores reales del tema.
> No son una captura de Plasma: este repositorio se escribió y probó en un contenedor sin escritorio KDE.
> Mira [Estado de verificación](#estado-de-verificación) para saber qué está probado y qué tienes que comprobar tú.

---

## Qué hace

| Zona | Contenido | Componente |
|---|---|---|
| Izquierda | Logo de Arch (azul niebla) → lanzador de apps | Kickoff nativo con icono propio |
| | `I II III` (Dark / Feudal / Castle Age) | **Empire Ages** (QML propio) |
| | Apps ancladas, monocromas, con punto si están abiertas | **Empire Launchers** (QML propio) |
| | Música: título + ⏮ ⏯ ⏭, se oculta si no suena nada | **Empire Media** (QML propio) |
| Centro | `Oct 26 · 4:27 P`, centrado en la pantalla, clic → calendario | **Empire Clock** (QML propio) |
| Derecha | Bandeja: Steam, Discord, Dropbox, Nextcloud… | Bandeja del sistema nativa |
| | `US`/`ES` · Bluetooth · Wi-Fi/red · Volumen · Notificaciones | Applets nativos de Plasma |
| | ⏻ → Bloquear, Suspender, Cerrar sesión, Reiniciar, Apagar | **Empire Power** (QML propio) |

Además:

- **Esquema de color `Empire Mist`** para Plasma y todas las apps (Dolphin, Preferencias del sistema, menús, notificaciones, calendario).
- **KWin:** decoración Breeze discreta, bordes mínimos, botones `minimizar · maximizar · cerrar`, sin blur, sin transparencias y sin efectos de ventanas gelatinosas.
- **Konsole:** perfil `Empire Mist`, fondo opaco `#101820`, cursor fino, sin barra de desplazamiento.
- **Prompt** para bash, zsh y fish: `Λ ~/proyectos ›`. Si un comando falla, muestra el código: `Λ ~/proyectos ×127 ›`.
- **Escritorios virtuales:** exactamente tres, llamados *Dark Age*, *Feudal Age* y *Castle Age*. Los nombres solo aparecen en tooltips, en Vista general y en el OSD. La barra solo muestra los números romanos.

No se tocan: wallpaper, kernel, drivers, Steam, Proton, Gamescope, OBS, energía, arranque, servicios, tema de iconos ni fuentes del sistema.

### Paleta

| Token | Color | Uso |
|---|---|---|
| base | `#101820` | Fondo dominante: barra, ventanas, cabeceras, terminal |
| view | `#141F29` | Fondo de listas y vistas (Dolphin) |
| slate | `#253846` | Selección, escritorio activo, elemento pulsado |
| mist | `#B8D5E0` | Texto e iconos (contraste 11,6:1 sobre la base) |
| mist-dim | `#86A0AC` | Texto inactivo (6,5:1, cumple WCAG AA) |
| mist-bright | `#DCEBF1` | Texto seleccionado |

Los colores *semánticos* (error, aviso, OK) y los 16 colores ANSI de Konsole se mantienen, aunque desaturados hacia la niebla. Sin ellos no se distinguirían un `git diff` ni un error. Ningún elemento decorativo usa dorado, borgoña, morado ni neón.

---

## Requisitos y dependencias

Todo viene con una instalación normal de CachyOS KDE. **No se instala ningún paquete.**

| Necesario | Paquete Arch | Para qué |
|---|---|---|
| Plasma ≥ 6.2 (recomendado ≥ 6.4) | `plasma-workspace`, `plasma-desktop`, `libplasma` | Barra, applets, API de scripting |
| KWin | `kwin` | Escritorios, decoración |
| Breeze | `breeze` | Estilo de apps y decoración |
| Konsole | `konsole` | Perfil de terminal |
| `kwriteconfig6`, `kreadconfig6` | `kconfig` | Escribir/leer configuración |
| `kquitapp6` | `kde-cli-tools` | Reiniciar plasmashell limpiamente |
| `busctl` | `systemd` | D-Bus (sin depender de `qdbus6`) |
| `fc-list` | `fontconfig` | Elegir fuente monoespaciada |
| Opcional: `kscreen-doctor` | `kscreen` | Mostrar monitores en el informe |

Para el terminal se usa la primera fuente instalada de esta lista: JetBrains Mono, Hack, Fira Code, Noto Sans Mono o DejaVu Sans Mono.

---

## Instalación

```bash
git clone https://github.com/dani3lsamir/aoe-plasma.git empire-plasma
cd empire-plasma
./install.sh --dry-run     # solo detecta y enseña qué cambiaría
./install.sh               # pregunta antes de cada cambio importante
```

El instalador sigue estos pasos:

1. **Detecta** la versión de CachyOS y de Plasma, si la sesión es Wayland o X11, los monitores, los paneles y escritorios actuales, el esquema de color, si Brave Origin y un adaptador Bluetooth están presentes, tu shell y tus distribuciones de teclado.
2. **Muestra** la lista completa de cambios.
3. **Pregunta** antes de aplicar nada. Además pregunta aparte antes de *borrar tus paneles actuales*, de quitar escritorios sobrantes y de configurar el teclado.
4. **Hace una copia de seguridad** en `~/.local/share/empire-plasma/backups/<fecha>/`. La primera copia queda marcada como *original*: aunque reinstales, `restore.sh` vuelve siempre a tu escritorio de antes de Empire.
5. **Aplica** los cambios y reinicia `plasmashell` una vez (la pantalla parpadea un segundo).
6. **Verifica** lo que se puede comprobar con un script (ver abajo) e informa de cualquier fallo.

Opciones:

```
--dry-run        detectar y previsualizar, sin cambios
-y, --yes        responder "sí" a todo (igualmente hace la copia)
--keep-panels    añadir la barra sin quitar los paneles actuales
--no-panel       solo tema, KWin, Konsole y prompt
--no-shell       no tocar bash/zsh/fish
--no-keyboard    no tocar distribuciones de teclado
--no-desktops    no cambiar número/nombres de escritorios
--layouts us,es  distribuciones si no tienes ninguna configurada (p. ej. us,latam)
--thickness 30   grosor de la barra en px (26–36)
```

### Restaurar

```bash
./restore.sh            # vuelve al estado anterior a la primera instalación
./restore.sh --list     # lista las copias
./restore.sh --from ~/.local/share/empire-plasma/backups/20261026-231520
```

Qué recupera:

- Los paneles (y con ellos el wallpaper de ese momento) y `plasmashellrc`.
- Cada ajuste que el instalador cambió, **clave por clave**, así que se conservan los cambios que hayas hecho después en otras opciones.
- El esquema de color y el estilo de Plasma.
- El número y los nombres de los escritorios virtuales.
- Tu `.bashrc`, `.zshrc` o `config.fish` sin el bloque del prompt.

También borra los widgets, el esquema y el perfil instalados. Las copias de seguridad se conservan hasta que las borres tú.

---

## Por qué hay QML propio

La prioridad es usar componentes nativos. Solo hay QML propio donde Plasma no ofrece lo que pide el diseño:

| Widget | Por qué no basta el nativo | Coste en ejecución |
|---|---|---|
| **Empire Ages** | El *Paginador* dibuja escritorios en miniatura con contornos de ventanas. No tiene un modo "solo números romanos con cápsula y subrayado". | Señales de KWin vía `libtaskmanager`. Al hacer clic, una llamada D-Bus asíncrona. Sin temporizadores. |
| **Empire Launchers** | El *Gestor de tareas de solo iconos* siempre pinta los iconos originales a color. Cambiar el tema de iconos alteraría todo el sistema. | El mismo `TasksModel` del gestor de tareas. El tinte monocromo es un `MultiEffect` estático: se renderiza una vez por icono. |
| **Empire Media** | El *Reproductor multimedia* en un panel es solo un icono; título y controles van en un popup. | El mismo modelo MPRIS que el widget nativo (`libkmpris`): señales D-Bus, sin sondeo y sin procesos extra. Se oculta sin reproductor. |
| **Empire Clock** | Un reloj entre dos espaciadores queda centrado *entre los grupos*, no en la pantalla, y se mueve cuando la música aparece o desaparece. El *Reloj digital* tampoco sabe escribir `A`/`P` con una sola letra. | Un tic por minuto, del mismo origen que el reloj nativo (`org.kde.plasma.clock` en Plasma ≥ 6.6; motor `time` en versiones anteriores). El recentrado solo se ejecuta cuando cambia el ancho de algo. El calendario es el `MonthView` de KDE y se crea al abrirlo por primera vez. |
| **Empire Power** | *Bloquear/Cerrar sesión* pone un icono por acción. | `SessionManagement` de Plasma. Reiniciar y apagar muestran la confirmación nativa. |
| **Empire Separator** | El *Espaciador* solo añade hueco, no dibuja línea. | Un rectángulo de 1 px. |

Todos leen sus colores del esquema de color: si lo cambias, la barra cambia con él. No hay colores fijos en el QML.

---

## Uso diario

### Aplicaciones ancladas

- **Anclar:** arrastra una app desde el menú Arch hasta los iconos de la barra. También funciona *clic derecho → Pin* sobre una app abierta (si activas "mostrar apps no ancladas").
- **Desanclar:** *clic derecho → Unpin*.
- **Lista manual:** *clic derecho → Configure Launchers…*. Escribe un ID por línea; basta `org.kde.dolphin`.

IDs habituales:

```
org.kde.dolphin
org.kde.konsole
steam
discord                     # Flatpak: com.discordapp.Discord
spotify-launcher            # o spotify / com.spotify.Client
com.obsproject.Studio
```

Para saber el ID exacto: `ls /usr/share/applications ~/.local/share/applications /var/lib/flatpak/exports/share/applications`.
Al inicio solo se ancla Brave Origin, y solo si el instalador lo encuentra.

Controles: clic izquierdo abre o enfoca la app, y vuelve a minimizarla si ya está enfocada. Clic central abre una ventana nueva. Si hay varias ventanas, cada clic pasa a la siguiente.

### Escritorios

Clic en `I`, `II` o `III`. La rueda del ratón sobre los números también cambia de escritorio. Para renombrar las "edades": *Preferencias del sistema → Escritorios virtuales*.

### Teclado

Clic en `US`/`ES` para alternar. Por defecto se configura *us,es* (España). Para Latinoamérica: `./install.sh --layouts us,latam`. Si ya tenías distribuciones configuradas, se conservan y solo cambian las etiquetas a mayúsculas.

---

## Personalizar colores y tamaños

**Colores:** edita `config/color-schemes/EmpireMist.colors` (formato `R,G,B`) y vuelve a ejecutar `./install.sh`, o aplica a mano:

```bash
cp config/color-schemes/EmpireMist.colors ~/.local/share/color-schemes/
plasma-apply-colorscheme BreezeDark && plasma-apply-colorscheme EmpireMist
```

Qué controla cada grupo del esquema:

| Grupo | Afecta a |
|---|---|
| `[Colors:Window]` / `[Colors:Header]` `BackgroundNormal` | La barra y el fondo de las ventanas |
| `[Colors:Selection]` `BackgroundNormal` | La cápsula del escritorio activo y las selecciones de Dolphin |
| `ForegroundNormal` | Texto e iconos (el azul niebla) |
| `ForegroundInactive` | Números de escritorios inactivos y texto apagado |

Los colores de Konsole están en `config/konsole/EmpireMist.colorscheme`. Los del prompt, al principio de `config/shell/prompt.*`.

**Tamaños:**

- **Grosor de la barra:** `./install.sh --thickness 28`, o *clic derecho en la barra → Mostrar configuración del panel → Altura*.
- **Iconos de las apps ancladas:** *Configure Launchers… → Icon size*. Es un porcentaje del grosor de la barra; por defecto 72 %, unos 22 px en una barra de 30 px.
- **Ajustes guardados por widget** en `~/.config/plasma-org.kde.plasma.desktop-appletsrc` (se aplican al reiniciar Plasma: `systemctl --user restart plasma-plasmashell`):

| Widget | Clave | Por defecto | Qué hace |
|---|---|---|---|
| Empire Clock | `fontScale` | `0.42` | Tamaño del texto respecto al grosor de la barra |
| Empire Clock | `letterSpacing` | `0.6` | Espaciado entre letras |
| Empire Clock | `localeName` | `en_US` | Idioma de los meses: `es_ES` da `oct` |
| Empire Clock | `twentyFourHour` | `false` | Formato de 24 horas |
| Empire Ages | `fontFamily` | `serif` | Fuente de los números romanos (vacío = fuente de Plasma) |
| Empire Media | `maxTitleWidth` | `220` | Ancho máximo del título antes de recortarlo, en px |

---

## Rendimiento

- No se instala nada que se quede ejecutándose: ni barra externa, ni Conky, ni monitores, ni scripts en bucle.
- Ningún widget sondea. Todos reaccionan a señales: KWin, MPRIS, el `TasksModel` y un tic de reloj por minuto.
- El compositor queda como estaba. Solo se desactivan blur, background contrast, translucency, wobbly windows y magic lamp. Los juegos a pantalla completa siguen pasando por KWin igual que antes. En Wayland, KWin ya usa scan-out directo para pantalla completa.
- **No prometo más FPS.** Quitar blur y transparencias reduce trabajo del compositor en el escritorio, pero no he medido diferencias en juegos. Si quieres datos, compara con MangoHud antes y después.

---

## Estado de verificación

**Comprobado aquí** (contenedor Linux sin escritorio, con las herramientas KDE simuladas):

- `shellcheck` sin avisos en `install.sh`, `restore.sh`, `lib/common.sh` y el prompt de bash.
- Todos los `.qml` pasan el analizador de Qt 6.9 (`qmllint`) sin errores de sintaxis.
- El script de la barra crea el orden de widgets correcto y configura el panel arriba, a 30 px, opaco, sin flotar, y la bandeja (probado contra una simulación de la API de scripting de Plasma).
- El formato del reloj: `Oct 26 · 4:27 P`, `12:05 A`, `12:00 P`; y los números romanos `I II III IV V IX XII`.
- Ciclo completo *instalar → reinstalar → restaurar* en un HOME temporal con herramientas KDE simuladas:
  - el wallpaper no se toca;
  - los escritorios pasan de 4 a 3 y vuelven a 4 con sus nombres;
  - la reinstalación conserva la copia original;
  - tras restaurar, el HOME queda **idéntico byte a byte**.
- Los prompts de bash, zsh 5.9 y fish 3.7 se renderizan bien, también con código de error.
- Las APIs usadas se revisaron contra el código fuente de Plasma 6.2, 6.4, 6.5, 6.6 y master: scripting de paneles, `VirtualDesktopInfo`, `Mpris2Model`, `SessionManagement`, `MonthView`, `Dialog` y el módulo D-Bus de QML.

**Por comprobar en tu PC.** Ningún script puede verlo; el instalador te lo recuerda. Marca cada punto:

- [ ] La barra es fina, completamente opaca y sin bordes llamativos.
- [ ] El reloj sigue centrado en la pantalla al empezar y al parar la música.
- [ ] `I`, `II` y `III` cambian de escritorio; la cápsula sigue al escritorio activo.
- [ ] El logo de Arch abre el lanzador.
- [ ] Brave Origin abre desde su icono (si está instalado).
- [ ] La música se pausa y se reanuda desde el módulo; el módulo desaparece al cerrar el reproductor.
- [ ] La bandeja muestra Steam, Discord y similares cuando están abiertos.
- [ ] Bluetooth, Wi-Fi, volumen y el cambio `US`/`ES` funcionan.
- [ ] El clic en el reloj abre el calendario, y `Esc` lo cierra.
- [ ] ⏻ bloquea, cierra sesión, reinicia y apaga (con confirmación).
- [ ] No hay iconos cortados ni desalineados.
- [ ] Steam, AoE II: DE y OBS (captura de pantalla y de juego) funcionan igual que antes.
- [ ] `./restore.sh` devuelve tu escritorio anterior.

Si algo falla, abre un issue con la salida de `./install.sh` y de `journalctl --user -b -u plasma-plasmashell | grep -i empire`.

---

## Estructura

```
empire-plasma/
├── install.sh                  detección → vista previa → copia → aplicar → verificar
├── restore.sh                  deshace todo desde la copia original
├── lib/common.sh               utilidades compartidas (KConfig, D-Bus, copias)
├── assets/empire-arch.svg      logo de Arch en azul niebla
├── config/
│   ├── color-schemes/EmpireMist.colors
│   ├── konsole/                EmpireMist.profile + EmpireMist.colorscheme
│   └── shell/                  prompt.bash · prompt.zsh · prompt.fish
├── plasma/
│   ├── layout/empire-panel.js  la barra, con la API de scripting de Plasma 6
│   └── plasmoids/              los 6 widgets Empire (QML)
└── docs/                       imágenes de vista previa
```

## Solución de problemas

- **Aparece un widget como "no disponible":** tu Plasma no incluye ese applet. Por ejemplo, sin `bluez` no hay applet de Bluetooth. La barra se crea igualmente sin él.
- **La barra vieja sigue ahí:** respondiste "no" a reemplazar paneles. Bórrala con *clic derecho → Mostrar configuración del panel → Más opciones → Eliminar panel*.
- **El indicador I II III no cambia de escritorio:** necesita Plasma ≥ 6.2, que trae el módulo QML `org.kde.plasma.workspace.dbus`.
- **CachyOS muestra fastfetch al abrir fish:** es el saludo de CachyOS, no de este tema. Para quitarlo, añade `function fish_greeting; end` a `~/.config/fish/config.fish`.

## Licencia

MIT. Consulta [LICENSE](LICENSE).

El logo de Arch Linux procede de [Simple Icons](https://simpleicons.org) (CC0). El nombre y el logo de Arch Linux son marcas del proyecto Arch Linux y se usan según su política de marcas para uso comunitario.

@echo off
setlocal
REM MEGA65 build: (optional) build assets, assemble with 64tass, write the D81 with c1541.
REM Rename PROJECT for a new project. The disk's first file is AUTOBOOT.C65, a one-line
REM BASIC program (10 RUN "PROJECT", from tools\autoboot.py): Xemu -autoload runs the first
REM file and a real MEGA65 runs AUTOBOOT.C65 at power-on, so both start the game, which is
REM on the disk only once.
set PROJECT=renderer65
if not exist target mkdir target
REM c1541 writes its settings under the user profile: keep them inside target\
if not exist target\userprofile\AppData\Roaming mkdir target\userprofile\AppData\Roaming
set "USERPROFILE=%CD%\target\userprofile"
set "APPDATA=%USERPROFILE%\AppData\Roaming"

del target\*.d81 2>nul
del target\*.lst 2>nul
del target\*.lbl 2>nul
del target\%PROJECT% 2>nul

REM Assets: src\assets (PNG sheets, asm tables) -> src\gen\*, target\assets\*. Uncomment when
REM the project has src\assets (tools\build_assets.py is a starting point):
REM python tools\build_assets.py
REM if errorlevel 1 exit /b 1

REM M65DEFS: extra 64tass defines for test builds, e.g. set M65DEFS=-D DBG_ROWS=8 -D DBG_PASS2=0
REM One assembly, one file per section: the resident program and the overlays (main.asm).
set TASS=.\64tass.exe -C -I src %M65DEFS% src\main.asm
%TASS% --flat --output-section=res -l target\%PROJECT%.lbl -L target\%PROJECT%.lst -o target\%PROJECT%
if errorlevel 1 exit /b 1
python tools\cut.py target\%PROJECT% 0x1fff
if errorlevel 1 exit /b 1
for %%n in (0 1 2 3 4 5 6 7) do (
    %TASS% --flat --output-section=ovl%%n -o target\ovl%%n >nul
    if errorlevel 1 (echo overlay %%n failed & exit /b 1)
    python tools\cut.py target\ovl%%n 0x1%%n0000
    if errorlevel 1 exit /b 1
)

python tools\autoboot.py %PROJECT% target\autoboot
if errorlevel 1 exit /b 1
REM BASIC 65 programs (src\basic\NAME.bas, lower case) -> target\NAME, tokenised by petcat
for %%f in (src\basic\*.bas) do (
    .\petcat.exe -w65 -l 2001 -o target\%%~nf -- %%f >nul
    if errorlevel 1 (echo petcat failed on %%f & exit /b 1)
)
cd target
..\c1541.exe -format "%PROJECT%,01" d81 %PROJECT%.d81 >nul
if errorlevel 1 (cd .. & exit /b 1)
..\c1541.exe -attach %PROJECT%.d81 -write autoboot autoboot.c65 >nul
if errorlevel 1 (cd .. & exit /b 1)
..\c1541.exe -attach %PROJECT%.d81 -write %PROJECT% %PROJECT% >nul
if errorlevel 1 (cd .. & exit /b 1)
for %%f in (..\src\basic\*.bas) do (
    ..\c1541.exe -attach %PROJECT%.d81 -write %%~nf %%~nf >nul
    if errorlevel 1 (echo failed writing %%~nf & cd .. & exit /b 1)
)
for %%n in (0 1 2 3 4 5 6 7) do (
    ..\c1541.exe -attach %PROJECT%.d81 -write ovl%%n ovl%%n >nul
    if errorlevel 1 (echo failed writing ovl%%n & cd .. & exit /b 1)
)
REM the scenes, as SEQ text files. SCENE.POV is the one rendered: scenes\default.pov, or
REM the file in M65SCENE (a test build: set M65SCENE=scenes\shapes.pov)
set SCENEPOV=%M65SCENE%
if "%SCENEPOV%"=="" set SCENEPOV=scenes\default.pov
..\c1541.exe -attach %PROJECT%.d81 -write ..\%SCENEPOV% "scene.pov,s" >nul
if errorlevel 1 (cd .. & exit /b 1)
for %%f in (..\scenes\*.pov ..\scenes\*.mdl ..\scenes\*.mat) do (
    ..\c1541.exe -attach %PROJECT%.d81 -write %%f "%%~nxf,s" >nul
    if errorlevel 1 (echo failed writing %%f & cd .. & exit /b 1)
)
REM asset files listed by tools\build_assets.py (written lower case = PETSCII upper case)
if exist assets\files.txt for /f %%f in (assets\files.txt) do (
    ..\c1541.exe -attach %PROJECT%.d81 -write assets\%%f %%f >nul
    if errorlevel 1 (echo failed writing %%f & cd .. & exit /b 1)
)
cd ..

REM keep only the D81, the listing and the labels (the Xemu test harness reads them)
for %%f in (target\*) do (
    if /i not "%%~xf"==".d81" if /i not "%%~xf"==".lst" if /i not "%%~xf"==".lbl" del "%%f"
)
for /d %%d in (target\*) do rmdir /s /q "%%d"

echo Built target\%PROJECT%.d81

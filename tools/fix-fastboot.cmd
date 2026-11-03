@echo off
setlocal
rem Reset the A/B slot after the 7-boot retry budget is exhausted.
rem Put platform-tools on PATH, or set PLATFORM_TOOLS_DIR first.
if defined PLATFORM_TOOLS_DIR cd /d "%PLATFORM_TOOLS_DIR%"

echo === fastboot devices ===
fastboot devices
if errorlevel 1 goto fail
echo.
echo === reset slot a ===
fastboot --set-active=a
if errorlevel 1 goto fail
echo.
echo === verify ===
fastboot getvar current-slot
fastboot getvar slot-unbootable:a
fastboot getvar slot-retry-count:a
echo.
echo === reboot ===
fastboot reboot
goto end

:fail
echo.
echo FAILED - is the device in fastboot mode? (volume-down + power)
:end
echo.
endlocal

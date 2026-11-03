@echo off
setlocal
cd /d "%~dp0"

echo ================================================
echo  TB371FC  Arch Linux ARM + Plasma 6  flash tool
echo ================================================
echo.
echo WARNING: this erases the userdata partition.
choice /C YN /M "Continue"
if errorlevel 2 goto end

fastboot devices
echo.

echo [1/4] boot_a
fastboot flash boot_a "boot\boot_a.img"
if errorlevel 1 goto fail

echo [2/4] dtbo_a
fastboot flash dtbo_a "boot\dtbo_a.img"
if errorlevel 1 goto fail

echo [3/4] userdata (sparse, chunked 16M)
if not exist "rootfs\userdata.img" (
  echo.
  echo rootfs\userdata.img not found.
  echo Extract rootfs\userdata.img.zst first (7-Zip 24+ or zstd.exe^).
  goto end
)
fastboot flash -S 16M userdata "rootfs\userdata.img"
if errorlevel 1 goto fail

echo [4/4] set active slot + reboot
fastboot --set-active=a
fastboot reboot
echo.
echo Done. First boot takes a while.
goto end

:fail
echo.
echo FAILED. Do not reboot blindly - check the message above.
:end
pause

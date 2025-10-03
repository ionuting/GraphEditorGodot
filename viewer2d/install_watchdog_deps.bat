@echo off
echo Installing Python dependencies for DXF Watchdog...
echo.

pip install watchdog
if %errorlevel% neq 0 (
    echo Failed to install watchdog
    pause
    exit /b 1
)

echo.
echo Dependencies installed successfully!
echo You can now run the DXF watchdog with:
echo python python/dxf_watchdog.py
echo.
pause
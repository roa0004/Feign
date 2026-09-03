@echo off
REM start.bat - Rei-chan project bootstrap for Windows
REM Safe, idempotent, does not overwrite existing .env or reinstall Ollama

SETLOCAL ENABLEDELAYEDEXPANSION

echo =============================
echo Rei-chan - Windows bootstrap
echo =============================
:: Change working directory to the script location to make paths safe when there are spaces
cd /d "%~dp0"
:: Check Node.js availability
where node >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Node.js is not found in PATH.
  echo Please install Node.js (>=18) from https://nodejs.org/ and re-run this script.
  pause
  exit /b 1
) else (
  node -v
  npm -v
)
:: Check Python availability (py -3 preferred)
set "PY_CMD="
py -3 --version >nul 2>&1
if errorlevel 1 (
  python --version >nul 2>&1
  if errorlevel 1 (
    set "PY_CMD="
  ) else (
    set "PY_CMD=python"
  )
) else (
  set "PY_CMD=py -3"
)
if "%PY_CMD%"=="" (
  echo [WARN] Python not found. Skipping virtualenv and Python dependency setup.
) else (
  echo Python runtime: %PY_CMD%
)
:: Ensure .env exists (do not overwrite if present)
if not exist ".env" (
  if exist ".env.example" (
    copy ".env.example" ".env" >nul
    echo Created .env from .env.example (please edit sensitive values in .env before first run).
  ) else (
    echo [WARN] .env.example not found; please create .env manually.
  )
) else (
  echo .env already exists; will not overwrite.
)
:: NPM install if node_modules missing
if not exist "node_modules" (
  echo node_modules not found. Installing npm dependencies...
  npm ci || npm install
) else (
  echo node_modules exists. Skipping npm install. If you need to reinstall, run: npm ci
)
:: Python venv & requirements (if Python present)
if not "%PY_CMD%"=="" (
  if exist "requirements.txt" (
    if not exist ".venv\Scripts\python.exe" (
      echo Creating Python virtual environment in .venv ...
      %PY_CMD% -m venv .venv
      if errorlevel 1 (
        echo [ERROR] Failed to create Python virtual environment. Please create one manually.
      ) else (
        echo Installing Python requirements into .venv ...
        call ".venv\Scripts\pip.exe" install --upgrade pip setuptools wheel
        call ".venv\Scripts\pip.exe" install -r requirements.txt
      )
    ) else (
      echo Python virtual environment (.venv) already exists. Skipping venv creation.
    )
  ) else (
    echo requirements.txt not found. Skipping Python dependency installation.
  )
)
:: Ollama: check presence but DO NOT auto-install Ollama.
where ollama >nul 2>&1
if errorlevel 1 (
  echo [WARN] Ollama CLI not found in PATH.
  echo If you plan to use local Ollama, please install it following OLLAMA_SETUP.md.
) else (
  echo Ollama CLI detected.
  rem Get model name from environment or .env (do not change any values)  
  set "MODEL=%OLLAMA_MODEL%"
  if "!MODEL!"=="" (
    if exist ".env" (
      for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
        if /i "%%~A"=="OLLAMA_MODEL" set "MODEL=%%~B"
      )
    )
  )
  if "!MODEL!"=="" (
    echo OLLAMA_MODEL not set. The script will not assume a default model.
  ) else (
    echo Checking Ollama for model "!MODEL!" ...
    ollama list 2>nul | findstr /I "!MODEL!" >nul
    if errorlevel 1 (
      echo Model "!MODEL!" not found locally.
      set /p DO_PULL="Would you like to attempt 'ollama pull !MODEL!' now? (y/N) > "
      if /I "!DO_PULL!"=="y" (
        echo Pulling model !MODEL! ...
        ollama pull "!MODEL!"
        if errorlevel 1 (
          echo [ERROR] Failed to pull model !MODEL!. Please run 'ollama pull !MODEL!' manually.
        ) else (
          echo Model !MODEL! pulled successfully.
        )
      ) else (
        echo Skipping model pull. You can run: ollama pull !MODEL!
      )
    ) else (
      echo Model "!MODEL!" is present locally.
    )
  )
)
:: External components note (do not mislead)
echo NOTE: This script does not automatically install/configure SearXNG, Piper TTS, Live2D, or other external services.
echo Please refer to SEARXNG_SETUP.md, PIPER_SETUP.md, and OLLAMA_SETUP.md for manual installation steps when needed.
:: Final: start the Node server
echo Starting Rei-chan server (node src/server.js)...
node "src/server.js" %*
if errorlevel 1 (
  echo [ERROR] Node application exited with code %ERRORLEVEL%.
  echo Check server logs and ensure environment variables in .env are correctly set.
  pause
  endlocal & exit /b %ERRORLEVEL%
)

echo Server stopped. Exiting.
ENDLOCAL

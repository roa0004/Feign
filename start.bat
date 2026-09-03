@echo off
REM start.bat - Rei-chan bootstrap for Windows (clean, minimal, robust)
REM - Does NOT overwrite existing .env
REM - Does NOT auto-install Ollama/SearXNG/Piper/Live2D

SETLOCAL ENABLEDELAYEDEXPANSION

echo =============================
echo Rei-chan - Windows bootstrap
echo =============================
:: Ensure script runs from its own directory (handles spaces)
cd /d "%~dp0"
:: --- Node.js check ---
where node >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Node.js not found in PATH.
  echo Please install Node.js (>=18) from https://nodejs.org/ and re-run this script.
  pause
  exit /b 1
) else (
  echo Node:
  node -v
  echo npm:
  npm -v
)
:: --- .env handling (do not overwrite existing .env) ---
if exist ".env" (
  echo .env already exists; will not overwrite.
) else (
  if exist ".env.example" (
    copy ".env.example" ".env" >nul
    echo Created .env from .env.example (please edit sensitive values in .env before first run).
  ) else (
    echo [WARN] .env not found and .env.example missing; please create .env manually.
  )
)
:: --- NPM dependencies ---
if not exist "node_modules" (
  echo node_modules not found. Installing npm dependencies...
  if exist "package-lock.json" (
    echo Running: npm ci
    npm ci || (
      echo npm ci failed, falling back to npm install
      npm install
    )
  ) else (
    echo Running: npm install
    npm install
  )
) else (
  echo node_modules exists. Skipping npm install. If you need to reinstall, run: npm ci
)
:: --- Python optional setup ---
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
  echo [INFO] Python not detected. Skipping Python virtualenv and requirements.
) else (
  echo [INFO] Python detected: %PY_CMD%
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
:: --- Ollama model check (do NOT auto-install Ollama) ---
where ollama >nul 2>&1
if errorlevel 1 (
  echo [INFO] Ollama CLI not found in PATH. Skipping Ollama checks. See OLLAMA_SETUP.md to install.
) else (
  echo [INFO] Ollama CLI detected.
  rem Use environment OLLAMA_MODEL first, then .env if present; do not set default model  
  set "MODEL=%OLLAMA_MODEL%"
  if "!MODEL!"=="" (
    if exist ".env" (
      for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
        if /i "%%~A"=="OLLAMA_MODEL" set "MODEL=%%~B"
      )
    )
  )
  if "!MODEL!"=="" (
    echo [INFO] OLLAMA_MODEL not set; skipping model presence check.
  ) else (
    echo [INFO] Checking Ollama for model "!MODEL!" ...
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
:: Note: external services like SearXNG/Piper/Live2D are not auto-installed by this script.
echo NOTE: This script does not automatically install/configure SearXNG, Piper TTS, Live2D, or other external services.
echo Please refer to SEARXNG_SETUP.md, PIPER_SETUP.md, and OLLAMA_SETUP.md for manual installation steps when needed.
:: --- Start Node server ---
echo Starting Rei-chan server (node "src/server.js")...
node "src/server.js" %*
set "RC=%ERRORLEVEL%"
if %RC% NEQ 0 (
  echo [ERROR] Node application exited with code %RC%.
  echo Check server logs and ensure environment variables in .env are correctly set.
  pause
  exit /b %RC%
)
necho Server stopped. Exiting.
ENDLOCAL

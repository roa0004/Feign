@echo off
REM start.bat - Rei-chan project bootstrap for Windows
REM Safe, idempotent, does not overwrite existing .env or reinstall Ollama

SETLOCAL ENABLEDELAYEDEXPANSION

echo =============================
echo Rei-chan - Windows bootstrap
echo =============================
:: Change working directory to the script location to make paths safe when there are spacesncd /d "%~dp0"
:: Helper: check if a command exists
where node >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
  echo [ERROR] Node.js is not found in PATH.
  echo Please install Node.js (>=18) from https://nodejs.org/ and re-run this script.
  pause
  exit /b 1
) else (
  node -v
  npm -v
)
:: Python check (try py -3 then python)
set "PY_CMD="
py -3 --version >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
  set "PY_CMD=py -3"
) ELSE (
  python --version >nul 2>&1
  IF %ERRORLEVEL% EQU 0 (
    set "PY_CMD=python"
  )
)
nIF "%PY_CMD%"=="" (
  echo [WARN] Python not found. Skipping virtualenv and Python dependency setup.
) ELSE (
  echo Python runtime: %PY_CMD%
)
:: Ensure .env exists (do not overwrite if present)IF NOT EXIST ".env" (
  IF EXIST ".env.example" (
    copy ".env.example" ".env" >nul
    echo Created .env from .env.example (you should edit it as needed).
  ) ELSE (
    echo [WARN] .env.example not found; create .env manually.
  )
) ELSE (
  echo .env already exists; will not overwrite.
)
:: NPM install if node_modules missing or package-lock changednIF NOT EXIST "node_modules" (
  echo node_modules not found. Installing npm dependencies...
  npm ci || npm install
) ELSE (
  echo node_modules exists. Skipping npm install. If you need to reinstall, run: npm ci
)
:: Python venv & requirementsIF NOT "%PY_CMD%"=="" (
  IF EXIST "requirements.txt" (
    IF NOT EXIST ".venv\Scripts\python.exe" (
      echo Creating Python virtual environment in .venv ...
      %PY_CMD% -m venv .venv
      IF %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Failed to create Python virtual environment. Please create one manually.
      ) ELSE (
        echo Installing Python requirements into .venv ...
        .venv\Scripts\pip.exe install --upgrade pip setuptools wheel >nul 2>&1
        .venv\Scripts\pip.exe install -r requirements.txt
      )
    ) ELSE (
      echo Python virtual environment (.venv) already exists. Skipping venv creation.
    )
  ) ELSE (
    echo requirements.txt not found. Skipping Python dependency installation.
  )
)
:: Ollama: check presence but do NOT auto-install Ollama.where ollama >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
  echo [WARN] Ollama CLI not found in PATH.
  echo If you plan to use local Ollama, please install it following OLLAMA_SETUP.md.
) ELSE (
  echo Ollama CLI detected.
  REM Check model presence only if OLLAMA_MODEL is set in .env or environment, but do not change it  
  set "MODEL=%OLLAMA_MODEL%"
  if "%MODEL%"=="" (
    REM Try to read from .env if present
    for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
      if /i "%%~A"=="OLLAMA_MODEL" set "MODEL=%%~B"
    )
  )
  if "%MODEL%"=="" (
    echo OLLAMA_MODEL not set. The script will not assume a default model.
  ) else (
    echo Checking Ollama for model "%MODEL%" ...
    ollama list 2>nul | findstr /I "%MODEL%" >nul
    IF %ERRORLEVEL% NEQ 0 (
      echo Model "%MODEL%" not found locally.
      set /p DO_PULL="Would you like to attempt 'ollama pull %MODEL%' now? (y/N) > "
      if /I "%DO_PULL%"=="y" (
        echo Pulling model %MODEL% ...
        ollama pull %MODEL%
        IF %ERRORLEVEL% NEQ 0 (
          echo [ERROR] Failed to pull model %MODEL%. Please run 'ollama pull %MODEL%' manually.
        ) ELSE (
          echo Model %MODEL% pulled successfully.
        )
      ) ELSE (
        echo Skipping model pull. You can run: ollama pull %MODEL%
      )
    ) ELSE (
      echo Model "%MODEL%" is present locally.
    )
  )
)
:: External components note (do not mislead)
echo NOTE: This script does not automatically install/configure SearXNG, Piper TTS, Live2D, or other external services.
echo Please refer to SEARXNG_SETUP.md, PIPER_SETUP.md, and OLLAMA_SETUP.md for manual installation steps when needed.
:: Final: start the Node server
echo Starting Rei-chan server (node src/server.js)...
node "src/server.js"
IF %ERRORLEVEL% NEQ 0 (
  echo [ERROR] Node application exited with code %ERRORLEVEL%.
  echo Check server logs and ensure environment variables in .env are correctly set.
  pause
  exit /b %ERRORLEVEL%
)
necho Server stopped. Exiting.
ENDLOCAL

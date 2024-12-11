@echo off
rem Обновления ТИС
if exist "C:\Program Files\tis\MySQL\network\admin" copy /Y \\server\TIS\TNS\tnsnames.ora "C:\Program Files\tis\MySQL\network\admin"
xcopy /D /V /H /R /Y /S \\server01\TIS\Upgrade\*.* "C:\Program Files\TIS"
xcopy /D /V /H /R /Y /E \\server01\TIS\RPT_all "C:\Program Files\TIS\igla"

rem Обновления КСО
xcopy /D /V /R /Y /E \\server01\tis\KSO\upgrade\*.*

rem Обновления тестовых машин
if exist "\\server01\tis\upgrade_test\upgrade_KSO" call upgrade_test_kso.bat

rem Копирование логов и чеков в сетевую папку
if not exist \\server01.local\TIS\logs\%computername% md \\server01.local\TIS\logs\%computername%
xcopy /D /V /H /R /Y "C:\Program Files\TIS\KSO\tis.log*" \\server01.local\TIS\logs\%computername%
robocopy /MIR "C:\Program Files\TIS\KSO\check_backup" \\server01.local\TIS\logs\%computername%\check_backup >nul
robocopy /MIR "C:\Program Files\TIS\KSO\check" \\server01.local\TIS\logs\%computername%\check >nul

rem Запуск КСО
cls
@echo Касса загружается. Пожалуйста, не мешайте ей это делать:)
@echo Осталось ждать примерно 20 минут...

@echo %time:~,-3% Загружаются таблицы ККМ...
start /wait pos.exe ini=pos_reserv.ini KKM_SYNC=Y

@echo %time:~,-3% Копируются файлы чеков...
if exist check\*.chk (copy /y check\*.chk check_backup) else @echo Нет сохранённых чеков

@echo %time:~,-3% В базу загружаются сохранённые чеки...
start /wait POS.exe ini=pos_reserv.ini SAVE_CHECK=Y LOG_DEBUGS=Y

@echo %time:~,-3% Удаляются старые записи...
forfiles /p check /m *.* /d -180 /c "cmd /c del @path" 2>nul

@echo %time:~,-3% Выгружаются справочники POS...
start /wait pos.exe ini=pos_reserv.ini sync=Y TIME_INTERVAL=12 POS_BASE=Y LOG_DEBUGS=Y

@echo Осталось ждать примерно 10 минут...

@echo %time:~,-3% Загружаются справочники...
rem Запускается отдельным процессом сервер топпера (run_report, см. строку 34), затем POS с параметром VER_COLONKA=5. В случае зависания/отключения топпера КСО не будет зависать. Топпер в случае его отключения можно рестартнуть не выходя из POS, завершив процесс run_report и перезапустив его с параметром (run_report.exe VER_COLONKA=3)
start run_report.exe VER_COLONKA=3 COLONKA=Y
rem для КСО ENGY: VER_COLONKA=3
TIMEOUT /T 1 > nul
start POS.exe ini=pos_reserv.ini OFFLINE=Y KKM_TYPE=SHTRIH-M KKM_LEN=48 SELF_TERMINAL=Y LOG_DEBUGS=Y SLEEP_TIME=180 VER_COLONKA=5 AUTO_USER=Y INTERVAL_CHECK_FILE=120 ADD_SLEEP_TIME_DIALOG=180 PAY_SOUND=OK.WAV

rem Задержка для чтения сообщений
timeout 60 >> nul

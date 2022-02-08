@echo off
:: --------------- Copyright (c) Takeoff Technical LLC 2022 -------------------
:: Purpose: Runs the python script and shows the output in BeyondCompare
:: Notes:   You do have BeyondCompare, right?
:: License: GPL v3
:: ----------------------------------------------------------------------------

setlocal

:: Use the location of this batch file as the base path
set _base_path=%~dp0
set _base_path=%_base_path:~0,-1%

:: The original env as copied or captured from u-boot
set _original_file="%_base_path%\input\env-original.txt"

:: Output file to a separate directory
set _output_path=%_base_path%\output

if not exist "%_output_path%" (
    md "%_output_path%"
)

:: Output filenames
set _pretty_file="%_output_path%\env-pretty.txt"
set _ugly_file="%_output_path%\env-ugly.txt"
set _pretty_ugly_file="%_output_path%\env-pretty-ugly.txt"

:: Run the Commands
set _py_script="%_base_path%\parse-multicmd-vars.py"

:: Create the file with multiple commands broken out on multiple lines
python %_py_script% expand %_original_file% %_pretty_file%

:: Recreate the single-line version of the file
python %_py_script% condense %_pretty_file% %_ugly_file%

:: Recreate the pretty version from that now
python %_py_script% expand %_ugly_file% %_pretty_ugly_file%

:: Start beyond compare to show the results
set _bcmp="%PROGRAMFILES%\Beyond Compare 4\BCompare.exe"

echo Verify pretty-print file is correct...
%_bcmp% %_original_file% %_pretty_file%

echo Verify conversion back to ugly format is equivalent...
%_bcmp% %_original_file% %_ugly_file%

echo Verify the ugly format converts to the same pretty format...
%_bcmp% %_pretty_file% %_pretty_ugly_file%

endlocal

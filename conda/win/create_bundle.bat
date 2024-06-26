set conda_env="fc_env"
set copy_dir="FreeCAD_Conda_Build"

mkdir %copy_dir%

call certutil.exe -urlcache -split -f "https://github.com/drwho495/freecad-context-feedstock/releases/download/conda-release/windows-conda-package.zip" packages.zip
mkdir packages
tar -xf packages.zip -C .\packages
dir .\packages
for /f "delims=" %%a in ('dir /b/s freecad*.conda') do @set package=%%a 
echo %package%

call mamba create ^
 -p %conda_env% ^
 occt vtk xerces-c pivy pyside2 r-libcoin python=3.11 numpy ^
 matplotlib-base scipy sympy pandas six pyyaml pycollada lxml ^
 xlutils olefile requests blinker opencv nine yaml-cpp docutils ^
 opencamlib calculix ifcopenshell lark blas=*=openblas ^
 --copy ^
 -c freecad/label/dev ^
 -c conda-forge ^
 -c r ^
 -y

echo "Installing FreeCAD"
call mamba install -p %conda_env% %package% --copy -c freecad/label/dev -y

echo "getting version"
%conda_env%\python ..\scripts\get_freecad_version.py
set /p freecad_version_name= <bundle_name.txt

echo **********************
echo %freecad_version_name%
echo **********************


REM remove arm binaries that fails to extract unless using latest 7zip
for /r %conda_env% %%i in (*arm*.exe) do @echo "%%i will be removed"
for /r %conda_env% %%i in (*arm*.exe) do @del "%%i"

REM Copy Conda's Python and (U)CRT to FreeCAD/bin
robocopy %conda_env%\DLLs %copy_dir%\bin\DLLs /S /MT:%NUMBER_OF_PROCESSORS% > nul
robocopy %conda_env%\Lib %copy_dir%\bin\Lib /XD __pycache__ /S /MT:%NUMBER_OF_PROCESSORS% > nul
robocopy %conda_env%\Scripts %copy_dir%\bin\Scripts /S /MT:%NUMBER_OF_PROCESSORS% > nul
robocopy %conda_env%\ python*.* %copy_dir%\bin\ /XF *.pdb /MT:%NUMBER_OF_PROCESSORS% > nul
robocopy %conda_env%\ msvc*.* %copy_dir%\bin\ /XF *.pdb /MT:%NUMBER_OF_PROCESSORS% > nul
robocopy %conda_env%\ ucrt*.* %copy_dir%\bin\ /XF *.pdb /MT:%NUMBER_OF_PROCESSORS% > nul
REM Copy gmsh and calculix
robocopy %conda_env%\Library\bin %copy_dir%\bin\ assistant.exe /MT:%NUMBER_OF_PROCESSORS% > nul
robocopy %conda_env%\Library\bin %copy_dir%\bin\ ccx.exe /MT:%NUMBER_OF_PROCESSORS% > nul
robocopy %conda_env%\Library\bin %copy_dir%\bin\ gmsh.exe /MT:%NUMBER_OF_PROCESSORS% > nul
robocopy %conda_env%\Library\mingw-w64\bin * %copy_dir%\bin\ /MT:%NUMBER_OF_PROCESSORS% > nul
REM Copy Conda's QT5/plugins to FreeCAD/bin
robocopy %conda_env%\Library\plugins %copy_dir%\bin\ /S /MT:%NUMBER_OF_PROCESSORS% > nul
robocopy %conda_env%\Library\resources %copy_dir%\resources /MT:%NUMBER_OF_PROCESSORS% > nul
robocopy %conda_env%\Library\translations %copy_dir%\translations /MT:%NUMBER_OF_PROCESSORS% > nul
echo [Paths] > %copy_dir%\bin\qt.conf
echo Prefix =.. >> "%copy_dir%\bin\qt.conf"
REM get all the dependency .dlls
robocopy %conda_env%\Library\bin *.dll %copy_dir%\bin /XF *.pdb /XF api*.* /MT:%NUMBER_OF_PROCESSORS% > nul
REM Copy FreeCAD build
robocopy %conda_env%\Library\bin FreeCAD* %copy_dir%\bin /XF *.pdb /MT:%NUMBER_OF_PROCESSORS% > nul
robocopy %conda_env%\Library\data %copy_dir%\data /XF *.txt /S /MT:%NUMBER_OF_PROCESSORS% > nul
REM robocopy %conda_env%\Library\doc\ *.html %copy_dir%\doc MT:%NUMBER_OF_PROCESSORS% > nul

robocopy %conda_env%\Library\Ext %copy_dir%\Ext /S /XD __pycache__ /MT:%NUMBER_OF_PROCESSORS% > nul
robocopy %conda_env%\Library\lib %copy_dir%\lib /XF *.lib /XF *.prl /XF *.sh /MT:%NUMBER_OF_PROCESSORS% > nul
robocopy %conda_env%\Library\Mod %copy_dir%\Mod /S /XD __pycache__ /MT:%NUMBER_OF_PROCESSORS% > nul
REM Apply Patches
rename %copy_dir%\bin\Lib\ssl.py ssl-orig.py
copy ssl-patch.py %copy_dir%\bin\Lib\ssl.py

cd %copy_dir%\..
ren %copy_dir% %freecad_version_name%
dir

REM if errorlevel1 exit 1

"%ProgramFiles%\7-Zip\7z.exe" a -t7z -mx9 -mmt=%NUMBER_OF_PROCESSORS% %freecad_version_name%.7z %freecad_version_name%\ -bb
certutil -hashfile "%freecad_version_name%.7z" SHA256 > "%freecad_version_name%.7z"-SHA256.txt
echo  %date%-%time% >>"%freecad_version_name%.7z"-SHA256.txt

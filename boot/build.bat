@echo off

REM This script assumes that 'nasm' is in your path

echo | set /p x=Building bmfs_mbr...
call nasm src\bootsectors\bmfs_mbr.asm -o bmfs_mbr.sys && (echo Success) || (echo Error!)

echo | set /p x=Building pxestart...
call nasm src\bootsectors\pxestart.asm -o pxestart.sys && (echo Success) || (echo Error!)

cd src
echo | set /p x=Building boot...
call nasm boot.asm -o ..\boot.sys && (echo Success) || (echo Error!)
cd ..
pause

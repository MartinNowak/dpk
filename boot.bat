cmd /C dmd -debug -unittest -ofdpk_boot src\dpk\build.d src\dpk\config.d src\dpk\ctx.d src\dpk\dflags.d src\dpk\install.d src\dpk\main.d src\dpk\pkgdesc.d src\dpk\util.d src\dpk\utrunner.d
dpk_boot.exe
del dpk_boot.exe dpk_boot.obj
